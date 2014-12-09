# encoding: utf-8
require 'sinatra'
require 'sinatra/json'
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
  helpers Sinatra::JSON

  def error_response msg=''
    message = "#{env['sinatra.error'].message}"
    message = "#{msg} #{message}" unless msg.empty?
    json result: 'error', message: message
  end

  error JSON::ParserError do
    status 400
    error_response "Invalid data."
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
    unless ENV['AIRBRAKE_API_KEY'].nil?
      Airbrake.configure do |cfg|
        cfg.api_key = ENV['AIRBRAKE_API_KEY']
      end
      use Airbrake::Sinatra
    end
    disable :sessions
    enable  :dump_errors
    disable :show_exceptions
  end

  before do
    if request.path_info != '/ping' && ENV['GAPTOOL_DISABLE_AUTH'].nil?
      user = Gaptool::Data.user(env['HTTP_X_GAPTOOL_USER'])
      raise Unauthenticated if user.nil?
      raise Unauthenticated unless user[:key] == env['HTTP_X_GAPTOOL_KEY']
    end
  end

  after do
    # Fix for old versions of gaptool-api
    if request.preferred_type.to_str == "application/json"
      content_type "application/json"
    else
      content_type 'text/html'
    end
  end
end

require_relative 'helpers/init'
require_relative 'routes'
