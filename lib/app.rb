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
require_relative 'exceptions'

class GaptoolServer < Sinatra::Application

  def error_response
    {result: 'error', message: env['sinatra.error'].message}.to_json
  end

  error HTTPError do
    status env['sinatra.error'].code
    error_response
  end

  error do
    status 500
    error_response
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
    disable :show_exceptions
  end

  before do
    if request.path_info != '/ping' && ENV['GAPTOOL_DISABLE_AUTH'].nil?
      error 401 unless $redis.hget('users', env['HTTP_X_GAPTOOL_USER']) == env['HTTP_X_GAPTOOL_KEY']
      error 401 unless env['HTTP_X_GAPTOOL_USER'] && env['HTTP_X_GAPTOOL_KEY']
    end
    content_type 'application/json'
  end
end

require_relative 'helpers/init'
require_relative 'routes'
