#!/usr/bin/env ruby

require 'redis'

ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']
ENV['REDIS_DB'] = '0' unless ENV['REDIS_DB']
$redis = Redis.new(:host => ENV['REDIS_HOST'],
                   :port => ENV['REDIS_PORT'],
                   :password => ENV['REDIS_PASS'],
                   :db => ENV['REDIS_DB'])

libpath = File.expand_path(File.join(File.dirname(__FILE__), "lib"))
$:.unshift(libpath)
require "#{libpath}/app.rb"

instance = GaptoolServer.new
run instance
