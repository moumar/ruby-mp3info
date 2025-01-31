require 'bindata'
require 'mp3info/frame/apic'

class Mp3Info
  # IDv3 standart has different types of strings with same structure of the body under some
  # header tag or chapter subtag
  #
  # Text encoding           $xx
  # ... various fields. e.g. ULST/COMM (3 bytes for lang); TIT2 (0 bytes)
  # Short content descrip.  <text string according to encoding> $00 (00)
  # The actual text         <full text string according to encoding>
  class Frame
    self.send(:remove_const, :Mp3ChapterOffset) rescue nil
    class Mp3ChapterOffset < BinData::Uint32be
      def sensible_default
        4294967295 # same as no offset, default for writes
      end
    end

    self.send(:remove_const, :TocFlags) rescue nil
    class TocFlags < BinData::Uint8
      def assign(val)
        @value = value
      end

      def value_to_binary_string(val)
        super((val[:top] ? 1 : 0) + (val[:ordered] ? 2 : 0))
      end

      def read_and_return_value(io)
        flags = super
        top = flags & 1 == 1
        ordered = (flags >> 1) & 1 == 1
        { :top => top, :ordered => ordered }
      end

      def sensible_default
        { :top => true, :ordered => true }
      end
    end

    self.send(:remove_const, :SubFrame) rescue nil
    class SubFrame < BinData::Record
      # hide :sub_frame_len, :flags

      string :name, :length => 4
      uint32be :sub_frame_len, :value => lambda {
        if reading?
          @obj.instance_variable_get(:@value)
        else
          require 'pry'; binding.pry if $DEBUG && $DEBUG_WRITE
          was =  @obj.instance_variable_get(:@value)
          now = body.num_bytes
          if now != was
            puts "SubFrame #{name} changed length #{was.inspect} -> #{now.inspect}" if $DEBUG_WRITE
          end
          now
        end
      }
      string :flags, :length => 2
      choice :body, :choices => {
               'WXXX' => [:link, :read_length => :sub_frame_len],
               'APIC' => [:apic, :read_length => :sub_frame_len],
               'TIT2' => [:tit2, :read_length => :sub_frame_len]
             }, :selection => :name
    end

    self.send(:remove_const, :SubFrames) rescue nil
    class SubFrames < BinData::Array
      optional_parameters :read_if
      def initialize_shared_instance
        super
        if has_parameter?(:read_until)
          extend ReadIfPlugin
        end
      end

      module ReadIfPlugin
        def do_read(io)
          loop do
            variables = { index: self.length - 1, element: self.last, array: self }
            require 'pry'; binding.pry if $DEBUG && $DEBUG_READ
            break unless eval_parameter(:read_if, variables)
            element = append_new_element
            element.do_read(io)
            break if eval_parameter(:read_until, variables)
          end
        end
      end
    end

    self.send(:remove_const, :Chapter) rescue nil
    class Chapter < BinData::Record
      # hide :chap_len, :flags, :start_offset, :finish_offset
      # mandatory_parameters :id, :start, :finish # cannot parse with that o_O

      uint32be :chap_len, :value => lambda {
        if reading?
          @obj.instance_variable_get(:@value)
        else
          require 'pry'; binding.pry if $DEBUG && $DEBUG_WRITE
          # 131067
          was =  @obj.instance_variable_get(:@value)
          now = id.num_bytes + start.num_bytes + finish.num_bytes + start_offset.num_bytes + finish_offset.num_bytes + sub_frames.map(&:num_bytes).reduce(:+).to_i
          if now != was
            puts "Chapter #{id} changed length #{was} -> #{now}" if $DEBUG_WRITE
          end
          now
        end
      }
      string :flags, :length => 2

      stringz_to_sym :id
      uint32be :start
      uint32be :finish
      mp3_chapter_offset :start_offset
      mp3_chapter_offset :finish_offset

      # fix upstream: without :read_until it sets zero length
      # https://github.com/dmendel/bindata/blob/v2.4.4/lib/bindata/array.rb#L278L281
      sub_frames :sub_frames, :type => :sub_frame, :read_until => lambda {
        require 'pry'; binding.pry if $DEBUG && $DEBUG_READ
        bytes_left = (chap_len - id.num_bytes - start.num_bytes - finish.num_bytes - start_offset.num_bytes - finish_offset.num_bytes)
        bytes_read = array.map(&:num_bytes).reduce(:+).to_i
        bytes_read >= bytes_left
      }, :read_if => lambda {
        require 'pry'; binding.pry if $DEBUG && $DEBUG_READ
        bytes_left = (chap_len - id.num_bytes - start.num_bytes - finish.num_bytes - start_offset.num_bytes - finish_offset.num_bytes)
        # bytes_left = (chap_len - id.num_bytes - 16 - 4 - 4 - 2 - len)
        bytes_read = array.map(&:num_bytes).reduce(:+).to_i
        bytes_read < bytes_left
      }
    end

    self.send(:remove_const, :Toc) rescue nil
    class Toc < BinData::Record
      stringz_to_sym :id
      toc_flags :flags
      uint8 :children_count, :value => lambda {
        if reading?
          @obj.instance_variable_get(:@value)
        else
          require 'pry'; binding.pry if $DEBUG && $DEBUG_WRITE
          was =  @obj.instance_variable_get(:@value)
          now = children_ids.size
          if now != was
            puts "TOC #{id} changed length #{was.inspect} -> #{now.inspect}" if $DEBUG_WRITE
          end
          now
        end
      }
      array :children_ids, type: :stringz_to_sym, :initial_length => :children_count
    end

    # main wrapper
    self.send(:remove_const, :Frame) rescue nil
    class Frame < BinData::Record
      default_parameter :flags => "\x00\x00"

      string :name, :length => 4 # TODO: must be ascii
      uint32be :frame_len, :value => lambda {
        if reading?
          @obj.instance_variable_get(:@value)
        else
          require 'pry'; binding.pry if $DEBUG && $DEBUG_WRITE
          was =  @obj.instance_variable_get(:@value)
          now = body.num_bytes
          if now != was
            puts "Frame #{name} changed length #{was.inspect} -> #{now.inspect}" if $DEBUG_WRITE
          end
          now
        end
      }
      string :flags, :length => 2

      # now for build/writes, TODO: use for reads
      rest :body
    end
  end
end
