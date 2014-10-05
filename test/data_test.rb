require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

describe "Data helper tests" do

  before(:each) do
    $redis.flushall
    DH.set_config('chefrepo', 'myrepo')
    DH.set_config('chefbranch', 'master')
  end

  it "should add a server" do
    data = {
      'role' => "role",
      'environment' => "env"
    }
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

end