#!/usr/bin/env ruby
# encoding: utf-8

dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../lib/")
$:.unshift("#{dir}/../test")

require "helper"
require "mp3info"
require "fileutils"
require "tempfile"
require "zlib"
require "yaml"

GOT_ID3V2 = system("which id3v2 > /dev/null")

class Mp3InfoTest < TestCase
  TEMP_FILE = File.join(File.dirname(__FILE__), "test_mp3info.mp3")

  DUMMY_TAG2 = {
    "COMM" => "comments",
    #"TCON" => "genre_s"
    "TIT2" => "title",
    "TPE1" => "artist",
    "TALB" => "album",
    "TYER" => "year",
    "TRCK" => "tracknum",
    "USLT" => "lyrics test 123456789"
  }

  DUMMY_TAG1 = {
    "title"    => "toto",
    "artist"   => "artist 123",
    "album"    => "ALBUMM",
    "year"     => 1934,
    "tracknum" => 14,
    "comments" => "comment me",
    "genre" => 233
  }

  def setup
    @tag = {
      "title" => "title",
      "artist" => "artist",
      "album" => "album",
      "year" => 1921,
      "comments" => "comments",
      "genre" => 0,
      "genre_s" => "Blues",
      "tracknum" => 36
    }
    load_fixture_to_temp_file("empty_mp3")
  end

  def teardown
    FileUtils.rm_f(TEMP_FILE)
  end

  def test_to_s
    Mp3Info.open(TEMP_FILE) { |info| assert(info.to_s.is_a?(String)) }
  end

  def test_not_an_mp3
    File.open(TEMP_FILE, "w") do |f|
      str = "0"*1024*1024
      f.write(str)
    end
    assert_raises(Mp3InfoEOFError) do
      Mp3Info.new(TEMP_FILE)
    end
  end

  def test_is_an_mp3
    Mp3Info.new(TEMP_FILE).close
  end

  def test_detected_info
    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_mp3_info_are_ok(mp3)
    end
  end

  def test_vbr_mp3_length
    load_fixture_to_temp_file("vbr")

    Mp3Info.open(TEMP_FILE) do |info|
      assert(info.vbr)
      assert_in_delta(174.210612, info.length, 0.000001)
    end
  end

  def test_removetag1
    Mp3Info.open(TEMP_FILE) { |info| info.tag1 = @tag }
    assert(Mp3Info.hastag1?(TEMP_FILE))
    Mp3Info.removetag1(TEMP_FILE)
    assert(! Mp3Info.hastag1?(TEMP_FILE))
  end

  def test_writetag1
    Mp3Info.open(TEMP_FILE) { |info| info.tag1 = @tag }
    Mp3Info.open(TEMP_FILE) { |info| assert_equal(info.tag1, @tag) }
  end

  def test_valid_tag1_1
    tag = [ "title", "artist", "album", "1921", "comments", 36, 0].pack('A30A30A30A4a29CC')
    valid_tag = {
      "title" => "title",
      "artist" => "artist",
      "album" => "album",
      "year" => 1921,
      "comments" => "comments",
      "genre" => "Blues",
      #"version" => "1",
      "tracknum" => 36
    }
    id3_test(tag, valid_tag)
  end

  def test_valid_tag1_0
    tag = [ "title", "artist", "album", "1921", "comments", 0].pack('A30A30A30A4A30C')
    valid_tag = {
      "title" => "title",
      "artist" => "artist",
      "album" => "album",
      "year" => 1921,
      "comments" => "comments",
      "genre" => "Blues",
      #"version" => "0"
    }
    id3_test(tag, valid_tag)
  end

  def id3_test(tag_str, valid_tag)
    tag = "TAG" + tag_str
    File.open(TEMP_FILE, "a") do |f|
      f.write(tag)
    end
    assert(Mp3Info.hastag1?(TEMP_FILE))
    #info = Mp3Info.new(TEMP_FILE)
    #FIXME validate this test
    #assert_equal(info.tag1, valid_tag)
  end

  def test_removetag2
    write_tag2_to_temp_file("TIT2" => "sdfqdsf")

    assert( Mp3Info.hastag2?(TEMP_FILE) )
    Mp3Info.removetag2(TEMP_FILE)
    assert( ! Mp3Info.hastag2?(TEMP_FILE) )
  end

  def test_hastags
    Mp3Info.open(TEMP_FILE) do |info|
      info.tag1 = @tag
    end
    assert(Mp3Info.hastag1?(TEMP_FILE))

    write_tag2_to_temp_file(DUMMY_TAG2)
    assert(Mp3Info.hastag2?(TEMP_FILE))
  end

  def test_universal_tag
    2.times do
      tag = {"title" => "title"}
      Mp3Info.open(TEMP_FILE) do |mp3|
        tag.each { |k,v| mp3.tag[k] = v }
      end
      w = Mp3Info.open(TEMP_FILE) { |m| m.tag }
      assert_equal(tag, w)
    end
  end

  def test_id3v2_universal_tag
    tag = {}
    %w{comments title artist album}.each { |k| tag[k] = k }
    tag["tracknum"] = 34
    Mp3Info.open(TEMP_FILE) do |mp3|
      tag.each { |k,v| mp3.tag[k] = v }
    end
    w = Mp3Info.open(TEMP_FILE) { |m| m.tag }
    w.delete("genre")
    w.delete("genre_s")
    assert_equal(tag, w)
    #    id3v2_prog_test(tag, w)
  end

  def test_id3v2_version
    written_tag = write_tag2_to_temp_file(DUMMY_TAG2)
    assert_equal( "2.3.0", written_tag.version )
  end

