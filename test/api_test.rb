require_relative 'test_helper'
require 'json'

describe "Test API" do
  before(:all) do
    ENV['DRYRUN'] = 'true'
  end

  after(:all) do
    ENV['DRYRUN'] = nil
  end

  before(:each) do
    header 'X_GAPTOOL_USER', 'test'
    header 'X_GAPTOOL_KEY',  'test'
    $redis.flushall
    DH.useradd('test', 'test')
  end

  def host_data
    {
      'security_group' => 'mysg',
      'role' => 'testrole',
      'environment' => 'testenv',
      'ami' => 'ami-1234567',
      'chef_runlist' => 'recipe[myrecipe]',
      'terminate' => false,
      'zone' => 'my-zone-1a',
      'itype' => 'm1.type'
    }
  end

  it "should return 200" do
    get '/'
    expect(last_response.status).to eq(200)
  end

  it "should create a server" do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body).keys).to eq(['instance'])
  end

end
