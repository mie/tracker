require 'digest/sha1'
require File.join(File.dirname(__FILE__), '..', '..', 'lib',  'rc4.rb')

module PeersEncryption

  class PeerEncrypt

    # def initialize(infohash)
    #   @iv = rand(1024).to_s(16)
    #   @infohash = infohash
    #   key = Digest::SHA1.hexdigest(@infohash + @iv)
    #   @rc4 = RC4.new(key)
    #   @rc4.generate(768)   # discard first 768
    #   @x = @rc4.generate(4).join
    #   @y = @rc4.generate(4).join
    # end

    def xor(plaintext, pseudo)
      isint = false
      if plaintext.kind_of? Integer
        plaintext = "%X" % plaintext
        isint = true
      end
      n = pseudo.size
      
      #ciphertext = ''
      #plaintext.chars.each_with_index { |c,i| ciphertext += (pseudo[i%n].ord ^ plaintext[i].ord).chr }
      #p ciphertext
      ciphertext = (pseudo.to_i(16) ^ plaintext.to_i(16)).to_s(16)
      
      ciphertext = ciphertext.unpack('I!')[0] if isint
      ciphertext
    end

    def enc_peers(peers, key, torrent_peers = 100)
      p peers, key, torrent_peers
      n = peers.size
      rc4 = RC4.new(key)
      pseudo = rc4.generate(n*6).join
      rc4.generate(768)
      x = rc4.generate(4).join
      y = rc4.generate(4).join
      encoded_peers = xor(peers.join, pseudo)
      i = rand(torrent_peers - n)
      {
        #'iv' => @iv,
        'i' => xor(i, x),
        'n' => xor(n, y),
        'peers' => encoded_peers
        #'x' => @x,
        #'y' => @y
      }
    end

  end

end