=begin
  # test for good output of APIC tag inspect (escaped and snipped)
  def test_id3v2_to_inspect_hash
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.APIC = "\0testing.jpg\0" * 20
      assert_match(/\\0testing\.jpg\\0.*<<<\.\.\.snip\.\.\.>>>$/, mp3.tag2.to_inspect_hash["APIC"])
    end
  end
=end

  # test for good output of APIC tag inspect (escaped and snipped)
  def test_id3v2_to_inspect_hash
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2["APIC"] =  "\x00testing.jpg\x00" * 20
      assert_match(/^((\\x00|\\u0000)testing.jpg(\\x00|\\u0000))+.*<<<\.\.\.snip\.\.\.>>>$/, mp3.tag2.to_inspect_hash["APIC"])
    end
  end

  def test_id3v2_get_pictures_png
    img = "\x89PNG".force_encoding('BINARY') +
      random_string(120).force_encoding('BINARY')
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.add_picture(img, :description => 'example image.png')
    end
    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal(["01_example image.png", img], mp3.tag2.pictures[0])
    end
  end

  def test_id3v2_get_pictures_png_bad_mime
    img = "\x89PNG\r\n\u001A\n\u0000\u0000\u0000\rIHDR\u0000\u0000\u0000\u0001\u0000\u0000\u0000\u0001\b\u0002\u0000\u0000\u0000\x90wS\xDE\u0000\u0000\u0000\fIDAT\b\xD7c\xF8\xFF\xFF?\u0000\u0005\xFE\u0002\xFE\xDC\xCCY\xE7\u0000\u0000\u0000\u0000IEND\xAEB`\x82".force_encoding('BINARY')
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.add_picture(img, :description => 'example image.png', :mime => 'jpg')
    end

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal(["01_example image.png", img], mp3.tag2.pictures[0])
    end
  end

  def test_id3v2_get_pictures_jpg
    img = "\xFF\xD8".force_encoding('BINARY') +
          random_string(120).force_encoding('BINARY')

    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.add_picture(img, :description => 'example image.jpg')
    end

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal(["01_example image.jpg", img], mp3.tag2.pictures[0])
    end
  end

  def test_id3v2_get_pictures_jpg_bad_mime
    img = "\xFF\xD8".force_encoding('BINARY') +
          random_string(120).force_encoding('BINARY')

    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.add_picture(img, :description => 'example image.jpg', :mime => 'png')
    end

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal(["01_example image.jpg", img], mp3.tag2.pictures[0])
    end
  end

  def test_id3v2_remove_pictures
    jpg_data = "\xFF\xD8".force_encoding('BINARY') +
      random_string(123).force_encoding('BINARY')
    Mp3Info.open(TEMP_FILE) do |mp|
      mp.tag2.add_picture(jpg_data)
    end
    Mp3Info.open(TEMP_FILE) do |mp|
      mp.tag2.remove_pictures
      assert_equal([], mp.tag2.pictures)
    end
  end

  def test_id3v2_methods
    tag = { "TIT2" => "tit2", "TPE1" => "tpe1" }
    Mp3Info.open(TEMP_FILE) do |mp3|
      tag.each do |k, v|
        mp3.tag2.tap { |h| h[k.to_s] = v }
      end
      assert_equal tag, mp3.tag2.to_hash
    end
  end

  def test_id3v2_basic
    written_tag = write_tag2_to_temp_file(DUMMY_TAG2)
    assert_equal(DUMMY_TAG2, written_tag.to_hash)
    id3v2_prog_test(DUMMY_TAG2, written_tag.to_hash)
  end

  #test the tag with the "id3v2" program
  def id3v2_prog_test(tag, written_tag)
    return unless GOT_ID3V2
    start = false
    id3v2_output = {}
