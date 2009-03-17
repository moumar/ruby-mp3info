#!/usr/bin/env ruby1.9
# coding:utf-8

$:.unshift("lib/")

require "test/unit"
require "mp3info"
require "fileutils"
require "tempfile"
require "zlib"
require "yaml"

class Mp3InfoTest < Test::Unit::TestCase

  TEMP_FILE = File.join(File.dirname(__FILE__), "test_mp3info.mp3")

  DUMMY_TAG2 = {
    "COMM" => "comments",
    #"TCON" => "genre_s" 
    "TIT2" => "title",
    "TPE1" => "artist",
    "TALB" => "album",
    "TYER" => "year",
    "TRCK" => "tracknum"
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

  FIXTURES = YAML::load_file( File.join(File.dirname(__FILE__), "fixtures.yml") )

  def setup
    # Command to create a gzip'ed dummy MP3
    # $ dd if=/dev/zero bs=1024 count=15 | \
    #   lame --quiet --preset cbr 128 -r -s 44.1 --bitwidth 16 - - | \
    #   ruby -rbase64 -rzlib -ryaml -e 'print(Zlib::Deflate.deflate($stdin.read)'
    # vbr:
    # $ dd if=/dev/zero of=#{tempfile.path} bs=1024 count=30000 |
    #     system("lame -h -v -b 112 -r -s 44.1 --bitwidth 16 - /tmp/vbr.mp3
    @valid_mp3, @valid_mp3_2_2, @vbr_mp3 = %w{empty_mp3 2_2_tagged vbr}.collect do |fixture_key|
      Zlib::Inflate.inflate(FIXTURES[fixture_key])
    end
                  
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
    File.open(TEMP_FILE, "w") { |f| f.write(@valid_mp3) }
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
    assert_raises(Mp3InfoError) do
      mp3 = Mp3Info.new(TEMP_FILE)
    end
  end

  def test_is_an_mp3
    assert_nothing_raised do
      Mp3Info.new(TEMP_FILE).close
    end
  end
  
  def test_detected_info
    Mp3Info.open(TEMP_FILE) do |info|
      assert_equal(1, info.mpeg_version)
      assert_equal(3, info.layer)
      assert_equal(false, info.vbr)
      assert_equal(128, info.bitrate)
      assert_equal("JStereo", info.channel_mode)
      assert_equal(44100, info.samplerate)
      assert_equal(0.1305625, info.length)
      assert_equal({:original => true, 
                    :error_protection => false, 
                    :padding => false, 
                    :emphasis => 0, 
                    :private => true, 
                    :mode_extension => 2, 
                    :copyright => false}, info.header)
    end
  end
  
  def test_vbr_mp3_length
    File.open(TEMP_FILE, "w") { |f| f.write(@vbr_mp3) }

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
    File.open(TEMP_FILE, "w") do |f|
      f.write(@valid_mp3)
      f.write(tag)
    end
    assert(Mp3Info.hastag1?(TEMP_FILE))
    #info = Mp3Info.new(TEMP_FILE)
    #FIXME validate this test
    #assert_equal(info.tag1, valid_tag)
  end

  def test_removetag2
    w = write_temp_file({"TIT2" => "sdfqdsf"})

    assert( Mp3Info.hastag2?(TEMP_FILE) )
    Mp3Info.removetag2(TEMP_FILE)
    assert( ! Mp3Info.hastag2?(TEMP_FILE) )
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
    written_tag = write_temp_file(DUMMY_TAG2)
    assert_equal( "2.#{ID3v2::WRITE_VERSION}.0", written_tag.version )
  end

  def test_id3v2_methods
    tag = { "TIT2" => "tit2", "TPE1" => "tpe1" }
    Mp3Info.open(TEMP_FILE) do |mp3|
      tag.each do |k, v|
        mp3.tag2.send("#{k}=".to_sym, v)
      end
      assert_equal(tag, mp3.tag2)
    end
  end

  def test_id3v2_basic
    w = write_temp_file(DUMMY_TAG2)
    assert_equal(DUMMY_TAG2, w)
    id3v2_prog_test(DUMMY_TAG2, w)
  end

  #test the tag with the "id3v2" program
  def id3v2_prog_test(tag, written_tag)
    return if RUBY_PLATFORM =~ /win32/
    return if `which id3v2`.empty?
    start = false
    id3v2_output = {}
    `id3v2 -l #{TEMP_FILE}`.split(/\n/).each do |line|
      if line =~ /^id3v2 tag info/
        start = true 
	next    
      end
      next unless start
      k, v = /^(.{4}) \(.+\): (.+)$/.match(line)[1,2]
      case k
	#COMM (Comments): ()[spa]: fmg
        when "COMM"
	  v.sub!(/\(\)\[.{3}\]: (.+)/, '\1')
      end
      id3v2_output[k] = v
    end

    assert_equal( id3v2_output, written_tag, "id3v2 program output doesn't match")
  end

  def test_id3v2_trash
  end

  def test_id3v2_complex
    tag = {}
    #ID3v2::TAGS.keys.each do |k|
    ["PRIV", "APIC"].each do |k|
      tag[k] = random_string(50)
    end

    got_tag = write_temp_file(tag)
    assert_equal(tag, got_tag)
  end

  def test_id3v2_bigtag
    tag = {"APIC" => random_string(1024) }
    assert_equal(tag, write_temp_file(tag))
  end

  def test_infinite_loop_on_seek_to_v2_end
    
  end

  def test_leading_char_gets_chopped
    tag2 = DUMMY_TAG2.dup
    tag2["WOAR"] = "http://foo.bar"
    w = write_temp_file(tag2)
    assert_equal("http://foo.bar", w["WOAR"])

    system(%(id3v2 --WOAR "http://foo.bar" "#{TEMP_FILE}"))

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert_equal "http://foo.bar", mp3.tag2["WOAR"]
    end
  end

  def test_reading2_2_tags
    File.open(TEMP_FILE, "w") { |f| f.write(@valid_mp3_2_2) }

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
      assert_equal expected_tag, tag

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
      assert_equal expected_tag, mp3.tag
    end
  end

  def test_writing_universal_tag_from_2_2_tags
    File.open(TEMP_FILE, "w") { |f| f.write(@valid_mp3_2_2) }
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
        if RUBY_VERSION < "1.9.0"
          assert_equal fn, mp3.tag.title
        else
          assert_equal fn, mp3.tag.title.force_encoding("utf-8")
        end
      end
    ensure
      File.delete(fn)
    end
  end

  def test_validity_of_id3v2_options
    info = Mp3Info.new(TEMP_FILE)
    expected_hash = { :lang => "ENG", :encoding => "iso-8859-1" }
    assert_equal( expected_hash, info.tag2.options)

    assert_raises(ArgumentError) do
      Mp3Info.new(TEMP_FILE, :encoding => "bad encoding")
    end
  end

  def test_encoding_read
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2['TEST'] = "all\xe9"
    end

    Mp3Info.open(TEMP_FILE, :encoding => "utf-8") do |mp3|
      assert_equal "allé", mp3.tag2['TEST']
    end

    Mp3Info.open(TEMP_FILE, :encoding => "iso-8859-1") do |mp3|
      if RUBY_VERSION < "1.9.0"
        assert_equal "all\xe9", mp3.tag2['TEST']
      else
        assert_equal "all\xe9".force_encoding("binary"), mp3.tag2['TEST']
      end
    end
  end

  def test_encoding_write
    Mp3Info.open(TEMP_FILE, :encoding => 'utf-8') do |mp3|
      mp3.tag2['TEST'] = "all\xc3\xa9"
    end

    Mp3Info.open(TEMP_FILE, :encoding => "iso-8859-1") do |mp3|
      if RUBY_VERSION < "1.9.0"
        assert_equal "all\xe9", mp3.tag2['TEST']
      else
        assert_equal "all\xe9".force_encoding("iso-8859-1"), mp3.tag2['TEST']
      end
    end
  end

=begin
  def test_should_raises_exception_when_writing_badly_encoded_frames
    assert_raises(Iconv::Failure) do 
      Mp3Info.open(TEMP_FILE, :encoding => 'utf-8') do |mp3|
	mp3.tag2['TEST'] = "all\xc3"
      end
    end
  end
=end

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

  def test_headerless_vbr_file
    mp3_length = 3
    # this will generate a 15 sec mp3 file (44100hz*16bit*2channels) = 60/4 = 15
    system("dd if=/dev/urandom bs=44100 count=#{mp3_length*4}  2>/dev/null | \
            lame -v -m s --vbr-new --preset 128 -r -s 44.1 --bitwidth 16 - -  > #{TEMP_FILE} 2>/dev/null")

    Mp3Info.open(TEMP_FILE) do |mp3|
      assert mp3.vbr
      assert_in_delta(mp3_length, mp3.length, 0.1)
      assert_in_delta(128, mp3.bitrate, 8)
    end
  end

  def test_parse_tags_disabled
    write_temp_file(DUMMY_TAG2)
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

  def compute_audio_content_mp3_digest(mp3)
    pos, size = mp3.audio_content
    data = File.open(mp3.filename) do |f|
      f.seek(pos, IO::SEEK_SET)
      f.read(size)
    end
    Digest::MD5.new.update(data).hexdigest
  end

  def write_temp_file(tag)
    Mp3Info.open(TEMP_FILE) do |mp3|
      mp3.tag2.update(tag)
    end
    return Mp3Info.open(TEMP_FILE) { |m| m.tag2 }
    #system("cp -v #{TEMP_FILE} #{TEMP_FILE}.test")
  end

  def random_string(size)
    out = ""
    size.times { out << rand(256).chr }
    out
  end

=begin

  def test_encoder
    write_to_temp
    info = Mp3Info.new(TEMP_FILE)
    assert(info.encoder == "Lame 3.93")
  end

  def test_vbr
    mp3_vbr = Base64.decode64 <<EOF

EOF
    File.open(TEMP_FILE, "w") { |f| f.write(mp3_vbr) }
    info = Mp3Info.new(TEMP_FILE)
    assert_equal(info.vbr, true)
    assert_equal(info.bitrate, 128)
  end
=end
end
