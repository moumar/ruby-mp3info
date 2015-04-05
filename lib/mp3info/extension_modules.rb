# coding:utf-8
# License:: Ruby
# Author:: Guillaume Pierronnet (mailto:guillaume.pierronnet@gmail.com)

class Mp3Info 
  module HashKeys #:nodoc:
    ### lets you specify hash["key"] as hash.key
    ### this came from CodingInRuby on RubyGarden
    ### http://www.rubygarden.org/ruby?CodingInRuby
    def method_missing(meth,*args)
      m = meth.id2name
      if /=$/ =~ m
	self[m.chop] = (args.length<2 ? args[0] : args)
      else
	self[m]
      end
    end
  end  
  
  class ::String
    if RUBY_VERSION < "1.9.0"
      alias getbyte []
    end
  end

  module Mp3FileMethods #:nodoc: 
    if RUBY_VERSION < "1.9.0"
      def getbyte
        getc
      end
    end
                        
    def get32bits
      (getbyte << 24) + (getbyte << 16) + (getbyte << 8) + getbyte
    end

    def get_syncsafe
      (getbyte << 21) + (getbyte << 14) + (getbyte << 7) + getbyte
    end                 
  end

  class EncodingHelper #:nodoc:
    def self.convert_to(value, from, to)
      if RUBY_1_8
        if to == "iso-8859-1"
          to = to + "//TRANSLIT"
        end
        ruby_18_encode(from, to, value)
      else
        if to == "utf-16"
          ("\uFEFF" +  value).encode("UTF-16LE") # Chab 01.apr.2012 : moved from big to little endian for more compatibility (Windows Media Player, older Quicktime..)
        else
          value.encode(to)
        end
      end
    end

    def self.convert_from_iso_8859_1(value)
      if RUBY_1_8
        ruby_18_encode("utf-8", "iso-8859-1", value)
      else
        value.force_encoding("iso-8859-1").encode("utf-8")
      end
    end

    def self.ruby_18_encode(from, to, value)
      Iconv.iconv(to, from, value).first
    end

    def self.decode_utf16(out)
      if RUBY_1_8
        convert_to(out, "UTF-8", "UTF-16")
      else
        # String#bytes is not an array in Ruby 1.9
        bytes = out.bytes.to_a
        if out.length >= 2 and bytes[0] == 0xff and bytes[1] == 0xfe
          tag_encoding = "UTF-16LE"
          first_valid = 1
        elsif out.length >= 2 and bytes[0] == 0xfe and bytes[1] == 0xff
          tag_encoding = "UTF-16BE"
          first_valid = 1
        else
          # ID3v2.3.0 section 3.3 mandates a BOM but some software
          # erroneously omits it so we have to guess. Since most of
          # the world is little endian we might as well go with that.
          tag_encoding = "UTF-16LE"
          first_valid = 0
        end
        out = out.dup.force_encoding(tag_encoding)[first_valid..-1]
      end
    end
  end
end
