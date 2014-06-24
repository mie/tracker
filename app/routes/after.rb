# encoding: utf-8
class Tracker < Sinatra::Base

  get "*" do
    #status 404
    json_status 404, 'Not found'
  end

  post "*" do
    #status 404
    json_status 404, 'Not found'
  end

  delete "*" do
    #status 404
    json_status 404, 'Not found'
  end

  not_found do
    #status 404
    json_status 404, "Not found"
  end

  error do
    json_status 500, env['sinatra.error'].message
  end

end