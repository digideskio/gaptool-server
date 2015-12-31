ENV['RACK_ENV'] = 'test'
if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-rcov'

  module SimpleCov
    module Formatter
      class MergedFormatter
        def format(result)
          SimpleCov::Formatter::HTMLFormatter.new.format(result)
          SimpleCov::Formatter::RcovFormatter.new.format(result)
        end
      end
    end
  end

  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
  SimpleCov.start do
    add_filter '/test/'
    add_group 'helpers', 'lib/helpers'
  end
end
# Clear airbrake env if set
ENV['AIRBRAKE_API_KEY'] = nil
libpath = File.realpath(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rspec'
require 'rack/test'
require 'fakeredis/rspec'
require 'redis-namespace'
require "#{libpath}/app.rb"

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  def app
    Gaptool::Server
  end
end

DH = Gaptool::Data
