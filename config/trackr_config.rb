class Tracker < Sinatra::Base

  configure :development do
    set :environment, :development
    enable :sessions, :logging, :static, :inline_templates, :method_override, :dump_errors, :run
    Mongoid.load!(File.expand_path(File.join("config", "mongoid.yml")))
    Mongoid.logger.level = Logger::DEBUG
    Mongoid.raise_not_found_error = false
  end

  configure :test do
    set :environment, :test
    enable :sessions, :static, :inline_templates, :method_override, :raise_errors
    disable :run, :dump_errors, :logging
    Mongoid.load!(File.expand_path(File.join("config", "mongoid.yml")))
    Mongoid.raise_not_found_error = false
  end

  configure :production do
    set :environment, :production
    enable :sessions, :logging, :static, :inline_templates, :method_override, :dump_errors, :run
    Mongoid.load!(File.expand_path(File.join("config", "mongoid.yml")))
    Mongoid.raise_not_found_error = false
  end

end