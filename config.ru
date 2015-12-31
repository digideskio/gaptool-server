#!/usr/bin/env ruby

ENV['DRYRUN'] = nil unless ENV['DRYRUN'] == 'true'

libpath = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift(libpath)
require "#{libpath}/app.rb"

run Gaptool::Server
