class Torrent
  include Mongoid::Document

  field :fid, type: String
  field :nfo_fid, type: String
  field :filename, type: String
  field :infohash, type: String
  field :orig_created_at, type: String
  field :created_at, type: DateTime, default: ->{ Time.now }
  field :size, type: Integer
  field :piece_length, type: Integer
  field :jsoned_files, type: String

  field :title, type: String
  field :description, type: String
  field :type, type: String
  field :technical, type: String

  belongs_to :user

  def peers
    Peer.where(:torrent_id => self.id)
  end

  def clean
    self.peers.destroy_all
    self.tag.destroy
  end

  def to_hash
    {
      :infohash => self.infohash,
      :title => self.title,
      :type => self.type,
      :description => self.description,
      :size => self.size
    }
  end

end