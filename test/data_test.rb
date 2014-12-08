require_relative 'test_helper'
require 'json'

describe "data helpers" do

  before(:each) do
    $redis.flushall
    DH.set_config('chef_repo', 'myrepo')
    DH.set_config('chef_branch', 'master')
  end

  after(:all) do
    keys = $redis.redis.keys('*').select{|k| !k.start_with?('gt:')}
    expect(keys).to eq([])
  end

  def data
    {
      'role' => "role",
      'environment' => "env"
    }
  end

  def instid
    'i-1234567'
  end

  it "should add a server" do
    expect { DH.addserver("i-1234567", {}, "secret") }.to raise_error(ArgumentError)
    expect { DH.addserver('', data, "secret") }.to raise_error(ArgumentError)

    DH.addserver(instid, data, "secret")
    server = DH.get_server_data(instid)
    expect(server).to eq(data.merge({
      'instance' => instid,
      'chef_repo' => 'myrepo',
      'chef_branch' => 'master',
      'registered' => 'false',
      'secret' => 'secret'
    }))
  end

  it "should add a registered server" do
    DH.addserver(instid, data, nil)
    server = DH.get_server_data(instid)
    expect(server).to eq(data.merge({
      'instance' => instid,
      'chef_repo' => 'myrepo',
      'chef_branch' => 'master'
    }))
  end

  it "should register a server" do
    DH.addserver(instid, data, "secret")
    res = DH.register_server(data['role'], data['environment'], '')
    expect(res).to be(nil)

    res = DH.register_server(data['role'], data['environment'], 'secret')
    expect(res).to eq(instid)
    server = DH.get_server_data(instid)
    expect(server).to eq(data.merge({
      'instance' => instid,
      'chef_repo' => 'myrepo',
      'chef_branch' => 'master'
    }))
  end

  it "should remove a server" do
    DH.addserver(instid, data, 'secret')
    res = DH.register_server(data['role'], data['environment'], 'secret')
    res = DH.rmserver(instid)
    expect(res).to eq(instid)
    server = DH.get_server_data(instid)
    expect(server).to be(nil)

    res = DH.rmserver(instid)
    expect(res).to be(nil)
  end

  it "should set a config" do
    c = DH.get_config('fakekey')
    expect(c).to be(nil)

    DH.set_config('fakekey', 'value')
    c = DH.get_config('fakekey')
    expect(c).to eq('value')
  end

  it "should return the initkey" do
    DH.set_config('initkey', 'FAKEKEY')
    DH.addserver(instid, data, nil)
    server = DH.get_server_data(instid, initkey: true)
    expect(server).to eq(data.merge({
      'instance' => instid,
      'chef_repo' => 'myrepo',
      'chef_branch' => 'master',
      'initkey' => 'FAKEKEY'
    }))
  end

  it "should get the runlist for a node from the role" do
    DH.save_role_data("role", chef_runlist: ["recipe[myrecipe]"].to_json)
    DH.addserver(instid, data, nil)
    role = DH.get_role_data("role")
    expect(role).to eq({"chef_runlist"=> ["recipe[myrecipe]"].to_json,
                        "apps" => [],
                        "amis" => {}})
    server = DH.get_server_data(instid)
    expect(server).to eq(data.merge("instance" => instid,
                                    "chef_runlist" => ["recipe[myrecipe]"],
                                    "chef_repo" => "myrepo",
                                    "chef_branch" => "master" ))
  end

  it "shoud get the ami for a node from the role" do
    DH.save_role_data("role", ami: 'ami-1234567')
    DH.addserver(instid, data, nil)
    role = DH.get_role_data("role")
    expect(role).to eq({'ami' => 'ami-1234567',
                        "apps" => [],
                        "amis" => {}})
  end
end