=begin
    id3v2 tag info for test/test_mp3info.mp3:
      COMM (Comments): (~)[ENG]:
      test/test_mp3info.mp3: No ID3v1 tag
=end
    raw_output = `id3v2 -l #{TEMP_FILE}`
    raw_output.split(/\n/).each do |line|
      if line =~ /^id3v2 tag info/
        start = true
        next
      end
      next unless start
      if match = /^(.{4}) \(.+\): (.+)$/.match(line)
        k, v = match[1, 2]
        case k
        #COMM (Comments): ()[spa]: fmg
        when "COMM", "USLT"
          v.sub!(/\(\)\[.{3}\]: (.+)/, '\1')
        end
        id3v2_output[k] = v
      end
    end

    assert_equal( id3v2_output, written_tag.to_hash, "id3v2 program output doesn't match")
  end

  def test_id3v2_complex
    tag = {}
    ["PRIV", "APIC"].each do |k|
      tag[k] = random_string(50)
    end

    got_tag = write_tag2_to_temp_file(tag)
    assert_equal(tag, got_tag.to_hash)
  end

  def test_id3v2_bigtag
    tag = {"APIC" => random_string(1024) }
    assert_equal(tag, write_tag2_to_temp_file(tag).to_hash)
  end

  def test_leading_char_gets_chopped
    tag2 = DUMMY_TAG2.dup
    tag2["WOAR"] = "http://foo.bar"
    w = write_tag2_to_temp_file(tag2)
    assert_equal("http://foo.bar", w["WOAR"])

    return unless GOT_ID3V2
    system(%(id3v2 --WOAR "http://foo.bar" "#{TEMP_FILE}"))

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal "http://foo.bar", mp3.tag2["WOAR"]
    end
  end

  def test_reading2_2_tags
    load_fixture_to_temp_file("2_2_tagged")

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal "2.2.0", mp3.tag2.version
      expected_tag = {
        "TCO" => "Hip Hop/Rap",
        "TP1" => "Grems Aka Supermicro",
        "TT2" => "Intro",
        "TAL" => "Air Max",
        "TEN" => "iTunes v7.0.2.16",
        "TYE" => "2006",
        "TRK" => "1/17",
        "TPA" => "1/1" }
      tag = mp3.tag2.dup
      assert_equal 4, tag["COM"].size
      tag.delete("COM")
      assert_equal expected_tag, tag.to_hash

      expected_tag = {
        "genre_s"       => "Hip Hop/Rap",
        "title"         => "Intro",
        #"comments"      => "\000engiTunPGAP\0000\000\000",
        "comments"      => "0",
        "year"          => 2006,
        "album"         => "Air Max",
        "artist"        => "Grems Aka Supermicro",
        "tracknum"      => 1 }
      # test universal tag
      assert_equal expected_tag, mp3.tag.to_hash
    end
  end

  def test_writing_universal_tag_from_2_2_tags
    load_fixture_to_temp_file("2_2_tagged")

    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag.artist = "toto"
      mp3.tag.comments = "comments"
      mp3.flush
      expected_tag = {
        "artist" => "toto",
        "genre_s" => "Hip Hop/Rap",
        "title" => "Intro",
        "comments" => "comments",
        "year" => 2006,
        "album" => "Air Max",
        "tracknum" => 1}

      assert_equal expected_tag, mp3.tag
    end
  end

  def test_remove_tag
    Mp3Info.open(TEMP_FILE) do |mp3|
      tag = mp3.tag
      tag.title = "title"
      tag.artist = "artist"
      mp3.close
      mp3.reload
      assert !mp3.tag1.empty?, "tag is empty"
      mp3.removetag1
      mp3.flush
      assert mp3.tag1.empty?, "tag is not empty"
    end
  end

  def test_good_parsing_of_a_pathname
    fn = "Freak On `(Stone´s Club Mix).mp3"
    FileUtils.cp(TEMP_FILE, fn)
    begin
      Mp3Info.open(fn) do |mp3|
        mp3.tag.title = fn
        mp3.flush
        if RUBY_VERSION[0..2] == "1.8"
          assert_equal fn, mp3.tag.title
        else
          assert_equal fn, mp3.tag.title.force_encoding("utf-8")
        end
      end
    ensure
      File.delete(fn)
    end
  end

  def test_audio_content
    require "digest/md5"

    expected_digest = nil
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag1.update(DUMMY_TAG1)
      mp3.tag2.update(DUMMY_TAG2)
      mp3.flush
      assert mp3.hastag1?
      assert mp3.hastag2?
      assert mp3.tag2.io_position != 0
      expected_digest = compute_audio_content_mp3_digest(mp3)
    end

    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.removetag1
      mp3.removetag2
      mp3.flush
      assert !mp3.hastag1?
      assert !mp3.hastag2?
      got_digest = compute_audio_content_mp3_digest(mp3)
      assert_equal expected_digest, got_digest
    end
  end

  def test_audio_content_problematic
    load_fixture_to_temp_file("audio_content_fixture", false)
    Mp3Info.open(TEMP_FILE) do |mp3|
      expected_pos = 150
      audio_content_pos, audio_content_size = mp3.audio_content
      assert_equal expected_pos, audio_content_pos
      assert_equal File.size(TEMP_FILE) - expected_pos, audio_content_size
    end
  end

  def test_headerless_vbr_file
    mp3_length = 3
    load_fixture_to_temp_file("small_vbr_mp3")

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert mp3.vbr
      assert_in_delta(mp3_length, mp3.length, 0.1)
      assert_in_delta(128, mp3.bitrate, 8)
    end
  end

  def test_parse_tags_disabled
    write_tag2_to_temp_file(DUMMY_TAG2)
    Mp3Info.open(TEMP_FILE, :parse_tags => false) do |mp3|
      assert mp3.tag.empty?
      assert mp3.tag1.empty?
      assert mp3.tag2.empty?
      mp3.tag["artist"] = "some dummy tag"
      mp3.tag2["TIT2"] = "title 2"
      mp3.flush
      # tag should not be written
      assert mp3.tag.empty?
      assert mp3.tag1.empty?
      assert mp3.tag2.empty?
    end
  end

  def test_string_io
    io = load_string_io
    Mp3Info.open(io) do |mp3|
      assert_mp3_info_are_ok(mp3)
    end
  end

  def test_trying_to_rename_a_stringio_should_raise_an_error
    io = load_string_io
    Mp3Info.open(io) do |mp3|
      assert_raises(Mp3InfoError) do
        mp3.rename("whatever_filename_is_error_should_be_raised.mp3")
      end
    end
  end

  def test_hastag_class_methods_with_a_stringio
    Mp3Info.open(TEMP_FILE) do |info|
      info.tag1 = @tag
    end
    io = load_string_io
    assert(Mp3Info.hastag1?(io))

    write_tag2_to_temp_file(DUMMY_TAG2)
    io = load_string_io
    assert(Mp3Info.hastag2?(io))
  end

  def test_convert_to_utf16_little_endian
    s = Mp3Info::EncodingHelper.convert_to("track's title €éàïôù", "utf-8", "utf-16")
    expected = "ff fe 74 00 72 00 61 00 63 00 6b 00 27 00 73 00 20 00 74 00 69 00 74 00 6c 00 65 00 20 00 ac 20 e9 00 e0 00 ef 00 f4 00 f9 00"
    assert_equal(expected, s.bytes.map{|b| b.to_s(16).rjust(2,"0")}.to_a.join(" "))
  end

  def test_modifying_an_io
    io = open(TEMP_FILE, "r")
    Mp3Info.open(io) do |mp3|
      mp3.tag.artist = "test_artist"
    end
  end

  def test_22k
    load_fixture_to_temp_file("22k", false)
    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal 40, mp3.bitrate
      assert !mp3.vbr
      assert_equal 2.0, mp3.length
    end
  end

  def test_parsing_unsynced_file
    load_fixture_to_temp_file("vbr")
    File.open("/tmp/test.mp3", "w") do |tf|
      tf.write File.read(TEMP_FILE, 96512)
      tf.write "\0\0"
      tf.write File.read(TEMP_FILE, nil, 96512)
    end

    Mp3Info.open("/tmp/test.mp3") do |info|
      info.each_frame { |frame| frame }
      assert(info.vbr)
      assert_in_delta(174.210612, info.length, 0.000001)
    end
  end

  def test_utf16_no_bom
    load_fixture_to_temp_file("utf16_no_bom")
    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal "2.3.0", mp3.tag2.version
      expected_tag = {
        "TALB" => "\u266bRodrigo y Gabriela",
        "TRCK"=>"1",
        "TIT2"=>"Tamacun",
        "TPE1"=>"Rodrigo y Gabriela"
      }
      tag = mp3.tag2.dup
      assert_equal expected_tag, tag.to_hash
    end
  end

  def compute_audio_content_mp3_digest(mp3)
    pos, size = mp3.audio_content
    data = File.open(mp3.filename) do |f|
      f.seek(pos, IO::SEEK_SET)
      f.read(size)
    end
    Digest::MD5.new.update(data).hexdigest
  end

  def write_tag2_to_temp_file(tag)
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.update(tag)
    end
    return Mp3Info.open(TEMP_FILE) { |m| m.tag2 }
  end

  def random_string(size)
    out = ""
    size.times { out << rand(256).chr }
    out
  end

  def assert_mp3_info_are_ok(mp3)
    assert_equal(1, mp3.mpeg_version)
    assert_equal(3, mp3.layer)
    assert_equal(false, mp3.vbr)
    assert_equal(128, mp3.bitrate)
    assert_equal("JStereo", mp3.channel_mode)
    assert_equal(44100, mp3.samplerate)
    assert_equal(0.1305625, mp3.length)
    assert_equal({
      :layer=>3,
      :bitrate=>128,
      :samplerate=>44100,
      :mpeg_version=>1,
      :padding=>false,
      :size=>417,
      :error_protection=>false,
      :private=>true,
      :mode_extension=>2,
      :copyright=>false,
      :original=>true,
      :emphasis=>0,
      :channel_num=>1,
      :channel_mode=>"JStereo"
    }, mp3.header)
  end

  def load_string_io(filename = TEMP_FILE)
    io = StringIO.new
    data = File.read(filename)
    io.write(data)
    io.rewind
    io
  end

  FIXTURES = YAML::load_file( File.join(File.dirname(__FILE__), "fixtures.yml") )

  def load_fixture_to_temp_file(fixture_key, zlibed = true)
    # Command to create a gzip'ed dummy MP3
    # $ dd if=/dev/zero bs=1024 count=15 | \
    #   lame --quiet --preset cbr 128 -r -s 44.1 --bitwidth 16 - - | \
    #   ruby -rbase64 -rzlib -ryaml -e 'print(Zlib::Deflate.deflate($stdin.read)'
    # vbr:
    # $ dd if=/dev/zero of=#{tempfile.path} bs=1024 count=30000 |
    #     system("lame -h -v -b 112 -r -s 44.1 --bitwidth 16 - /tmp/vbr.mp3
    #
    # this will generate a #{mp3_length} sec mp3 file (44100hz*16bit*2channels) = 60/4 = 15
    # system("dd if=/dev/urandom bs=44100 count=#{mp3_length*4}  2>/dev/null | \
    #        lame -v -m s --vbr-new --preset 128 -r -s 44.1 --bitwidth 16 - -  > #{TEMP_FILE} 2>/dev/null")
    content = FIXTURES[fixture_key]
    if zlibed
      content = Zlib::Inflate.inflate(content)
    end

    File.open(TEMP_FILE, "w") do |f|
      f.write(content)
    end
  end
end
