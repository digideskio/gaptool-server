# encoding: utf-8
require 'sinatra'
require 'json'
require 'yaml'
require 'erb'
require 'aws-sdk'
require 'openssl'
require 'net/ssh'
require 'peach'
require 'airbrake'

class GaptoolServer < Sinatra::Application

  error do
    {:result => 'error', :message => env['sinatra.error']}.to_json
  end

  configure do
    unless ENV['GAPTOOL_AIRBRAKE_KEY'].nil?
      Airbrake.configure do |cfg|
        cfg.api_key = ENV['GAPTOOL_AIRBRAKE_KEY']
      end
      use Airbrake::Sinatra
    end
    disable :sessions
    enable  :dump_errors
  end

  before do
    if request.path_info != '/ping' && !ENV['DRYRUN']
      error 401 unless $redis.hget('users', env['HTTP_X_GAPTOOL_USER']) == env['HTTP_X_GAPTOOL_KEY']
      error 401 unless env['HTTP_X_GAPTOOL_USER'] && env['HTTP_X_GAPTOOL_KEY']
    end
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end
end

require_relative 'helpers/init'
require_relative 'routes/init'
