require_relative 'test_helper'

describe "Data helper tests" do

  before(:each) do
    $redis.flushall
    DH.set_config('chefrepo', 'myrepo')
    DH.set_config('chefbranch', 'master')
  end

  def data
    {
      'role' => "role",
      'environment' => "env"
    }
  end

  it "should add a server" do
    expect { DH.addserver("i-1234567", {}, "secret") }.to raise_error(ArgumentError)
    expect { DH.addserver('', data, "secret") }.to raise_error(ArgumentError)
    expect { DH.addserver("i-1234567", data, nil) }.to raise_error(ArgumentError)

    DH.addserver('i-1234567', data, "secret")
    server = DH.get_server_data('i-1234567')
    expect(server).not_to be(nil)
    expect(server).to eq(data.merge({
      'instance' => 'i-1234567',
      'chef_repo' => 'myrepo',
      'chef_branch' => 'master',
      'registered' => 'false'
    }))
  end

  it "should register a server" do
    DH.addserver('i-1234567', data, "secret")
    res = DH.register_server(data['role'], data['environment'], '')
    expect(res).to be(nil)

    res = DH.register_server(data['role'], data['environment'], 'secret')
    expect(res).to eq('i-1234567')
    server = DH.get_server_data('i-1234567')
    expect(server['registered']).to be(nil)
  end
end
