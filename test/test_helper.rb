ENV['RACK_ENV'] = 'test'

libpath = File.realpath(File.join(File.dirname(__FILE__), "..", "lib"))
require 'rspec'
require 'rack/test'
require 'fakeredis/rspec'
require "#{libpath}/app.rb"
require "#{libpath}/helpers/data"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  def app
    GaptoolServer
  end
end

class DataHelperIncluder
  include DataHelper
end
DH = DataHelperIncluder.new

$redis = Redis.new
