require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  GaptoolServer
end

describe "ping" do
  it "should return PONG" do
    get '/ping'
    last_response.body.must_include "PONG"
  end
end

describe "unathenticated" do
  it "should return 401 error" do
    get '/'
    assert_equal last_response.unauthorized?, true
  end
end
