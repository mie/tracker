require 'uri'

class Tracker < Sinatra::Base

  class RedisMan

    def initialize(infohash, ip, port, peer_id, ipv6 = nil)
      @infohash = infohash
      @port = port
      @ip = ip
      @peer_id = peer_id
      if ipv6
        unescaped = URI.unescape(ipv6)
        if unescaped.include? ('[')
          match = /\[([\:\h]+)\]\:(\d+)/.match(unescaped)
          @ip, @port = match if match
        end
      end
      @compact = compact(ip, port)
      @dict_no_peer_id = to_dict(@ip, @port)
      @dict_peer_id = to_dict(@ip, @port, @peer_id)
    end

    def self.add_torrent(infohash)
      RS.sadd('torrents', infohash)
      RS.del("#{@infohash}_seeders")
      RS.del("#{@infohash}_leechers")
    end

    def del_torrent
      RS.multi {
        RS.srem('torrents', @infohash)
        RS.del("#{@infohash}_leechers")
        RS.del("#{@infohash}_seeders")
      }
    end

    def set_seeder
      RS.multi{
        RS.sadd("#{@infohash}_seeders", @compact)
        RS.srem("#{@infohash}_leechers", @compact)
      }
    end

    def set_leecher
      RS.multi{
        RS.sadd("#{@infohash}_leechers", @compact)
        RS.srem("#{@infohash}_seeders", @compact)
      }
    end

    def add_peer
      RS.hmset(@compact,
        'dict_no_peer', @dict_no_peer_id,
        'dict_peer', @dict_peer_id
      )
    end

    def del_peer
      RS.multi{
        RS.srem("#{@infohash}_leechers", @compact)
        RS.srem("#{@infohash}_seeders", @compact)
      }
    end

    def get_seeders(number)
      RS.srandmember("#{@infohash}_seeders", number)
    end

    def get_leechers(number)
      RS.srandmember("#{@infohash}_leechers", number)
    end

    def get_peers(downloaded, left, numwant)
      leechers_count = RS.scard("#{@infohash}_leechers")
      seeders_count = RS.scard("#{@infohash}_seeders")
      leechers = seeders = nil
      if (leechers_count+seeders_count) <= numwant
        RS.multi {
          RS.srem("#{@infohash}_leechers", @compact)
          leechers = RS.smembers("#{@infohash}_leechers")
          RS.sadd("#{@infohash}_leechers", @compact)
          seeders = RS.smembers("#{@infohash}_seeders")
        }
        return leechers.value, seeders.value
      end

      r = left/(downloaded+left)
      need_leechers = (0.8*r*numwant).floor
      if leechers_count <= need_leechers
        need_leechers = leechers_count
      end
      need_seeders = numwant - need_leechers
      
      RS.multi {
        RS.srem("#{@infohash}_leechers", @compact)
        leechers = get_leechers(need_leechers)
        RS.sadd("#{@infohash}_leechers", @compact)
        seeders = get_seeders(need_seeders)
      }
      return leechers.value, seeders.value
    end

    private

    def compact(ip, port)
      ip.split('.').map { |k| "%02X" % k.to_i}.join() + ("%04X" % port.to_i)
    end

    def to_dict(ip, port, peer_id = nil)
      d = {
        'ip' => ip,
        'port' => port
      }
      #d['peer_id'] = [peer_id].pack('H*') if peer_id
      d['peer_id'] = peer_id if peer_id
      d.to_ben
    end

  end

end