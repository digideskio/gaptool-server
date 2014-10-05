require_relative 'test_helper'

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
