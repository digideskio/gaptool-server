ENV['RACK_ENV'] = 'test'

libpath = File.realpath(File.join(File.dirname(__FILE__), "..", "lib"))
#require 'minitest/autorun'
require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'fakeredis/rspec'
require "#{libpath}/app.rb"
require "#{libpath}/helpers/data"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

$redis = Redis.new

def auth
  DH.useradd('test', 'test')
  headers = {
    'HTTP_X_GAPTOOL_USER' => 'test',
    'HTTP_X_GAPTOOL_KEY' => 'test'
  }
  yield headers
end

