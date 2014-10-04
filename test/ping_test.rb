require File.expand_path '../test_helper.rb', __FILE__

class GaptoolBaseTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    GaptoolServer
  end

  def test_it_says_pong
    get '/ping'
    assert last_response.ok?
    assert_equal 'PONG', last_response.body
  end
end
