class Peer

  include Mongoid::Document

  field :torrent_id, type: Moped::BSON::ObjectId
  field :uploaded, type: Integer
  field :downloaded, type: Integer
  field :left, type: Integer
  field :seedbox, type: String
  field :last_updated, type: DateTime, default: ->{ Time.now }

  belongs_to :user

  def torrent
    Torrent.find(_id: self.torrent_id)
  end

  def ratio
    return uploaded/downloaded if downloaded > 0
    1000000
  end

end