class Tracker < Sinatra::Base

  get '/announce' do
    content_type 'text/plain'

    TrackerLogger.debug "incoming: #{params}"

    return failure(403, 'disallowed') unless params['passkey']
    return failure(101, 'info_hash missing') unless params['info_hash'] || params['sha_ih']
    return failure(102, 'peer_id missing') unless params['peer_id']
    return failure(103, 'port missing') unless params['port']
    return failure(151, 'bad peer_id size') if params['peer_id'].size != 20
    
    #return failure(152, 'too much peers wanted') if params['numwant'] && params['numwant'].to_i > settings.ts['max_peers']

    iscompact = params['compact'] || settings.ts['compact']
    no_peer_id = (params['no_peer_id'] && params['no_peer_id'] == '1') || false
    numwant = [params['numwant'].to_i, settings.ts['max_peers']].min

    user = User.find_by(passkey: params['passkey'])
    return failure(405, 'no such user') unless user

    infohash = params['info_hash'].unpack('H*')[0]
    torrent = Torrent.find_by(infohash: infohash)
    return failure(405, 'no such torrent') unless torrent
    
    return failure(403, 'wait time in action') if ((Time.now - torrent.created_at) < settings.ts['wait_time']*60)
    
    if ['port', 'uploaded', 'downloaded', 'left'].all? {|i| params.keys.include?(i) }
      
      ip = params['ip'] || params['ipv4'] || request['REMOTE_ADDR'] || request.ip
      ipv6 = params['ipv6']
      left = params['left'].to_i
      port = params['port'].to_i

      rman = RedisMan.new(infohash, ip, port, params['peer_id'], ipv6)

      str_peer = compact(ip, params['port'])# : todict(ip, params['port'], no_peer_id)
      
      peer_id = params['peer_id']
      me = user.peers.find_by(torrent_id: torrent.id)
      
      me ||= Peer.new(torrent_id: torrent.id)
      
      if params['event'] == 'started'
        rman.add_peer#(infohash, peer_id, [compact(ip, port), to_dict(ip, port), to_dict(ip, port, peer_id)])
      else
        #rman.touch_peer(infohash, peer_id)
        # if settings.ts['seedbonus']['enabled']
        #   #add seed bonus
        #   last_updated = me.last_updated
        #   user.seedbonus += (Time.now - last_updated)/3600*settings.ts['seedbonus']['per_hour'] unless last_updated.nil? || Time.now - last_updated > 60*60
        #   user.save
        # end
      end
      
      # save user data in mongo
      me.uploaded = params['uploaded'].to_i
      me.downloaded = params['downloaded'].to_i
      me.left = left
      me.last_updated = Time.now
      
      if me.save
        if left > 0
          rman.set_leecher
        else
          rman.set_seeder
        end
        user.add_peer(me)

        if params['event'] == 'stopped'
          rman.del_peer
          if settings.ts['hit_and_runs']['enabled']
            if me.ratio < settings.ts['min_ratio'].to_f
              user.hit_and_run!
            end
          end
        end

        torrent.save
        
        peers = []
        peers6 = []
        out = {
          'interval' => settings.ts['announce_interval'],
          'min interval' => settings.ts['min_interval']
        }
        if left > 0
          l,s = rman.get_peers(me.downloaded, me.left, numwant)
          peers = l+s
        end
        peers, peers6 = peers.partition{ |peer| peer.size == 10 }
        out['peers'] = peers.join
        out['peers6'] = peers6.join if peers6.size > 0
        out['complete'] = s ? s.size : 0
        out['incomplete'] = l ? l.size : 0

        status 200
        return out.to_ben unless params['event'] == 'stopped'
      else
        return failure(900, 'something went wrong')
      end
    else
      return failure(900, 'parameters missing')
    end
  end


end 