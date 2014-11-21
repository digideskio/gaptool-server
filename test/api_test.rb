require_relative 'test_helper'
require 'json'
require 'set'

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

  def add_and_register_server data=nil
    data ||= host_data
    post '/init', data.to_json
    expect(last_response.status).to eq(200)
    res = JSON.parse(last_response.body)
    id = res['instance']
    secret = res['secret']
    # there is no API to get the secret, get it from the database.
    secret = Gaptool::Data::get_server_data(id)['secret']
    put '/register', {'role' => data['role'],
                      'environment' => data['environment'],
                      'secret'=> secret,
                      'zone'=> data['zone']}.to_json
    expect(last_response.status).to eq(200)
    res
  end

  def host_data
    {
      'security_group' => 'mysg',
      'role' => 'testrole',
      'environment' => 'testenv',
      'ami' => 'ami-1234567',
      'chef_runlist' => ['recipe[myrecipe]'],
      'terminable' => true,
      'zone' => 'my-zone-1a',
      'itype' => 'm1.type',
      "hostname" => 'fake.hostname.gild.com'
    }
  end

  def expanded_runlist
    ['recipe[init]', 'recipe[myrecipe]']
  end

  it "should return 200" do
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('text/html')

    header 'Accept', 'application/json'
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('application/json')
  end

  it "should create a instance" do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body).keys).to eq(["instance", "ami", "role", "environment", "secret", "terminable", "security_group"])
  end

  it "should get the runlist from the role" do
    DH.save_role_data(host_data['role'], chef_runlist: ['recipe[other]'].to_json)
    id = add_and_register_server(host_data.reject{|k,v| k == 'chef_runlist'})['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to include("chef_runlist")
    expect(resp['chef_runlist']).to eq(['recipe[init]', 'recipe[other]'])
  end

  it "should remove default runlist" do
    id = add_and_register_server(host_data.merge("chef_runlist"=> ['recipe[init]']))['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include("chef_runlist")
  end

  it "should remove default runlist from role" do
    DH.save_role_data(host_data['role'], chef_runlist: ['recipe[init]'].to_json)
    id = add_and_register_server(host_data.reject{|k,v| k == 'chef_runlist'})['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include("chef_runlist")
    expect(resp['chef_runlist']).to be(nil)

  end

  it "should get the ami from the role" do
    DH.save_role_data(host_data['role'], 'amis' => {'my-zone-1' => 'ami-other'})
    res = add_and_register_server(host_data.reject{|k,v| k == 'ami'})
    expect(res['ami']).to eq('ami-other')
    get "/host/testrole/testenv/#{res['instance']}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to_not include("ami")
  end

  it "should get the ami from global conf" do
    DH.set_amis({'my-zone-1' => 'ami-default'})
    res = add_and_register_server(host_data.reject{|k,v| k == 'ami'})
    expect(res['ami']).to eq('ami-default')
    get "/host/testrole/testenv/#{res['instance']}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to_not include("ami")
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
    post '/init', host_data.merge('terminable' => false).to_json
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
    add_and_register_server
    expect(last_response.body).to include("-E #{host_data['environment']}")
  end

  it "should find an host" do
    id = add_and_register_server()['instance']
    get '/hosts'
    expect(last_response.status).to eq(200)
    exp_data = host_data.reject{|k,v| k == 'terminable'}.merge('chef_runlist' => expanded_runlist)
    exp_data['instance'] = id
    expect(JSON.parse(last_response.body)).to eq([exp_data])
  end

  it "should find two hosts" do
    id1 = add_and_register_server()['instance']
    id2 = add_and_register_server()['instance']
    get '/hosts'
    expect(last_response.status).to eq(200)
    exp_data = [
      host_data.reject{|k,v| k == 'terminable'}.merge({'instance' => id1,
                                                      'chef_runlist' => expanded_runlist}),
      host_data.reject{|k,v| k == 'terminable'}.merge({'instance' => id2,
                                                      'chef_runlist' => expanded_runlist})
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)
  end

  it "should find an host by role" do
    other = host_data.merge({'role' => 'otherrole'})
    id1 = add_and_register_server(other)['instance']
    id2 = add_and_register_server()['instance']

    get '/hosts/otherrole'
    expect(last_response.status).to eq(200)
    exp_data = [other.reject{|k,v| k == 'terminable'}.merge({'instance'=> id1,
                                                    'chef_runlist' => expanded_runlist})]
    expect(JSON.parse(last_response.body)).to eq(exp_data)
  end

  it "should find an host by id" do
    id = add_and_register_server()['instance']
    ["/instance/#{id}", "/host/testrole/testenv/#{id}", "/host/FAKE/FAKE/#{id}"].each do |url|
      get url
      expect(last_response.status).to eq(200)
      exp_data = host_data.reject{|k,v| k == 'terminable'}.merge({
        'instance'=> id,
        'chef_runlist' => expanded_runlist})
      expect(JSON.parse(last_response.body)).to eq(exp_data)
    end
  end

  it "should find all hosts by environment and role" do
    id1 = add_and_register_server()['instance']
    id2 = add_and_register_server()['instance']
    id3 = add_and_register_server(host_data.merge({'environment' => 'otherenv'}))['instance']
    id4 = add_and_register_server(host_data.merge({'role' => 'otherrole'}))['instance']
    get '/hosts/testrole/testenv'
    expect(last_response.status).to eq(200)
    d = host_data.reject{|k,v| k == 'terminable'}.merge('chef_runlist' => expanded_runlist)
    exp_data = [
      d.merge({'instance' => id1}),
      d.merge({'instance' => id2})
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)

    get '/hosts/ALL/testenv'
    expect(last_response.status).to eq(200)
    exp_data = [
      d.merge({'instance' => id1}),
      d.merge({'instance' => id2}),
      d.merge({'instance' => id4, 'role'=> 'otherrole'})
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)
  end

  it "should return the server version" do
    version = File.read(File.realpath(
      File.join(File.dirname(__FILE__), "..", 'VERSION')
    )).strip
    get "/version"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq({"server_version" => version, "api" => {"v0" => "/"}})
  end

  it "should return the list of apps" do
    DH.add_app("firstapp", "testrole")
    DH.add_app("secondapp", "testrole")
    apps_list = {"firstapp" => {"role" => "testrole"},
                 "secondapp" =>{"role" => "testrole"}}
    get "/apps"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq(apps_list)
  end
end
