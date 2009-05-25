# coding:utf-8
# $Id: mp3info.rb 98 2008-09-16 11:07:31Z moumar $
# License:: Ruby
# Author:: Guillaume Pierronnet (mailto:moumar_AT__rubyforge_DOT_org)
# Website:: http://ruby-mp3info.rubyforge.org/

require "fileutils"
require "mp3info/extension_modules"
require "mp3info/id3v2"

# ruby -d to display debugging infos

# Raised on any kind of error related to ruby-mp3info
class Mp3InfoError < StandardError ; end

class Mp3InfoInternalError < StandardError #:nodoc:
end

class Mp3Info

  VERSION = "0.6.13"

  LAYER = [ nil, 3, 2, 1]
  BITRATE = {
    1 => 
    [
      [32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
      [32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
      [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320] ],
    2 => 
    [
      [32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
      [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
      [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
    ],
    2.5 => 
    [
      [32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
      [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
      [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
    ]
  }
  SAMPLERATE = {
    1 => [ 44100, 48000, 32000 ],
    2 => [ 22050, 24000, 16000 ],
    2.5 => [ 11025, 12000, 8000 ]
  }
  CHANNEL_MODE = [ "Stereo", "JStereo", "Dual Channel", "Single Channel"]

  GENRES = [
    "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk",
    "Grunge", "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies",
    "Other", "Pop", "R&B", "Rap", "Reggae", "Rock",
    "Techno", "Industrial", "Alternative", "Ska", "Death Metal", "Pranks",
    "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
    "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House",
    "Game", "Sound Clip", "Gospel", "Noise", "AlternRock", "Bass",
    "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock",
    "Ethnic", "Gothic", "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk",
    "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
    "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret",
    "New Wave", "Psychadelic", "Rave", "Showtunes", "Trailer", "Lo-Fi",
    "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical",
    "Rock & Roll", "Hard Rock", "Folk", "Folk/Rock", "National Folk", "Swing",
    "Fast-Fusion", "Bebob", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde",
    "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band",
    "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech", "Chanson",
    "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus",
    "Porn Groove", "Satire", "Slow Jam", "Club", "Tango", "Samba",
    "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle", "Duet",
    "Punk Rock", "Drum Solo", "A capella", "Euro-House", "Dance Hall",
    "Goa", "Drum & Bass", "Club House", "Hardcore", "Terror",
    "Indie", "BritPop", "NegerPunk", "Polsk Punk", "Beat",
    "Christian Gangsta", "Heavy Metal", "Black Metal", "Crossover", "Contemporary C",
    "Christian Rock", "Merengue", "Salsa", "Thrash Metal", "Anime", "JPop",
    "SynthPop" ]

  TAG1_SIZE = 128
  #MAX_FRAME_COUNT = 6  #number of frame to read for encoder detection
  
  # map to fill the "universal" tag (#tag attribute)
  # for id3v2.2
  TAG_MAPPING_2_2 = { 
    "title"    => "TT2",
    "artist"   => "TP1", 
    "album"    => "TAL",
    "year"     => "TYE",
    "tracknum" => "TRK",
    "comments" => "COM",
    "genre_s"  => "TCO"
  }

  # for id3v2.3 and 2.4
  TAG_MAPPING_2_3 = { 
    "title"    => "TIT2",
    "artist"   => "TPE1", 
    "album"    => "TALB",
    "year"     => "TYER",
    "tracknum" => "TRCK",
    "comments" => "COMM",
    "genre_s"  => "TCON"
  }
  
  # http://www.codeproject.com/audio/MPEGAudioInfo.asp
  SAMPLES_PER_FRAME = [
    nil,
    {1=>384, 2=>384, 2.5=>384},    # Layer I   
    {1=>1152, 2=>1152, 2.5=>1152}, # Layer II
    {1=>1152, 2=>576, 2.5=>576}    # Layer III
  ]

  # mpeg version = 1 or 2
  attr_reader(:mpeg_version)

  # layer = 1, 2, or 3
  attr_reader(:layer)

  # bitrate in kbps
  attr_reader(:bitrate)

  # samplerate in Hz
  attr_reader(:samplerate)

  # channel mode => "Stereo", "JStereo", "Dual Channel" or "Single Channel"
  attr_reader(:channel_mode)

  # variable bitrate => true or false
  attr_reader(:vbr)

  # Hash representing values in the MP3 frame header. Keys are one of the following:
  # - :private (boolean)
  # - :copyright (boolean)
  # - :original (boolean)
  # - :padding (boolean)
  # - :error_protection (boolean)
  # - :mode_extension (integer in the 0..3 range)
  # - :emphasis (integer in the 0..3 range)
  # detailled explanation can be found here: http://www.mp3-tech.org/programmer/frame_header.html
  attr_reader(:header)

  # length in seconds as a Float
  attr_reader(:length)

  # error protection => true or false
  attr_reader(:error_protection)

  #a sort of "universal" tag, regardless of the tag version, 1 or 2, with the same keys as @tag1
  #this tag has priority over @tag1 and @tag2 when writing the tag with #close
  attr_reader(:tag)

  # id3v1 tag as a Hash. You can modify it, it will be written when calling
  # "close" method.
  attr_accessor(:tag1)

  # id3v2 tag attribute as an ID3v2 object. You can modify it, it will be written when calling
  # "close" method.
  attr_accessor(:tag2)

  # the original filename
  attr_reader(:filename)

  # Test the presence of an id3v1 tag in file +filename+
  def self.hastag1?(filename)
    File.open(filename) { |f|
      f.seek(-TAG1_SIZE, File::SEEK_END)
      f.read(3) == "TAG"
    }
  end

  # Test the presence of an id3v2 tag in file +filename+
  def self.hastag2?(filename)
    File.open(filename) { |f|
      f.read(3) == "ID3"
    }
  end

  # Remove id3v1 tag from +filename+
  def self.removetag1(filename)
    if self.hastag1?(filename)
      newsize = File.size(filename) - TAG1_SIZE
      File.open(filename, "rb+") { |f| f.truncate(newsize) }
    end
  end
  
  # Remove id3v2 tag from +filename+
  def self.removetag2(filename)
    self.open(filename) do |mp3|
      mp3.tag2.clear
    end
  end

  # Instantiate Mp3Info object with name +filename+.
  # options hash is used for ID3v2#new. 
  # You can specify :parse_tags => false to disable the processing 
  # of the tags (read and write).
  def initialize(filename, options = {})
    warn("#{self.class}::new() does not take block; use #{self.class}::open() instead") if block_given?
    @filename = filename
    @tag_parsing_enabled = options.delete(:parse_tags)
    if @tag_parsing_enabled == nil
      @tag_parsing_enabled = true
    end
    @id3v2_options = options
    reload
  end

  # reload (or load for the first time) the file from disk
  def reload
    raise(Mp3InfoError, "empty file") unless File.size?(@filename)

    @header = {}
    
    @file = File.new(filename, "rb")
    @file.extend(Mp3FileMethods)
    @tag1 = @tag = @tag1_orig = @tag_orig = {}
    @tag1.extend(HashKeys)
    @tag2 = ID3v2.new(@id3v2_options)
    
    begin
      if @tag_parsing_enabled
        parse_tags
        @tag1_orig = @tag1.dup

        if hastag1?
          @tag = @tag1.dup
        end

        if hastag2?
          @tag = {}
          # creation of a sort of "universal" tag, regardless of the tag version
          tag2_mapping = @tag2.version =~ /^2\.2/ ? TAG_MAPPING_2_2 : TAG_MAPPING_2_3
          tag2_mapping.each do |key, tag2_name| 
            tag_value = (@tag2[tag2_name].is_a?(Array) ? @tag2[tag2_name].first : @tag2[tag2_name])
            next unless tag_value
            @tag[key] = tag_value.is_a?(Array) ? tag_value.first : tag_value

            if %w{year tracknum}.include?(key)
              @tag[key] = tag_value.to_i
            end
            # this is a special case with id3v2.2, which uses
            # old fashionned id3v1 genres
            if tag2_name == "TCO" && tag_value =~ /^\((\d+)\)$/
              @tag["genre_s"] = GENRES[$1.to_i]
            end
          end
        end

        @tag.extend(HashKeys)
        @tag_orig = @tag.dup
      end


      ### extracts MPEG info from MPEG header and stores it in the hash @mpeg
      ###  head (fixnum) = valid 4 byte MPEG header
      
      found = false

      head = nil
      5.times do
	head = find_next_frame() 
        @first_frame_pos = @file.pos - 4
        current_frame = Mp3Info.get_frames_infos(head)
	@mpeg_version = current_frame[:mpeg_version]
	@layer = current_frame[:layer]
	@header[:error_protection] = head[16] == 0 ? true : false
	@bitrate = current_frame[:bitrate]
	@samplerate = current_frame[:samplerate]
	@header[:padding] = current_frame[:padding]
	@header[:private] = head[8] == 0 ? true : false
	@channel_mode = CHANNEL_MODE[@channel_num = Mp3Info.bits(head, 7,6)]
	@header[:mode_extension] = Mp3Info.bits(head, 5,4)
	@header[:copyright] = (head[3] == 1 ? true : false)
	@header[:original] = (head[2] == 1 ? true : false)
	@header[:emphasis] = Mp3Info.bits(head, 1,0)
	@vbr = false
	found = true
        break
      end

      raise(Mp3InfoError, "Cannot find good frame") unless found

      seek = @mpeg_version == 1 ? 
	(@channel_num == 3 ? 17 : 32) :       
	(@channel_num == 3 ?  9 : 17)

      @file.seek(seek, IO::SEEK_CUR)
      
      vbr_head = @file.read(4)
      if vbr_head == "Xing"
	puts "Xing header (VBR) detected" if $DEBUG
	flags = @file.get32bits
	stream_size = frame_count = 0
	flags[1] == 1 and frame_count = @file.get32bits
	flags[2] == 1 and stream_size = @file.get32bits 
	puts "#{frame_count} frames" if $DEBUG
	raise(Mp3InfoError, "bad VBR header") if frame_count.zero?
	# currently this just skips the TOC entries if they're found
	@file.seek(100, IO::SEEK_CUR) if flags[0] == 1
	#@vbr_quality = @file.get32bits if flags[3] == 1

        samples_per_frame = SAMPLES_PER_FRAME[@layer][@mpeg_version] 
	@length = frame_count * samples_per_frame / Float(@samplerate)

	@bitrate = (((stream_size/frame_count)*@samplerate)/144) / 1024
	@vbr = true
      else
	# for cbr, calculate duration with the given bitrate
	stream_size = @file.stat.size - (hastag1? ? TAG1_SIZE : 0) - (@tag2.io_position || 0)
	@length = ((stream_size << 3)/1000.0)/@bitrate
        # read the first 100 frames and decide if the mp3 is vbr and needs full scan
        begin
          bitrate, length = frame_scan(100)
          if @bitrate != bitrate
            @vbr = true
            @bitrate, @length = frame_scan
          end
        rescue Mp3InfoInternalError
        end
      end
    ensure
      @file.close
    end
  end

  # "block version" of Mp3Info::new()
  def self.open(*params)
    m = self.new(*params)
    ret = nil
    if block_given?
      begin
        ret = yield(m)
      ensure
        m.close
      end
    else
      ret = m
    end
    ret
  end

  # Remove id3v1 from mp3
  def removetag1
    @tag1.clear
    self
  end
  
  # Remove id3v2 from mp3
  def removetag2
    @tag2.clear
    self
  end

  # Does the file has an id3v1 or v2 tag?
  def hastag?
    hastag1? || hastag2?
  end

  # Does the file has an id3v1 tag?
  def hastag1?
    !@tag1.empty?
  end

  # Does the file has an id3v2 tag?
  def hastag2?
    @tag2.parsed?
  end

  # write to another filename at close()
  def rename(new_filename)
    @filename = new_filename
  end

  # this method returns the "audio-only" data boundaries of the file, 
  # i.e. content stripped form tags. Useful to compare 2 files with the same 
  # audio content but with differents tags. Returned value is an array 
  # [position_in_the_file, length_of_the_data]
  def audio_content
    pos = 0
    length = File.size(@filename)
    if hastag1?
      length -= TAG1_SIZE
    end
    if hastag2?
      pos = @tag2.io_position
      length -= @tag2.io_position
    end
    [pos, length]
  end

  # return the length in seconds of one frame
  def frame_length
    SAMPLES_PER_FRAME[@layer][@mpeg_version] / Float(@samplerate)
  end

  # Flush pending modifications to tags and close the file
  def close
    puts "close" if $DEBUG
    if !@tag_parsing_enabled
      return 
    end
    if @tag != @tag_orig
      puts "@tag has changed" if $DEBUG

      # @tag1 has precedence over @tag
      if @tag1 == @tag1_orig
	@tag.each do |k, v|
	  @tag1[k] = v
	end
      end

      # ruby-mp3info can only write v2.3 tags
      TAG_MAPPING_2_3.each do |key, tag2_name|
        @tag2.delete(TAG_MAPPING_2_2[key])
        @tag2[tag2_name] = @tag[key] if @tag[key]
      end
    end

    if @tag1 != @tag1_orig
      puts "@tag1 has changed" if $DEBUG
      raise(Mp3InfoError, "file is not writable") unless File.writable?(@filename)
      #@tag1_orig.update(@tag1)
      @tag1_orig = @tag1.dup
      File.open(@filename, 'rb+') do |file|
        if @tag1_orig.empty?
          newsize = file.stat.size - TAG1_SIZE
          file.truncate(newsize)
        else
          file.seek(-TAG1_SIZE, File::SEEK_END)
          t = file.read(3)
          if t != 'TAG'
            #append new tag
            file.seek(0, File::SEEK_END)
            file.write('TAG')
          end
          str = [
            @tag1_orig["title"]||"",
            @tag1_orig["artist"]||"",
            @tag1_orig["album"]||"",
            ((@tag1_orig["year"] != 0) ? ("%04d" % @tag1_orig["year"].to_i) : "\0\0\0\0"),
            @tag1_orig["comments"]||"",
            0,
            @tag1_orig["tracknum"]||0,
            @tag1_orig["genre"]||255
            ].pack("Z30Z30Z30Z4Z28CCC")
          file.write(str)
        end
      end
    end

    if @tag2.changed?
      puts "@tag2 has changed" if $DEBUG
      raise(Mp3InfoError, "file is not writable") unless File.writable?(@filename)
      tempfile_name = nil
      File.open(@filename, 'rb+') do |file|
	#if tag2 already exists, seek to end of it
	if @tag2.parsed?
	  file.seek(@tag2.io_position)
	end
  #      if @file.read(3) == "ID3"
  #        version_maj, version_min, flags = @file.read(3).unpack("CCB4")
  #        unsync, ext_header, experimental, footer = (0..3).collect { |i| flags[i].chr == '1' }
  #	tag2_len = @file.get_syncsafe
  #        @file.seek(@file.get_syncsafe - 4, IO::SEEK_CUR) if ext_header
  #	@file.seek(tag2_len, IO::SEEK_CUR)
  #      end
	tempfile_name = @filename + ".tmp"
	File.open(tempfile_name, "wb") do |tempfile|
	  unless @tag2.empty?
	    tempfile.write(@tag2.to_bin)
	  end

	  bufsiz = file.stat.blksize || 4096
	  while buf = file.read(bufsiz)
	    tempfile.write(buf)
	  end
	end
      end
      File.rename(tempfile_name, @filename)
    end
  end

  # close and reopen the file, i.e. commit changes to disk and 
  # reload it
  def flush
    close
    reload
  end

  # inspect inside Mp3Info
  def to_s
    s = "MPEG #{@mpeg_version} Layer #{@layer} #{@vbr ? "VBR" : "CBR"} #{@bitrate} Kbps #{@channel_mode} #{@samplerate} Hz length #{@length} sec. header #{@header.inspect} "
    s << "tag1: "+@tag1.inspect+"\n" if hastag1?
    s << "tag2: "+@tag2.inspect+"\n" if hastag2?
    s
  end

  # iterates over each mpeg frame over the file, allowing you to 
  # write some funny things, like an mpeg lossless cutter, or frame
  # counter, or whatever you like ;) +frame+ is a hash with the following keys:
  # :layer, :bitrate, :samplerate, :mpeg_version, :padding and :size (in bytes)
  def each_frame
    File.open(@filename, 'r') do |file|
      file.seek(@first_frame_pos, File::SEEK_SET)
      loop do
        head = file.read(4).unpack("N").first
        frame = Mp3Info.get_frames_infos(head)
        file.seek(frame[:size] -4, File::SEEK_CUR)
        yield frame
        #puts "frame #{frame_count} len #{frame[:length]} br #{frame[:bitrate]} @file.pos #{@file.pos}"
        break if file.eof?
      end
    end
  end

private
  
  def Mp3Info.get_frames_infos(head)
    # be sure we are in sync
    if ((head & 0xffe00000) != 0xffe00000)    || # 11 bit MPEG frame sync
       ((head & 0x00060000) == 0x00060000)    || #  2 bit layer type
       ((head & 0x0000f000) == 0x0000f000)    || #  4 bit bitrate
       ((head & 0x0000f000) == 0x00000000)    || #        free format bitstream
       ((head & 0x00000c00) == 0x00000c00)    || #  2 bit frequency
       ((head & 0xffff0000) == 0xfffe0000) 
      raise Mp3InfoInternalError 
    end
    mpeg_version = [2.5, nil, 2, 1][bits(head, 20,19)]
    
    layer = LAYER[bits(head, 18,17)]
    raise Mp3InfoInternalError if layer == nil || mpeg_version == nil

    bitrate = BITRATE[mpeg_version][layer-1][bits(head, 15,12)-1]
    samplerate = SAMPLERATE[mpeg_version][bits(head, 11,10)]
    padding = (head[9] == 1)
    if layer == 1
      size = (12 * bitrate*1000.0 / samplerate + (padding ? 1 : 0))*4 
    else # layer 2 and 3
      size = 144 * (bitrate*1000.0 / samplerate) + (padding ? 1 : 0)
    end
    size = size.to_i
    { :layer => layer,
      :bitrate => bitrate,
      :samplerate => samplerate,
      :mpeg_version => mpeg_version,
      :padding => padding,
      :size => size }
  end

  ### parses the id3 tags of the currently open @file
  def parse_tags
    return if @file.stat.size < TAG1_SIZE  # file is too small
    @tag1_parsed = false
    @file.seek(0)
    f3 = @file.read(3)
    # v1 tag at beginning
    if f3 == "TAG"  
      gettag1 
      @tag1_parsed = true
    end

    @tag2.from_io(@file) if f3 == "ID3"  # v2 tag at beginning
      
    unless @tag1_parsed         # v1 tag at end
      # this preserves the file pos if tag2 found, since gettag2 leaves
      # the file at the best guess as to the first MPEG frame
      pos = (@tag2.io_position || 0)
      # seek to where id3v1 tag should be
      @file.seek(-TAG1_SIZE, IO::SEEK_END) 
      if @file.read(3) == "TAG"
        gettag1
      end
      @file.seek(pos)
    end
  end
  
  ### gets id3v1 tag information from @file
  ### assumes @file is pointing to char after "TAG" id
  def gettag1
    @tag1_parsed = true
    @tag1["title"] = @file.read(30).unpack("A*").first
    @tag1["artist"] = @file.read(30).unpack("A*").first
    @tag1["album"] = @file.read(30).unpack("A*").first
    year_t = @file.read(4).to_i
    @tag1["year"] = year_t unless year_t == 0
    comments = @file.read(30)
    if comments.getbyte(-2) == 0
      @tag1["tracknum"] = comments.getbyte(-1).to_i
      comments.chop! #remove the last char
    end
    @tag1["comments"] = comments.unpack("A*").first
    @tag1["genre"] = @file.getbyte
    @tag1["genre_s"] = GENRES[@tag1["genre"]] || ""

    # clear empty tags
    @tag1.delete_if { |k, v| v.respond_to?(:empty?) && v.empty? }
    @tag1.delete("genre") if @tag1["genre"] == 255
    @tag1.delete("tracknum") if @tag1["tracknum"] == 0
  end

  ### reads through @file from current pos until it finds a valid MPEG header
  ### returns the MPEG header as FixNum
  def find_next_frame
    # @file will now be sitting at the best guess for where the MPEG frame is.
    # It should be at byte 0 when there's no id3v2 tag.
    # It should be at the end of the id3v2 tag or the zero padding if there
    #   is a id3v2 tag.
    #dummyproof = @file.stat.size - @file.pos => WAS TOO MUCH
    dummyproof = [ @file.stat.size - @file.pos, 2000000 ].min
    dummyproof.times do |i|
      if @file.getbyte == 0xff
        data = @file.read(3)
        raise(Mp3InfoError, "end of file reached") if @file.eof?
        head = 0xff000000 + (data.getbyte(0) << 16) + (data.getbyte(1) << 8) + data.getbyte(2)
        begin
          Mp3Info.get_frames_infos(head)
          return head
        rescue Mp3InfoInternalError
          @file.seek(-3, IO::SEEK_CUR)
        end
      end
    end
    if @file.eof?
      raise Mp3InfoError, "cannot find a valid frame: got EOF"
    else
      raise Mp3InfoError, "cannot find a valid frame after reading #{dummyproof} bytes"
    end
  end

  def frame_scan(frame_limit = nil)
    frame_count = bitrate_sum = 0
    each_frame do |frame|
      bitrate_sum += frame[:bitrate]
      frame_count += 1
      break if frame_limit && (frame_count >= frame_limit)
    end
    
    average_bitrate = bitrate_sum/frame_count.to_f
    length = (frame_count-1) * frame_length
    [average_bitrate, length]
  end


  ### returns the selected bit range (b, a) as a number
  ### NOTE: b > a  if not, returns 0
  def self.bits(number, b, a)
    t = 0
    b.downto(a) { |i| t += t + number[i] }
    t
  end
end

if $0 == __FILE__
  while filename = ARGV.shift
    begin
      info = Mp3Info.new(filename)
      puts filename
      #puts "MPEG #{info.mpeg_version} Layer #{info.layer} #{info.vbr ? "VBR" : "CBR"} #{info.bitrate} Kbps \
      #{info.channel_mode} #{info.samplerate} Hz length #{info.length} sec."
      puts info
    rescue Mp3InfoError => e
      puts "#{filename}\nERROR: #{e}"
    end
    puts
  end
end
