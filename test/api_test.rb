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
      'chef_runlist' => ['recipe[myrecipe]'],
      'terminate' => true,
      'zone' => 'my-zone-1a',
      'itype' => 'm1.type'
    }
  end

  it "should return 200" do
    get '/'
    expect(last_response.status).to eq(200)
  end

  it "should create a instance" do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to eq('application/json')
    expect(JSON.parse(last_response.body).keys).to eq(['instance'])
  end

  it "should fail to parse client data" do
    post '/init', host_data
    expect(last_response.status).to eq(400)
  end

  it "should fail to create a instance" do
    %w(role environment zone itype).each do |req|
      post '/init', host_data.reject{|k, v| k == req}.to_json
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body).keys).to eq(%w(result message))
    end
  end

  it "should fail for missing parameter to terminate" do
    post '/terminate'
    expect(last_response.status).to eq(400)
  end

  it "should fail to terminate non-existing instance" do
    post '/terminate', {'id' => 'i-1234567'}.to_json
    expect(last_response.status).to eq(404)
  end

  it "should fail to terminate non-terminable instance" do
    post '/init', host_data.merge('terminate' => false).to_json
    expect(last_response.status).to eq(200)
    id = JSON.parse(last_response.body)['instance']
    post '/terminate', {'id' => id}.to_json
    expect(last_response.status).to eq(409)
  end

  it "should terminate instance" do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    id = JSON.parse(last_response.body)['instance']
    post '/terminate', {'id' => id}.to_json
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq({id => {'status'=> 'terminated'}})
  end

  it "should fail to register a server" do
    required_keys = %w(role zone environment secret)
    hdata = host_data.select {|k, v| required_keys.include?(k)}
    hdata['secret'] = 'mysecret'
    required_keys.each do |key|
      put '/register', hdata.select {|k,v| k != key}.to_json
      expect(last_response.status).to eq(400)
    end
    put '/register', hdata.to_json
    expect(last_response.status).to eq(403)
  end

  it "should register the server" do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    id = JSON.parse(last_response.body)['instance']
    # there is no API to get the secret, get it from the database.
    secret = Gaptool::Data::get_server_data(id)['secret']
    put '/register', {'role' => host_data['role'],
                      'environment' => host_data['environment'],
                      'secret'=> secret,
                      'zone'=> host_data['zone']}.to_json
    expect(last_response.status).to eq(200)
  end

end
