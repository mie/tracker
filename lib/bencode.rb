# Copyright (C) 2012 Daehyun Kim <https://github.com/hatemogi>

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'stringio'

class Fixnum
  # bencode
  def to_ben
    d = to_s(10)
    "i#{d}e"
  end
end

class String
  # bencode
  def to_ben
    u = self#.encode('utf-8')
    "#{u.bytesize}:#{u}"
  end
end

class Symbol
  # bencode
  def to_ben
    to_s.gsub("_", " ").to_ben
  end
end

class Hash
  # bencode
  def to_ben
    'd' + keys.sort.collect {|k| k.to_ben + self[k].to_ben}.join + 'e' 
  end
end

class Array
  # bencode
  def to_ben
    'l' + collect(&:to_ben).join + 'e'
  end
end

module Bencode
  class Parser
    def initialize io 
      @io = io
    end

    def parse_string start_with
      len = start_with
      until (c = @io.getc) == ':'
        len += c
      end  
      len = len.to_i
      str = @io.read(len)
    end

    def parse_number
      num = ''
      until (c = @io.getc) == 'e'
        num += c
      end  
      num.to_i
    end

    def parse_array
      r = []
      until (c = @io.getc) == 'e'
        @io.ungetc c
        r << parse
      end
      r
    end

    def parse_hash
      r = {}
      until (c = @io.getc) == 'e'
        r[parse_string c] = parse
      end
      r
    end

    def parse
      case c = @io.getc
      when '0'..'9'
        parse_string c
      when 'i'
        parse_number 
      when 'l'
        parse_array
      when 'd'
        parse_hash
      end    
    end
  end

  # Parse a bencoded string or IO object
  #
  # Example:
  #   >> Bencode.parse('11:Hello World')
  #   => 'Hello World'
  #
  # Arguments:
  #   str: (String or IO)

  def self.parse str
    istream = StringIO.new(str)
    Parser.new(istream).parse
  end
end
