ENV['RACK_ENV'] = 'test'
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_group 'helpers', 'lib/helpers'
  end
end

libpath = File.realpath(File.join(File.dirname(__FILE__), "..", "lib"))
require 'rspec'
require 'rack/test'
require 'fakeredis/rspec'
require "#{libpath}/app.rb"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  def app
    GaptoolServer
  end
end

DH = Gaptool::Data

$redis = Redis.new
