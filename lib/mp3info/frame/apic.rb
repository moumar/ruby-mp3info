require 'bindata'

class Mp3Info
  class Frame
    self.send(:remove_const, :BinImg) rescue nil
    class BinImg < BinData::BasePrimitive
      def value_to_binary_string(value)
      end

      def read_and_return_value(io)
      end

      def sensible_default
        ""
      end
    end

    self.send(:remove_const, :SyncSafeInt) rescue nil
    class SyncSafeInt < BinData::BasePrimitive
      def value_to_binary_string(value)
        a = value >> 21
        b = (value - (a << 24)) >> 14
        c = (value - (a << 24) - (b << 16)) >> 7
        d = value - (a << 24) - (b << 16) - (c << 8)
        [a, b, c, d].pack('C*')
      end

      def read_and_return_value(io)
        bstr = io.readbytes(4)
        (bstr.getbyte(0) << 21) | (bstr.getbyte(1) << 14) | (bstr.getbyte(2) << 7) | bstr.getbyte(3)
      end

      def sensible_default
        0
      end
    end

    self.send(:remove_const, :Stringz8859) rescue nil
    class StringzToSym < BinData::Stringz # NOTE: this should decode ASCII only!
      arg_processor :string

      def assign(val)
        @value = val
      end

      def snapshot
        _value
      end

      def value_to_binary_string(value)
        super(value.to_s.encode('ASCII-8BIT'))
      end

      def read_and_return_value(io)
        super.chomp("\0").to_sym
      end
    end

    self.send(:remove_const, :String8859) rescue nil
    class StringIso8859 < BinData::BasePrimitive
      arg_processor :string
      optional_parameters :read_length

      def value_to_binary_string(value)
        text = Mp3Info::EncodingHelper.convert_to(value[:text], "utf-8", "iso-8859-1")
        url = Mp3Info::EncodingHelper.convert_to(value[:url], "utf-8", "iso-8859-1")
        [text, url].join("\x00")
      end

      def read_and_return_value(io)
        len = eval_parameter(:read_length) || 0
        bstr = io.readbytes(len)
        text, url = Mp3Info::EncodingHelper.convert_from_iso_8859_1(bstr).split("\x00")
        { :text => text, :url => url }
      end

      def sensible_default
        { :text => "", :url => "" }
      end
    end

    self.send(:remove_const, :StringUtf16) rescue nil
    class StringUtf16 < BinData::BasePrimitive
      arg_processor :string
      optional_parameters :read_length

      def value_to_binary_string(value)
        Mp3Info::EncodingHelper.convert_to(value, "utf-8", "utf-16")
      end

      def read_and_return_value(io)
        len = eval_parameter(:read_length) || 0
        bstr = io.readbytes(len)
        Mp3Info::EncodingHelper.decode_utf16(bstr).encode("utf-8")
      end

      def sensible_default
        ""
      end

      # fix upstream: should be default for string?
      def do_num_bytes #:nodoc:
        value_to_binary_string(_value).bytesize
      end
    end

    self.send(:remove_const, :Href) rescue nil
    class Href < StringIso8859
    end

    self.send(:remove_const, :Link) rescue nil
    class Link < BinData::Record # WXXX
      # hide :flags

      default_parameter :flags => "\x00\x00"
      default_parameter :encoding_index => 1

      uint8 :encoding_index
      href :href, :read_length => lambda {
        require 'pry'; binding.pry if $DEBUG && $DEBUG_READ

        sub_frame_len - 1 } # 1 - encoding byte
    end

    self.send(:remove_const, :Apic) rescue nil
    class Apic < BinData::Record
      hide :data #, :flags

      default_parameter :image_type => 0
      default_parameter :flags => "\x00\x00"
      default_parameter :encoding_index => 1

      ENCODING_SIZE = 1
      uint8 :encoding_index
      stringz :mime
      uint8 :image_type
      stringz :description # FIXME: now ASCII-8BIT. Need iso8859z, utf16z, utf8z classes
      string :data, :read_length => lambda {
        require 'pry'; binding.pry if $DEBUG && $DEBUG_READ

        sub_frame_len - 1 - mime.num_bytes - 1 - description.num_bytes } # 1 - encoding byte
    end

    self.send(:remove_const, :Tit2) rescue nil
    class Tit2 < BinData::Record
      # hide :len, :rest, :flags, :name, :encoding_index
      default_parameter :encoding_index => 1

      ENCODING_SIZE = 1
      uint8 :encoding_index
      choice :title, :choices => {
               0 => [:string_iso8859, {:read_length => lambda { sub_frame_len - ENCODING_SIZE }}],
               1 => [:string_utf16, {:read_length => lambda { sub_frame_len - ENCODING_SIZE }}],
               2 => [:string_utf16, {:read_length => lambda { sub_frame_len - ENCODING_SIZE }}],
               3 => [:string, {:read_length => lambda { sub_frame_len - ENCODING_SIZE }}]
             }, :selection => :encoding_index
    end

  end
end
