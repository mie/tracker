require_relative 'peers_encryption'
require_relative 'peers_manager'

Tracker.helpers PeersEncryption

class Tracker < Sinatra::Base

  helpers do

    def failure(code, reason)
      TrackerLogger.debug "failure: #{reason}"
      status(code)
      body({'failure reason' => reason}.to_ben)
    end

    def json_status(code, reason)
      #status code
      {
        :status => code,
        :reason => reason
      }.to_json
    end

    def self.put_or_post(*a, &b)
      put *a, &b
      post *a, &b
    end

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