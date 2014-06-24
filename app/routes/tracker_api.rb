require 'tmpdir'
require 'base64'
require 'stringio'
require 'securerandom'

class Tracker < Sinatra::Base

  get '/torrents/:infohash' do
    p params
    return json_status(400, 'Bad request') unless params.include?('passkey')
    torrent = Torrent.find_by(infohash: params['infohash'])
    user = User.find_by(passkey: params['passkey'])
    return json_status(401, 'Not authorized') unless user
    return json_status(404, 'No such torrent') unless torrent
    data = Bencode.parse(FS.get(torrent.fid).data)
    data['announce'] = "http://#{request.host}:#{request.port}/announce?passkey="+user.passkey
    data['announce-list'] = [["http://#{request.host}/announce?passkey="+user.passkey]]
    data['comment'] = 'BFTT'
    content_type 'application/octet-stream'
    attachment(torrent.filename + '.torrent')
    response.write(data.to_ben)
  end

  get '/torrents/?' do
    torrents = Torrent.all
    content_type :json
    torrents.map{|t| t.to_hash}.to_json
  end

  post '/torrents/?' do
    # FS::File.delete_all
    # FS::Chunk.delete_all
    # Torrent.all.first.delete
    content_type :json
    data = request.body.read
    jd = JSON.parse(data)
    return json_status(400, 'missing parameter') unless ['passkey', 'torrentfile', 'title', 'description', 'type', 'technical'].all? {|o| jd.include? o}
    user = User.find_by(passkey: jd['passkey'])
    return json_status(401, 'Not authorized') unless user
    
    meta = Bencode.parse(Base64.decode64(jd['torrentfile']))
    
    creation_date = meta['creation date']
    piece_length = meta['info']['piece length']
    jsoned_files = meta['info']['files'] ? JSON.generate({:files => meta['info']['files']}) : JSON.generate({:files => meta['info']['name']})
    torrent_size = meta['info']['files'] ? 0 : meta['info']['length']
    meta['info']['files'].each { |f|
      torrent_size += f['length']
    } if meta['info']['files']

    info = {'info' => meta['info']}.to_ben
    return json_status(400, 'Bad .torrent-file') unless info

    sha = Digest::SHA1.hexdigest(meta["info"].to_ben)
    infofile = StringIO.new(info)
    
    nfo = jd['nfo']
    
    title = jd['title'].downcase.gsub(/[^a-zA-Z0-9]+/, '.')+'.BFTT'
    
    #title = params['title'].downcase.gsub(/[\s|\-|_|\.|!|\?]+/, '_')+sha[0,19]
    #redirect '/'
    
    fid = FS.put(infofile, :filename => sha+'.torrent').id
    nfofid = ""
    if nfo
      nfofile = StringIO.new(Base64.decode(nfo))
      nfofid = FS.put(nfofile, :filename => sha+'.nfo').id
    end
    
    t = Torrent.new(:fid => fid,
      :infohash_sha1 => Digest::SHA1.hexdigest(sha),
      :infohash => sha,
      :filename => title,
      :size => torrent_size,
      :orig_created_at => creation_date,
      :piece_length => piece_length,
      :jsoned_files => jsoned_files,

      :title => jd['title'],
      :description => jd['description'],
      :type => jd['type'],
      :technical => jd['technical']
    )
    t.nfo_fid = nfofid if nfo
    t.save
    
    user.add_torrent(t)
    RedisMan.add_torrent(sha)
    t.to_hash.to_json
  end

  delete '/torrents/:tid' do
    torrent = Torrent.find_by(_id: params['tid'])
    return json_status(404, 'Not found') unless torrent
    torrent.destroy
    content_type :json
    json_status(200, 'OK')
  end

  get '/users/:username' do
    user = User.find_by(username: params['username'])
    return json_status(404, 'Not found') unless user
    content_type :json
    return user.to_hash.to_json
  end

  get '/users/?' do
    users = User.all
    content_type :json
    users.map{ |u| u.to_hash }.to_json
  end

  post '/users/?' do
    content_type :json
    data = request.body.read
    jd = JSON.parse(data)
    return json_status(400, 'missing parameter') unless ['username', 'email', 'password'].all? {|o| jd.include? o}
    users = User.any_of({:username => jd['username']}, {:email => jd['email']})
    return json_status(405, 'User already exists') unless users.count == 0

    u = User.new(:username => jd['username'], :password => jd['password'], :email => jd['email'])
    u.passkey = SecureRandom.hex(12)
    u.save

    u.to_json
  end

  delete '/users/:username' do
    user = User.find_by(username: params['username'])
    return json_status(404, 'Not found') unless user
    user.destroy
    content_type :json
    json_status(200, 'OK')
  end



end