#!/usr/bin/env ruby

ENV['DRYRUN'] = nil unless ENV['DRYRUN'] == 'true'

libpath = File.expand_path(File.join(File.dirname(__FILE__), "lib"))
$:.unshift(libpath)
require "#{libpath}/helpers/redis"
require "#{libpath}/app.rb"

run GaptoolServer
