require_relative 'test_helper'

describe "Test API" do
  before(:each) do
    header 'X_GAPTOOL_USER', 'test'
    header 'X_GAPTOOL_KEY',  'test'
    $redis.flushall
    DH.useradd('test', 'test')
  end

  it "should return 200" do
    get '/', {}, {}
    expect(last_response.status).to eq(200)
  end


end