require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  GaptoolServer
end

describe "ping should work unauthenticated" do
  it "should return PONG" do
    get '/ping'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq("PONG")
  end
end

describe "unauthenticated" do
  it "should return 401 error" do
    get '/'
    expect(last_response.status).to eq(401)
  end
end

describe "authenticated" do
  it "should return 200" do
    auth do |h|
      get '/', nil, h
      expect(last_response.status).to eq(200)
    end
  end
end
