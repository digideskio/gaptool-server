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
require 'logger'
require_relative 'exceptions'

class GaptoolServer < Sinatra::Application
  helpers Sinatra::JSON
  use Airbrake::Sinatra

  def error_response msg=''
    message = env['sinatra_error'].nil? ? "" : " #{env['sinatra.error'].message}"
    message = "#{msg}#{message}" unless msg.empty?
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

  def unauthenticated
    halt(401, error_response("Unauthenticated"))
  end

  error do
    status 500
    error_response
  end

  configure do
    unless ENV['AIRBRAKE_API_KEY'].nil?
      Airbrake.configure do |cfg|
        cfg.api_key = ENV['AIRBRAKE_API_KEY']
        cfg.logger = Logger.new(STDOUT)
      end
    end
    disable :sessions
    enable  :dump_errors
    disable :show_exceptions
  end

  before do
    if request.path_info != '/ping' && ENV['GAPTOOL_DISABLE_AUTH'].nil?
      user = Gaptool::Data.user(env['HTTP_X_GAPTOOL_USER'])
      return unauthenticated if user.nil?
      return unauthenticated unless user[:key] == env['HTTP_X_GAPTOOL_KEY']
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
