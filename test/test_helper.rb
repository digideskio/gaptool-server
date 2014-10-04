ENV['RACK_ENV'] = 'test'

libpath = File.realpath(File.join(File.dirname(__FILE__), "..", "lib"))
require 'minitest/autorun'
require 'rack/test'
require "#{libpath}/app.rb"

