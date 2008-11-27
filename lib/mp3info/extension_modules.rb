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
    else
      def getbyte(i)
        self[i].ord
      end
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
end
