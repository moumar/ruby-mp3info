# encoding: utf-8
# License:: Ruby
# Author:: Guillaume Pierronnet (mailto:guillaume.pierronnet@gmail.com)

require "delegate"

require "mp3info/extension_modules"

class ID3v2Error < StandardError ; end

# This class can be used to decode id3v2 tags from files, like .mp3 or .ape for example.
# It works like a hash, where key represents the tag name as 3 or 4 upper case letters
# (respectively related to 2.2 and 2.3+ tag) and value represented as array or raw value.
# Written version is always 2.3.
class ID3v2 < DelegateClass(Hash)

  TAGS = {
    "AENC" => "Audio encryption",
    "APIC" => "Attached picture",
    "COMM" => "Comments",
    "COMR" => "Commercial frame",
    "ENCR" => "Encryption method registration",
    "EQUA" => "Equalization",
    "ETCO" => "Event timing codes",
    "GEOB" => "General encapsulated object",
    "GRID" => "Group identification registration",
    "IPLS" => "Involved people list",
    "LINK" => "Linked information",
    "MCDI" => "Music CD identifier",
    "MLLT" => "MPEG location lookup table",
    "OWNE" => "Ownership frame",
    "PRIV" => "Private frame",
    "PCNT" => "Play counter",
    "POPM" => "Popularimeter",
    "POSS" => "Position synchronisation frame",
    "RBUF" => "Recommended buffer size",
    "RVAD" => "Relative volume adjustment",
    "RVRB" => "Reverb",
    "SYLT" => "Synchronized lyric/text",
    "SYTC" => "Synchronized tempo codes",
    "TALB" => "Album/Movie/Show title",
    "TBPM" => "BPM (beats per minute)",
    "TCOM" => "Composer",
    "TCON" => "Content type",
    "TCOP" => "Copyright message",
    "TDAT" => "Date",
    "TDLY" => "Playlist delay",
    "TENC" => "Encoded by",
    "TEXT" => "Lyricist/Text writer",
    "TFLT" => "File type",
    "TIME" => "Time",
    "TIT1" => "Content group description",
    "TIT2" => "Title/songname/content description",
    "TIT3" => "Subtitle/Description refinement",
    "TKEY" => "Initial key",
    "TLAN" => "Language(s)",
    "TLEN" => "Length",
    "TMED" => "Media type",
    "TOAL" => "Original album/movie/show title",
    "TOFN" => "Original filename",
    "TOLY" => "Original lyricist(s)/text writer(s)",
    "TOPE" => "Original artist(s)/performer(s)",
    "TORY" => "Original release year",
    "TOWN" => "File owner/licensee",
    "TPE1" => "Lead performer(s)/Soloist(s)",
    "TPE2" => "Band/orchestra/accompaniment",
    "TPE3" => "Conductor/performer refinement",
    "TPE4" => "Interpreted, remixed, or otherwise modified by",
    "TPOS" => "Part of a set",
    "TPUB" => "Publisher",
    "TRCK" => "Track number/Position in set",
    "TRDA" => "Recording dates",
    "TRSN" => "Internet radio station name",
    "TRSO" => "Internet radio station owner",
    "TSIZ" => "Size",
    "TSRC" => "ISRC (international standard recording code)",
    "TSSE" => "Software/Hardware and settings used for encoding",
    "TYER" => "Year",
    "TXXX" => "User defined text information frame",
    "UFID" => "Unique file identifier",
    "USER" => "Terms of use",
    "USLT" => "Unsychronized lyric/text transcription",
    "WCOM" => "Commercial information",
    "WCOP" => "Copyright/Legal information",
    "WOAF" => "Official audio file webpage",
    "WOAR" => "Official artist/performer webpage",
    "WOAS" => "Official audio source webpage",
    "WORS" => "Official internet radio station homepage",
    "WPAY" => "Payment",
    "WPUB" => "Publishers official webpage",
    "WXXX" => "User defined URL link frame"
  }

  # Translate V2 to V3 tags
  TAG_MAPPING_2_2_to_2_3 = {
    "BUF"   => "RBUF",
    "COM"   => "COMM",
    "CRA"   => "AENC",
    "EQU"   => "EQUA",
    "ETC"   => "ETCO",
    "GEO"   => "GEOB",
    "MCI"   => "MCDI",
    "MLL"   => "MLLT",
    "PIC"   => "APIC",
    "POP"   => "POPM",
    "REV"   => "RVRB",
    "RVA"   => "RVAD",
    "SLT"   => "SYLT",
    "STC"   => "SYTC",
    "TAL"   => "TALB",
    "TBP"   => "TBPM",
    "TCM"   => "TCOM",
    "TCO"   => "TCON",
    "TCR"   => "TCOP",
    "TDA"   => "TDAT",
    "TDY"   => "TDLY",
    "TEN"   => "TENC",
    "TFT"   => "TFLT",
    "TIM"   => "TIME",
    "TKE"   => "TKEY",
    "TLA"   => "TLAN",
    "TLE"   => "TLEN",
    "TMT"   => "TMED",
    "TOA"   => "TOPE",
    "TOF"   => "TOFN",
    "TOL"   => "TOLY",
    "TOR"   => "TORY",
    "TOT"   => "TOAL",
    "TP1"   => "TPE1",
    "TP2"   => "TPE2",
    "TP3"   => "TPE3",
    "TP4"   => "TPE4",
    "TPA"   => "TPOS",
    "TPB"   => "TPUB",
    "TRC"   => "TSRC",
    "TRD"   => "TRDA",
    "TRK"   => "TRCK",
    "TSI"   => "TSIZ",
    "TSS"   => "TSSE",
    "TT1"   => "TIT1",
    "TT2"   => "TIT2",
    "TT3"   => "TIT3",
    "TXT"   => "TEXT",
    "TXX"   => "TXXX",
    "TYE"   => "TYER",
    "UFI"   => "UFID",
    "ULT"   => "USLT",
    "WAF"   => "WOAF",
    "WAR"   => "WOAR",
    "WAS"   => "WOAS",
    "WCM"   => "WCOM",
    "WCP"   => "WCOP",
    "WPB"   => "WPB",
    "WXX"   => "WXXX",
  }

  # See id3v2.4.0-structure document, at section 4.
  TEXT_ENCODINGS = ["iso-8859-1", "utf-16", "utf-16be", "utf-8"]

  include Mp3Info::HashKeys

  # In Ruby 2.1.0 (and possibly others), DelegateClass breaks Kernel methods.
  include Kernel

  # this is the position in the file where the tag really ends
  attr_reader :io_position

  # :+lang+: for writing comments
  #
  # [DEPRECATION] :+encoding+: one of the string of +TEXT_ENCODINGS+,
  # use of :encoding parameter is DEPRECATED. In ruby 1.8, use utf-8 encoded strings for tags.
  # In ruby >= 1.9, strings are automatically transcoded from their originaloriginal  encoding.
  attr_reader :options

  # possible options are described above ('options' attribute)
  # you can access this object like an hash, with [] and []= methods
  # special cases are ["disc_number"] and ["disc_total"] mirroring TPOS attribute
  def initialize(options = {})
    @options = { :lang => "ENG" }
    if @options[:encoding]
      warn("use of :encoding parameter is DEPRECATED. In ruby 1.8, use utf-8 encoded strings for tags.\n" +
           "In ruby >= 1.9, strings are automatically transcoded from their original encoding.")
    end

    @options.update(options)

    @hash = {}
    #TAGS.keys.each { |k| @hash[k] = nil }
    @hash_orig = {}
    super(@hash)
    @parsed = false
    @version_maj = @version_min = nil
  end

  # does this tag has been correctly read ?
  def parsed?
    @parsed
  end

  # does this tag has been changed ?
  def changed?
    @hash_orig != @hash
  end

  # full version of this tag (like "2.3.0") or nil
  # if tag was not correctly read
  def version
    if @version_maj && @version_min
      "2.#{@version_maj}.#{@version_min}"
    else
      nil
    end
  end

  ### cuts out long tag values from hash for display on screen
  def to_inspect_hash
    result = Marshal.load(Marshal.dump(self.to_hash))
    result.each do |k,v|
      if v.is_a? Array
        v.each_index do |i, item|
          if (v[i].is_a? String and v[i].length > 128)
            result[k][i] = pretty_header(v[i])
          end
        end
      elsif v.is_a? String and v.length > 128
        result[k] = pretty_header(v) # this method 'snips' long data
      end
    end
    result
  end

  ### ID3V2::add_picture
  ### Takes an image string as input and writes it with header.
  ### Mime type is automatically guessed by default.
  ### It is possible but not necessary to include:
  ###  :pic_type => 0 - 14 (see http://id3.org/id3v2.3.0#Attached_picture)
  ###  :mime => 'gif'
  ###  :description => "Image description"
  def add_picture(data, opts = {})
    options = {
                :pic_type => 0,
                :mime => nil,
                :description => "image"
              }
    options.update(opts)
    jpg = Regexp.new( "^\xFF".force_encoding("BINARY"),
                 Regexp::FIXEDENCODING )
    png = Regexp.new( "^\x89PNG".force_encoding("BINARY"),
                 Regexp::FIXEDENCODING )
    gif = Regexp.new( "^\x89GIF".force_encoding("BINARY"),
                 Regexp::FIXEDENCODING )

    mime = options[:mime]
    mime ||= "jpg" if data.match jpg
    mime ||= "png" if data.match png
    mime ||= "gif" if data.match gif
    pic_type = options[:pic_type]
    pic_type = ["%02i" % pic_type].pack('H*')
    desc = "#{options[:description]}"
    header = "\x00image/#{mime}\x00#{pic_type}#{desc}\x00"
    self["APIC"] = header + data.force_encoding('BINARY')
  end

  ### Returns an array of images:
  ###   [  ["01_.jpg", "Image Data in Binary String"],
  ###      ["02_.png", "Another Image in a String"]    ]
  ###
  ### e.g. to write all images:
  ### mp3.tag2.pictures.each do |image|
  ###   File.open(img[0], 'wb'){|f| f.write img[1])
  ### end
  def pictures
    apic_images = [self["APIC"]].flatten.dup
    result = []
    apic_images.each_index do |index|
      pic = apic_images[index]
      next if !pic.is_a?(String) or pic == ""
      pic.force_encoding 'BINARY'
      picture = []
      jpg_regexp = Regexp.new("jpg|JPG|jpeg|JPEG".force_encoding("BINARY"),
                   Regexp::FIXEDENCODING )
      png_regexp = Regexp.new("png|PNG".force_encoding("BINARY"),
                   Regexp::FIXEDENCODING )
      header = pic.unpack('a120').first.force_encoding "BINARY"
      mime_pos = 0

      # safest way to correctly extract jpg and png is finding mime
      if header.match jpg_regexp and not header.match png_regexp
        mime = "jpg"
        mime_pos = header =~ jpg_regexp
        start = Regexp.new("\xFF\xD8".force_encoding("BINARY"),
                Regexp::FIXEDENCODING )
        start_with_anchor = Regexp.new("^\xFF\xD8".force_encoding("BINARY"),
                                       Regexp::FIXEDENCODING )
      end

      if header.match png_regexp and not header.match jpg_regexp
        mime = "png"
        mime_pos = header =~ png_regexp
        start = Regexp.new("\x89PNG".force_encoding("BINARY"),
                Regexp::FIXEDENCODING )
        start_with_anchor = Regexp.new("^\x89PNG".force_encoding("BINARY"),
                            Regexp::FIXEDENCODING )
      end

      puts "analysing image: #{header.inspect}..." if $DEBUG
      _, _, desc, data = pic[mime_pos, pic.length].unpack('Z*hZ*a*')

      if mime
        if !data.match(start_with_anchor) or data.nil?
          real_start = pic =~ start
          data = pic[real_start, pic.length]
        end

        if mime == "jpg"
          # inspect jpg image header (first 10 chars) for "\xFF\x00" (expect "\xFF")
          trailing_null_byte = Regexp.new("(\377)(\000)".force_encoding('BINARY'),
                                          Regexp::FIXEDENCODING)
          md = data =~ trailing_null_byte
          if !md.nil? and md < 10
            data.gsub!(trailing_null_byte, "\xff".force_encoding('BINARY'))
          end
        end
      else
        mime = "dat"
        # if no jpg or png, extract data anyway e.g. gif
        mime, desc, data = pic.unpack('h Z* h Z* a*').values_at(1,3,4)
      end

      filename = ("%02i_#{desc[0,25]}" % (index + 1)).gsub('/','')

      picture[0] = filename
      picture[1] = data
      result << picture
    end
    result
  end

  def inspect
    self.to_inspect_hash
  end

  def remove_pictures
    self["APIC"] = ""
    self["PIC"]  = ""
  end

  ### gets id3v2 tag information from io object (must support #seek() method)
  def from_io(io)
    @io = io
    original_pos = @io.pos
    @io.extend(Mp3Info::Mp3FileMethods)
    version_maj, version_min, flags = @io.read(3).unpack("CCB4")
    @unsync, ext_header, _, _ = (0..3).collect { |i| flags[i].chr == '1' }  # _, _ = experimental, footer
    raise(ID3v2Error, "can't find version_maj ('#{version_maj}')") unless [2, 3, 4].include?(version_maj)
    @version_maj, @version_min = version_maj, version_min
    @tag_length = @io.get_syncsafe

    @parsed = true
    begin
      case @version_maj
        when 2
          read_id3v2_2_frames
        when 3, 4
          # seek past extended header if present
          @io.seek(@io.get_syncsafe - 4, IO::SEEK_CUR) if ext_header
          read_id3v2_3_frames
      end
    rescue ID3v2Error => e
      warn("warning: id3v2 tag not fully parsed: #{e.message}")
    end
    @io_position = @io.pos
    @tag_length = @io_position - original_pos

    @hash_orig = @hash.dup
    #no more reading
    @io = nil
  end

  # dump tag for writing. Version is always 2.3.0
  def to_bin
    #TODO handle of @tag2[TLEN"]
    #TODO add of crc
    #TODO add restrictions tag

    tag = ""
    @hash.each do |k, v|
      next unless v
      next if v.respond_to?("empty?") and v.empty?

      # Automagically translate V2 to V3 tags
      k = TAG_MAPPING_2_2_to_2_3[k] if TAG_MAPPING_2_2_to_2_3.has_key?(k)

      # doesn't encode id3v2.2 tags, which have 3 characters
      next if k.size != 4

      # Output one flag for each array element, or one only if it's not an array
      [v].flatten.each do |value|
        data = encode_tag(k, value.to_s)
        #data << "\x00"*2 #End of tag

        tag << k[0,4]   #4 characte max for a tag's key
        #tag << to_syncsafe(data.size) #+1 because of the language encoding byte
        size = data.size
        size = data.dup.force_encoding("binary").size
        tag << [size].pack("N") #+1 because of the language encoding byte
        tag << "\x00"*2 #flags
        tag << data
      end
    end

    tag_str = "ID3"
    #version_maj, version_min, unsync, ext_header, experimental, footer
    tag_str << [ 3, 0, "0000" ].pack("CCB4")
    tag_str << [to_syncsafe(tag.size)].pack("N")
    tag_str << tag
    puts "tag in binary format: #{tag_str.inspect}" if $DEBUG
    tag_str
  end

  private

  def encode_tag(name, value)
    puts "encode_tag(#{name.inspect}, #{value.inspect})" if $DEBUG
    name = name.to_s

    if name =~ /^(COM|T|USLT)/
      transcoded_value = Mp3Info::EncodingHelper.convert_to(value, "utf-8", "utf-16")
    end
    case name
    when "COMM", "USLT"
      puts "encode #{name} lang: #{@options[:lang]}, value #{transcoded_value.inspect}" if $DEBUG
      s = [ 1, @options[:lang], "\xFE\xFF\x00\x00", transcoded_value].pack("ca3a*a*")
      return s
    when /^T/
      transcoded_value.force_encoding("BINARY")

	return "\x01" + transcoded_value
      else
        return value
    end
  end

  ### Read a tag from file and perform UNICODE translation if needed
  def decode_tag(name, raw_value)
    puts("decode_tag(#{name.inspect}, #{raw_value.inspect})") if $DEBUG
    if name =~ /^(T|COM|USLT)/
      begin
        if name =~ /^(COM|USLT)/
          encoding_index, lang, raw_tag = raw_value.unpack("ca3a*")
          if raw_tag == "\x00"
            return nil
          else
            if encoding_index == 1
              split_str = /\x00\x00\x00?/
            else
              split_str = "\x00"
            end
            head, tail = raw_tag.split(split_str)
            if head == "\xFF\xFE".force_encoding('binary')
              rgx = Regexp.new("^\xFF\xFE\x00\x00".force_encoding("BINARY"))
              out = raw_tag.sub(rgx, '')
            elsif tail
              out = tail
            elsif head
              out = head
            else
              warn("warning: cannot decode tag #{name} with raw value #{raw_value.inspect}")
              return nil
            end
          end
          puts "COM tag found. encoding: #{encoding_index} lang: #{lang} str: #{out.inspect}" if $DEBUG
        else
          encoding_index = raw_value.getbyte(0) # language encoding (see TEXT_ENCODINGS constant)
          out = raw_value[1..-1]
        end
        # we need to convert the string in order to match
        # the requested encoding
        if TEXT_ENCODINGS[encoding_index]
          if encoding_index == 1
            out = Mp3Info::EncodingHelper.decode_utf16(out)
          else
            out.force_encoding(TEXT_ENCODINGS[encoding_index])
          end
          out.encode!("utf-8")
        end

        # remove padding zeros for textual tags
        r = Regexp.new("\x00*$".encode(out.encoding))
        out.sub!(r, '')

        return out
      rescue => e
        warn "warning: cannot decode tag #{name} with raw value #{raw_value.inspect}: #{e}"
        return nil
      end
    else
      return raw_value
    end
  end

  ### reads id3 ver 2.3.x/2.4.x frames and adds the contents to @tag2 hash
  ### NOTE: the id3v2 header does not take padding zero's into consideration
  def read_id3v2_3_frames
    loop do # there are 2 ways to end the loop
      name = @io.read(4)
      if name.nil? || name.getbyte(0) == 0 || name == "MP3e" #bug caused by old tagging application "mp3ext" ( http://www.mutschler.de/mp3ext/ )
        @io.seek(-4, IO::SEEK_CUR)    # 1. find a padding zero,
	seek_to_v2_end
        break
      else
	if @version_maj == 4
	  size = @io.get_syncsafe
	else
	  size = @io.get32bits
	end
        @io.seek(2, IO::SEEK_CUR)     # skip flags
        puts "name '#{name}' size #{size}" if $DEBUG
        add_value_to_tag2(name, size)
      end
      break if @io.pos >= @tag_length # 2. reach length from header
    end
  end

  ### reads id3 ver 2.2.x frames and adds the contents to @tag2 hash
  ### NOTE: the id3v2 header does not take padding zero's into consideration
  def read_id3v2_2_frames
    loop do
      name = @io.read(3)
      if name.nil? || name.getbyte(0) == 0
        @io.seek(-3, IO::SEEK_CUR)
	seek_to_v2_end
        break
      else
        size = (@io.getbyte << 16) + (@io.getbyte << 8) + @io.getbyte
	add_value_to_tag2(name, size)
        break if @io.pos >= @tag_length
      end
    end
  end

  ### Add data to tag2["name"]
  ### read lang_encoding, decode data if unicode and
  ### create an array if the key already exists in the tag
  def add_value_to_tag2(name, size)
    puts "add_value_to_tag2" if $DEBUG

    if size > 50_000_000
      raise ID3v2Error, "tag size is > 50_000_000"
    end

    data_io = @io.read(size)
    data = decode_tag(name, data_io)
    if data && !data.empty?
      if self.keys.include?(name)
        if self[name].is_a?(Array)
          unless self[name].include?(data)
            self[name] << data
          end
        else
          self[name] = [ self[name], data ]
        end
      else
        self[name] = data
      end

      if name == "TPOS" && data =~ /(\d+)\s*\/\s*(\d+)/
        self["disc_number"] = $1.to_i
        self["disc_total"] = $2.to_i
      end
    end

    puts "self[#{name.inspect}] = #{self[name].inspect}" if $DEBUG
  end

  ### runs thru @file one char at a time looking for best guess of first MPEG
  ###  frame, which should be first 0xff byte after id3v2 padding zero's
  def seek_to_v2_end
    until @io.getbyte == 0xff
      raise ID3v2Error, "got EOF before finding id3v2 end" if @io.eof?
    end
    @io.seek(-1, IO::SEEK_CUR)
  end

  ### convert an 32 integer to a syncsafe string
  def to_syncsafe(num)
    ( (num<<3) & 0x7f000000 )  + ( (num<<2) & 0x7f0000 ) + ( (num<<1) & 0x7f00 ) + ( num & 0x7f )
  end

  ### this is especially useful for printing out APIC data because
  ### only the header of the APIC tag is of interest
  def pretty_header(str, chars=128)
    "#{str.unpack("a#{chars}").first}<<<...snip...>>>".inspect[1..-2]
  end

end
