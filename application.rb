require 'sinatra'
require 'sinatra/contrib'
require 'mongoid'
require "mongoid-grid_fs"
require 'redis'
require 'logger'

class Tracker < Sinatra::Base
  
  if defined? Encoding
    Encoding.default_external = Encoding::UTF_8
    Encoding.default_internal = Encoding::UTF_8
  end

  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :default_encoding, 'utf-8'
  set :static, true
  set :ts, YAML::load(File.open(File.join(settings.root, 'config', 'config.yml')))

  require File.join(settings.root, 'app', 'helpers', 'helpers.rb')
  require File.join(settings.root, 'app', 'routes', 'init.rb')
  require File.join(settings.root, 'config', 'trackr_config.rb')
  require File.join(settings.root,  'lib', 'bencode.rb')
  
  RS = Redis.new
  RS.flushdb
  Torrent.all.each{ |t|
    RedisMan.add_torrent(t.infohash)
  }
  RS.client.logger = Logger.new(STDOUT)
  TrackerLogger = Logger.new(STDOUT)

  FS = Mongoid::GridFs

  require File.join(settings.root, 'app', 'models', 'init.rb')

  # set :scheduler, { Rufus::Scheduler.start_new }

  # settings.scheduler.every('30m') do
  #   Peer.find_by(:last_updated.lt => Time.now - 30*60).each {|peer| }
  # end

end

