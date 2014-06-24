class Tracker < Sinatra::Base

  get '/announce' do
    content_type 'text/plain'

    p params

    return failure(403, 'disallowed') unless params['passkey']
    return failure(101, 'info_hash missing') unless params['info_hash'] || params['sha_ih']
    return failure(102, 'peer_id missing') unless params['peer_id']
    return failure(103, 'port missing') unless params['port']
    return failure(151, 'bad peer_id size') if params['peer_id'].size != 20
    
    #return failure(152, 'too much peers wanted') if params['numwant'] && params['numwant'].to_i > settings.ts['max_peers']

    iscompact = params['compact'] || settings.ts['compact']
    no_peer_id = (params['no_peer_id'] && params['no_peer_id'] == '1') || true
    numwant = [params['numwant'].to_i, settings.ts['max_peers']].min

    users = User.where(passkey: params['passkey'])
    torrents = []
    infohash = ''
    if params['sha_ih'] # encrypt traffic
      info_hash = params['sha_ih'].unpack('H*')[0]
      #return failure(150, 'bad info_hash size') if info_hash.size != 40
      torrents = Torrent.where(infohash_sha1: info_hash)
    else # don't encrypt traffic
      info_hash = params['info_hash'].unpack('H*')[0]
      #return failure(150, 'bad info_hash size') if info_hash.size != 40
      torrents = Torrent.where(infohash_sha1: info_hash)
    end
    
    return failure(405, 'no such torrent or user') if users.size == 0 || torrents.size == 0
    
    torrent = torrents.first
    return failure(403, 'wait time in action') if ((Time.now - torrent.created_at) < settings.ts['wait_time']*60)
    user = users.first

    if ['port', 'uploaded', 'downloaded', 'left'].all? {|i| params.keys.include?(i) }
      
      ip = '127.0.0.1' #params['ip'] || params['ipv4'] || request['REMOTE_ADDR'] || request.ip
      left = params['left'].to_i
      port = params['port']

      str_peer = iscompact ? compact(ip, params['port']) : todict(ip, params['port'], no_peer_id)
      
      mes = Peer.where(peer_id: params['peer_id'], ip: ip, port: port, torrent_id: torrent.id)
      me = nil
      is_new = false
      if mes.size > 0
        me = mes.first
      else
        me = Peer.new(peer_id: params['peer_id'], ip: ip, port: port, torrent_id: torrent.id)
        is_new = true
      end

      if left == 0 && !is_new && me.left > 0
        # from leechers to seeders
      end
      

      
      me.connected = true
      peer_id = params['peer_id']
      if params['event'] == 'started'
        Redis.current.hmset(info_hash+peer_id, 
          'compact', compact(ip, port), 
          'dict_no_peer', to_dict(ip, port), 
          'dict_peer', to_dict(ip, port, peer_id)
        )

        # ! seconds !
        Redis.current.expire(info_hash+peer_id, 60*60) # 1 hour
      else
        if settings.ts['seedbonus']['enabled']
          #add seed bonus
          last_updated = me.last_updated
          user.seedbonus += (Time.now - last_updated)/3600*settings.ts['seedbonus']['per_hour'] unless last_updated.nil? || Time.now - last_updated > 60*60
          user.save
        end
      end
      if params['event'] == 'stopped'
        me.connected = false
      end
      
      # save user data in mongo
      me.uploaded = params['uploaded'].to_i
      me.downloaded = params['downloaded'].to_i
      me.left = left
      me.last_updated = Time.now
      
      if me.save
        user.add_peer(me)

        if params['event'] == 'stopped'
          if settings.ts['hit_and_runs']['enabled']
            if me.ratio < settings.ts['min_ratio'].to_f
              user.hit_and_run!
            end
          end
        end

        # -- if we keep seeders/leechers numbers in mongo models:
        if params['event'] == 'stopped'
          left == 0 ? torrent.s_seeders -= 1 : torrent.s_leechers -= 1
        elsif params['event'] == 'started'
          left == 0 ? torrent.s_seeders += 1 : torrent.s_leechers += 1
        elsif params['event'] == 'completed' || left == 0
          torrent.s_seeders += 1
          torrent.s_leechers -= 1
        end
        torrent.save
        # --

        status 200
        l = params['numwant'].to_i || settings.ts['max_peers']
        peers = []
        prs = ''
        out = {
          'interval' => settings.ts['announce_interval'],
          'min interval' => settings.ts['min_interval']
        }
        if left > 0
          #leechers, seeders = redis_find_peers(info_hash, downloaded, left, l)
          leechers, seeders = get_peers(torrent, me.downloaded, me.left, numwant)
          all_peers = leechers.select{|l| l != me} + seeders
          default_type = iscompact ? 'compact' : (no_peer_id ? 'dict_no_peer' : 'dict_peer')
          peers = all_peers.map{ |peer| Redis.current.hget(info_hash+peer.peer_id, default_type) }

          # if iscompact
          #   peers = leechers.map{|l| Redis.hget(info_hash+l.peer_id, 'compact') }.join + 
          #           seeders.map{|s| Redis.hget(info_hash+s.peer_id, 'compact') }.join
          # elsif no_peer_id
          #   peers = leechers.map{|l| Redis.hget(info_hash+l.peer_id, 'dict_no_peer') }.join + 
          #           seeders.map{|s| Redis.hget(info_hash+s.peer_id, 'dict_no_peer') }.join
          # else
          #   peers = leechers.map{|l| Redis.hget(info_hash+l.peer_id, 'dict_peer') }.join + 
          #           seeders.map{|s| Redis.hget(info_hash+s.peer_id, 'dict_peer') }.join
          # end

        end
        # if params['supportcrypto'] == '1' && params['key']
        #   torrent.peers.each {|g| p g.inspect}
        #   pe = PeerEncrypt.new
        #   prs = pe.enc_peers(peers, params['key'], torrent.peers.count)
        #   prs.each {|k,v| out[k] = v }
        # else
        out['peers'] = peers.join
        # end

        p out

        return out.to_ben
      else
        return failure(900, 'something went wrong')
      end
    else
      return failure(900, 'parameters missing')
    end
  end


end 