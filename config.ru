require File.join(File.dirname(__FILE__), 'application')

set :environment, :development
set :port, 9393

run Tracker.new