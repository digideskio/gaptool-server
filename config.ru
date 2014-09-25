#!/usr/bin/env ruby

require 'redis'

# docker links support
unless ENV['REDIS_PORT_6379_TCP_ADDR'].nil?
  ENV['REDIS_HOST'] = ENV['REDIS_PORT_6379_TCP_ADDR']
  ENV['REDIS_PORT'] = ENV['REDIS_PORT_6379_TCP_PORT']
  ENV.delete('REDIS_PASS')
end

# fig support
unless ENV['REDIS_1_PORT_6379_TCP_ADDR'].nil?
  ENV['REDIS_HOST'] = ENV['REDIS_1_PORT_6379_TCP_ADDR']
  ENV['REDIS_PORT'] = ENV['REDIS_1_PORT_6379_TCP_PORT']
  ENV.delete('REDIS_PASS')
end

ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']

ENV['DRYRUN'] = nil unless ENV['DRYRUN'] == 'true'

$redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'], :password => ENV['REDIS_PASS'])

libpath = File.expand_path(File.join(File.dirname(__FILE__), "lib"))
$:.unshift(libpath)
require "#{libpath}/app.rb"

instance = GaptoolServer.new
run instance
