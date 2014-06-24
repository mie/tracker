class User

  include Mongoid::Document

  field :username, type: String
  field :password, type: String
  field :email, type: String
  field :passkey, type: String
  field :seedboxes, type: Array
  field :hit_and_runs, type: Integer, default: 0

  has_many :peers, dependent: :delete
  has_many :torrents
  
  def add_peer(peer)
    self.peers << peer unless self.peers.include? peer
  end

  def del_peer(peer)
    self.peers.delete(peer) if self.peers.include? peer
    peer.delete
  end

  def add_torrent(torrent)
    self.torrents << torrent unless self.torrents.include? torrent
  end

  def active_peers
    self.peers.where(connected: true)
  end

  def connected?
    self.has_peers?
  end

  def uploaded
    sum = 0
    self.peers.each{|u| sum += u.uploaded }
    sum
  end

  def downloaded
    #self.peers.sum(:downloaded)
    sum = 0
    self.peers.each{|u| sum += u.downloaded }
    sum
  end

  def ratio
    downloaded == 0 ? 100500 : uploaded/downloaded
  end

  def seeding
    self.peers.where(:connected => true, :left => 0)
  end

  def seeding_torrents
    self.seeding.map{|peer| peer.torrent }
  end

  def leeching
    self.peers.where(:connected => true, :left => {'$ne' => 0})
  end

  def leeching_torrents
    self.leeching.map{|peer| peer.torrent }
  end

  def del_torrent(torrent)
    self.torrents.delete(torrent) if self.torrents.include?(torrent)
  end

  def hit_and_run!
    self.inc(:hit_and_runs, 1)
    save
  end

  def to_hash
    {
      :username => self.username,
      :email => self.email,
      :hit_and_runs => self.hit_and_runs,
      :passkey => self.passkey
    }
  end

  def add_seedbox(ip, port)
    str = [ip, port].join(':')
    self.seedboxes << str unless self.seedboxes.include?(str)
  end

  def del_seedbox(ip, port)
    str = [ip, port].join(':')
    self.seedboxes.delete(str) if self.seedboxes.include?(str)
  end

end