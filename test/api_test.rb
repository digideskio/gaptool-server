require_relative 'test_helper'
require 'json'
require 'set'

redis = Gaptool.redis

describe 'Test API' do
  before(:all) do
    ENV['DRYRUN'] = 'true'
    ENV['GAPTOOL_CHECK_CLIENT_VERSION'] = nil
  end

  after(:all) do
    ENV['DRYRUN'] = nil
    ENV['GAPTOOL_CHECK_CLIENT_VERSION'] = nil
  end

  before(:each) do
    header 'X-GAPTOOL-USER', 'test'
    header 'X-GAPTOOL-KEY',  'test'
    header 'X-GAPTOOL-VERSION', version
    redis.flushall
    DH.useradd('test', 'test')
    $time = Time.now
  end

  def add_and_register_server(data = nil)
    data ||= host_data
    post '/init', data.to_json
    expect(last_response.status).to eq(200)
    res = JSON.parse(last_response.body)
    id = res['instance']
    # there is no API to get the secret, get it from the database.
    secret = Gaptool::Data.get_server_data(id)['secret']
    put '/register', { 'role' => data['role'],
                       'environment' => data['environment'],
                       'secret' => secret,
                       'zone' => data['zone'] }.to_json
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
      'hostname' => 'fake.hostname.gild.com',
      'launch_time' => $time.to_i
    }
  end

  def expanded_runlist
    ['role[base]', 'recipe[myrecipe]']
  end

  def version
    @v ||= File.read(
      File.realpath(File.join(File.dirname(__FILE__), '..', 'VERSION')
                   )).strip
  end

  it 'should return 200' do
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('text/html')

    header 'Accept', 'application/json'
    get '/'
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include('application/json')
  end

  it 'should create a instance' do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body).keys).to eq(%w(instance ami role hostname launch_time
                                                         environment secret terminable security_group))
  end

  it 'should get the runlist from the role' do
    DH.save_role_data(host_data['role'], chef_runlist: ['recipe[other]'].to_json)
    id = add_and_register_server(host_data.reject { |k, _v| k == 'chef_runlist' })['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to include('chef_runlist')
    expect(resp['chef_runlist']).to eq(['recipe[other]'])
  end

  it 'should get the security group from the role' do
    DH.save_role_data(host_data['role'], 'sg' => { host_data['environment'] => 'mysg-in-role' })
    id = add_and_register_server(host_data.reject { |k, _v| k == 'security_group' })['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to include('security_group')
    expect(resp['security_group']).to eq('mysg-in-role')
  end

  it 'should get the default security group' do
    id = add_and_register_server(host_data.reject { |k, _v| k == 'security_group' })['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to include('security_group')
    expect(resp['security_group']).to eq("#{host_data['role']}-#{host_data['environment']}")
  end

  it 'should set instance unterminable' do
    id = add_and_register_server['instance']

    get "/instance/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('terminable')

    patch "/instance/#{id}", { terminable: false }.to_json
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['terminable']).to eq(false)

    get "/instance/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['terminable']).to eq(false)

    post '/terminate', { 'id' => id }.to_json
    expect(last_response.status).to eq(409)

    patch "/instance/#{id}", { terminable: true }.to_json
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['terminable']).to eq(true)

    post '/terminate', { 'id' => id }.to_json
    expect(last_response.status).to eq(200)
  end

  it 'should set an instance as hidden' do
    id = add_and_register_server['instance']

    get "/instance/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('hidden')

    patch "/instance/#{id}", { hidden: false }.to_json
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('hidden')

    get "/instance/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('hidden')

    patch "/instance/#{id}", { hidden: true }.to_json
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['hidden']).to eq(true)

    get "/instance/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['hidden']).to eq(true)

    get "/host/#{host_data['role']}/#{host_data['environment']}/#{id}"
    expect(last_response.status).to eq(200)
    resp = JSON.parse(last_response.body)
    expect(resp['hidden']).to eq(true)

    get '/hosts'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])

    get "/hosts/#{host_data['role']}"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])

    get "/hosts/#{host_data['role']}/#{host_data['environment']}"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])

    get "/hosts/ALL/#{host_data['environment']}"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])
  end

  it 'should remove default runlist' do
    id = add_and_register_server(host_data.merge('chef_runlist' => ['role[base]']))['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('chef_runlist')
  end

  it 'should remove default runlist from role' do
    DH.save_role_data(host_data['role'], chef_runlist: ['role[base]'].to_json)
    id = add_and_register_server(host_data.reject { |k, _v| k == 'chef_runlist' })['instance']
    get "/host/testrole/testenv/#{id}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).not_to include('chef_runlist')
    expect(resp['chef_runlist']).to be(nil)
  end

  it 'should get the ami from the role' do
    DH.save_role_data(host_data['role'], 'amis' => { 'my-zone-1' => 'ami-other' })
    res = add_and_register_server(host_data.reject { |k, _v| k == 'ami' })
    expect(res['ami']).to eq('ami-other')
    get "/host/testrole/testenv/#{res['instance']}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to_not include('ami')
  end

  it 'should get the ami from global conf' do
    DH.amis('my-zone-1' => 'ami-default')
    res = add_and_register_server(host_data.reject { |k, _v| k == 'ami' })
    expect(res['ami']).to eq('ami-default')
    get "/host/testrole/testenv/#{res['instance']}"
    resp = JSON.parse(last_response.body)
    expect(resp.keys).to_not include('ami')
  end

  it 'should fail to parse client data' do
    post '/init', host_data
    expect(last_response.status).to eq(400)
  end

  it 'should fail to create a instance' do
    %w(role environment zone itype).each do |req|
      post '/init', host_data.reject { |k, _v| k == req }.to_json
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body).keys).to eq(%w(result message))
    end
  end

  it 'should fail for missing parameter to terminate' do
    post '/terminate'
    expect(last_response.status).to eq(400)
  end

  it 'should fail to terminate non-existing instance' do
    post '/terminate', { 'id' => 'i-1234567' }.to_json
    expect(last_response.status).to eq(404)
  end

  it 'should fail to terminate non-terminable instance' do
    post '/init', host_data.merge('terminable' => false).to_json
    expect(last_response.status).to eq(200)
    id = JSON.parse(last_response.body)['instance']
    post '/terminate', { 'id' => id }.to_json
    expect(last_response.status).to eq(409)
  end

  it 'should terminate instance' do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)
    id = JSON.parse(last_response.body)['instance']
    post '/terminate', { 'id' => id }.to_json
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq(id => { 'status' => 'terminated' })
  end

  it 'should fail to register a server' do
    required_keys = %w(role zone environment secret)
    hdata = host_data.select { |k, _v| required_keys.include?(k) }
    hdata['secret'] = 'mysecret'
    required_keys.each do |key|
      put '/register', hdata.select { |k, _v| k != key }.to_json
      expect(last_response.status).to eq(400)
    end
    put '/register', hdata.to_json
    expect(last_response.status).to eq(403)
  end

  it 'should register the server' do
    add_and_register_server
    expect(last_response.body).to include("-E #{host_data['environment']}")
  end

  it 'should init with the default runlist' do
    hdata = host_data.select{ |k, _v| k != 'chef_runlist' }
    add_and_register_server(hdata)
    expect(last_response.body).to include('"run_list":["role[base]"],')
  end

  it 'should init with the host runlist' do
    add_and_register_server
    expect(last_response.body).to include('"run_list":["role[base]","recipe[myrecipe]"],')
  end

  it 'should not find any hosts' do
    post '/init', host_data.to_json
    expect(last_response.status).to eq(200)

    get '/hosts'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])

    get "/hosts/#{host_data['role']}"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq([])
  end

  it 'should find an host' do
    id = add_and_register_server['instance']
    get '/hosts'
    expect(last_response.status).to eq(200)
    exp_data = host_data.reject { |k, _v| k == 'terminable' }.merge('chef_runlist' => expanded_runlist,
                                                                    'apps' => [])
    exp_data['instance'] = id
    expect(JSON.parse(last_response.body)).to eq([exp_data])
  end

  it 'should find two hosts' do
    id1 = add_and_register_server['instance']
    id2 = add_and_register_server['instance']
    get '/hosts'
    expect(last_response.status).to eq(200)
    exp_data = [
      host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id1,
                                                           'chef_runlist' => expanded_runlist,
                                                           'apps' => []),
      host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id2,
                                                           'chef_runlist' => expanded_runlist,
                                                           'apps' => [])
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)
  end

  it 'should find one hidden host' do
    id1 = add_and_register_server['instance']
    id2 = add_and_register_server['instance']
    patch "/instance/#{id1}", { hidden: true }.to_json
    %W(/hosts /hosts/#{host_data['role']} /hosts/#{host_data['role']}/#{host_data['environment']} /hosts/ALL/#{host_data['environment']}).each do |url|
      get url
      expect(last_response.status).to eq(200)
      res = JSON.parse(last_response.body).map { |x| x.delete('apps'); x }.to_set
      exp_data = [host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id2,
                                                                       'chef_runlist' => expanded_runlist)].to_set
      expect(res).to eq(exp_data)
      get url, hidden: true
      expect(last_response.status).to eq(200)
      exp_data = [
        host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id1,
                                                             'chef_runlist' => expanded_runlist,
                                                             'hidden' => true),
        host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id2,
                                                             'chef_runlist' => expanded_runlist)
      ].to_set
      expect(JSON.parse(last_response.body).map { |x| x.delete('apps'); x }.to_set).to eq(exp_data)
    end
  end

  it 'should find an host by role' do
    other = host_data.merge('role' => 'otherrole')
    id1 = add_and_register_server(other)['instance']
    add_and_register_server['instance']

    get '/hosts/otherrole'
    expect(last_response.status).to eq(200)
    exp_data = [other.reject { |k, _v| k == 'terminable' }.merge('instance' => id1,
                                                                 'chef_runlist' => expanded_runlist,
                                                                 'apps' => [])]
    expect(JSON.parse(last_response.body)).to eq(exp_data)
  end

  it 'should find an host by id' do
    id = add_and_register_server['instance']
    ["/instance/#{id}", "/host/testrole/testenv/#{id}", "/host/FAKE/FAKE/#{id}"].each do |url|
      get url
      expect(last_response.status).to eq(200)
      exp_data = host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id,
                                                                      'chef_runlist' => expanded_runlist,
                                                                      'apps' => [])
      expect(JSON.parse(last_response.body)).to eq(exp_data)
    end
  end

  it 'should return the host attr json' do
    DH.set_config('chef_repo', 'FAKECHEFREPO')
    DH.set_config('chef_branch', 'chefbranch')
    DH.set_config('url', 'localhost:666')
    id = add_and_register_server['instance']
    get "/instance/#{id}/attrs"
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq(
      'apps' => [],
      'branch' => 'master',
      'chefbranch' => 'chefbranch',
      'chefrepo' => 'FAKECHEFREPO',
      'deploy_apps' => [],
      'environment' => host_data['environment'],
      'gaptool' => {
        'user' => 'test',
        'key' => 'test',
        'url' => 'localhost:666'
      },
      'migrate' => false,
      'role' => host_data['role'],
      'rollback' => false,
      'run_list' => expanded_runlist
    )
  end

  it 'old clients should receive apps as strings' do
    header 'X-GAPTOOL-VERSION', '0.7.0'
    id = add_and_register_server['instance']
    ["/instance/#{id}", "/host/testrole/testenv/#{id}", "/host/FAKE/FAKE/#{id}"].each do |url|
      get url
      expect(last_response.status).to eq(200)
      exp_data = host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id,
                                                                      'chef_runlist' => expanded_runlist,
                                                                      'apps' => '[]')
      expect(JSON.parse(last_response.body)).to eq(exp_data)
    end
  end

  it 'clients with no version should be handled as old' do
    header 'X-GAPTOOL-VERSION', nil
    id = add_and_register_server['instance']
    ["/instance/#{id}", "/host/testrole/testenv/#{id}", "/host/FAKE/FAKE/#{id}"].each do |url|
      get url
      expect(last_response.status).to eq(200)
      exp_data = host_data.reject { |k, _v| k == 'terminable' }.merge('instance' => id,
                                                                      'chef_runlist' => expanded_runlist,
                                                                      'apps' => '[]')
      expect(JSON.parse(last_response.body)).to eq(exp_data)
    end
  end

  it 'should not find an host by id' do
    add_and_register_server['instance']
    get '/instance/other'
    expect(last_response.status).to eq(404)
    expect(JSON.parse(last_response.body)).to eq(
      'result' => 'error',
      'message' => "instance with id 'other' not found"
    )
  end

  it 'should find all hosts by environment and role' do
    id1 = add_and_register_server['instance']
    id2 = add_and_register_server['instance']
    add_and_register_server(host_data.merge('environment' => 'otherenv'))['instance']
    id4 = add_and_register_server(host_data.merge('role' => 'otherrole'))['instance']
    get '/hosts/testrole/testenv'
    expect(last_response.status).to eq(200)
    d = host_data.reject { |k, _v| k == 'terminable' }.merge('chef_runlist' => expanded_runlist, 'apps' => [])
    exp_data = [
      d.merge('instance' => id1),
      d.merge('instance' => id2)
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)

    get '/hosts/ALL/testenv'
    expect(last_response.status).to eq(200)
    exp_data = [
      d.merge('instance' => id1),
      d.merge('instance' => id2),
      d.merge('instance' => id4, 'role' => 'otherrole')
    ].to_set
    expect(JSON.parse(last_response.body).to_set).to eq(exp_data)
  end

  it 'should return the server version' do
    get '/version'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq('server_version' => version, 'api' => { 'v0' => '/' })
  end

  it 'should return the list of apps' do
    DH.add_app('firstapp', 'testrole', 'testenv')
    DH.add_app('secondapp', 'testrole', 'testenv')
    apps_list = { 'app:firstapp' => { 'testenv' => 'testrole' },
                  'app:secondapp' => { 'testenv' => 'testrole' } }
    get '/apps'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq(apps_list)
  end

  it 'should fail as client did not send version' do
    ENV['GAPTOOL_CHECK_CLIENT_VERSION'] = '1'
    header 'X-GAPTOOL-VERSION', nil
    get '/version'
    expect(last_response.status).to eq(400)
    resp = JSON.parse(last_response.body)
    expect(resp['result']).to eq('error')
    expect(resp['message']).to match(/^Invalid version/)
  end

  it 'should not check version for clients' do
    ENV['GAPTOOL_CHECK_CLIENT_VERSION'] = nil
    header 'X_GAPTOOL_VERSION', nil
    get '/version'
    expect(last_response.status).to eq(200)
  end

  it 'should reject old clients versions' do
    ENV['GAPTOOL_CHECK_CLIENT_VERSION'] = '1'
    srv = Versionomy.parse(version)
    cl = Versionomy.create(major: srv.major, minor: srv.minor - 1, tiny: 0)
    header 'X_GAPTOOL_VERSION', cl.to_s
    get '/version'
    expect(last_response.status).to eq(400)
    resp = JSON.parse(last_response.body)
    expect(resp['result']).to eq('error')
    expect(resp['message']).to match(/^Invalid version/)
  end
end
