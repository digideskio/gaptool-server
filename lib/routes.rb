# encoding: utf-8
require 'securerandom'
require 'set'
require_relative 'exceptions'

module Gaptool
  class Server < Sinatra::Application
    def require_parameters(required_keys, data)
      data = data.delete_if { |_, v| v.nil? }
      required_keys = [*required_keys].to_set unless required_keys.is_a? Set
      keys = data.keys.to_set
      fail(BadRequest, "Missing required_parameters: #{(required_keys - keys).to_a.join(' ')}") \
        unless keys >= required_keys
      data
    end

    get '/' do
      'You must be lost. Read the instructions.'
    end

    get '/ping' do
      'PONG'
    end

    post '/init' do
      data = require_parameters(%w(role environment zone itype),
                                JSON.parse(request.body.read))

      secret = SecureRandom.hex(12)
      data['security_group'] = data['security_group'] || Gaptool::Data.get_sg_for_role(data['role'], data['environment'])
      sgid = Gaptool::EC2.get_or_create_securitygroup(data['role'], data['environment'], data['zone'], data['security_group'])
      image_id = data['ami'] || Gaptool::Data.get_ami_for_role(data['role'], data['zone'].chop)
      data['terminable'] = data['terminable'].nil? ? true : !!data['terminable']
      data['secret'] = secret

      instance = Gaptool::EC2.create_ec2_instance(
        {
          image_id: image_id,
          availability_zone: data['zone'],
          instance_type: data['itype'],
          key_name: 'gaptool',
          security_group_ids: sgid,
          user_data: "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{Gaptool::Data.get_config('url')}/register -X PUT --data '#{data.to_json}' | bash"
        },
        role: data['role'],
        env: data['environment'],
        zone: data['zone']
      )

      # Tag instance
      role = data['role']
      env = data['environment']
      name = "#{role}-#{env}-#{instance[:id]}"
      { 'Name' => name, 'gaptool' => 'yes', 'role' => role, 'environment' => env }.each do |tag, value|
        begin
          Gaptool::EC2.tag_ec2_instance(instance[:instance], tag, value)
        rescue => e
          logger.error("Error while tagging: #{e}. Skipping tag")
          Airbrake.notify_or_ignore(
            e,
            error_class: 'EC2 Tag failed',
            parameters: { instance: instance[:id], name: name, role: role, environment: env }
          )
        end
      end

      # Add host tag
      data.merge!(Hash[instance.reject { |k, _| [:id, :instance].include?(k) }.map { |k, v| [k.to_s, v] }])
      Gaptool::Data.addserver(instance[:id], data, secret)
      json(
        instance: instance[:id],
        ami: image_id,
        role: data['role'],
        hostname: instance[:hostname],
        launch_time: instance[:launch_time],
        environment: data['environment'],
        secret: secret,
        terminable: data['terminable'],
        security_group: sgid
      )
    end

    post '/terminate' do
      data = require_parameters('id',
                                JSON.parse(request.body.read))
      host_data = Gaptool::Data.get_server_data data['id']
      fail NotFound, "No such instance: #{data['id']}" if host_data.nil?
      fail Conflict, "Instance #{data['id']} cannot be terminated" if host_data['terminable'] == false

      Gaptool::EC2.terminate_ec2_instance(data['zone'], data['id'])
      Gaptool::Data.rmserver(data['id'])
      json data['id'] => { 'status' => 'terminated' }
    end

    put '/register' do
      data = JSON.parse request.body.read
      data = require_parameters(%w(role zone environment secret), data)
      instance_id = Gaptool::Data.register_server data['role'], data['environment'], data['secret']

      fail Forbidden, "Can't register instance: wrong secret or missing role/environment" unless instance_id

      hostname = Gaptool::EC2.get_ec2_instance_data(data['zone'].chop, instance_id)[:hostname]
      Gaptool::Data.set_server_data_attr(instance_id, 'hostname', hostname)
      host_data = Gaptool::Data.get_server_data instance_id, initkey: true, force_runlist: true

      chef_repo = host_data['chef_repo']
      chef_branch = host_data['chef_branch']
      chef_environment = host_data['environment']
      # FIXME: remove init key from redis
      initkey = Gaptool::Data.get_config('initkey')
      run_list = host_data['chef_runlist']

      jdata = {
        'run_list' => run_list,
        'role' => data['role'],
        'environment' => data['environment'],
        'chefrepo' => chef_repo,
        'chefbranch' => chef_branch,
        'identity' => initkey,
        'appuser' => Gaptool::Data.get_config('appuser'),
        'apps' => host_data['apps'],
        'gaptool' => {
          'user' => env['HTTP_X_GAPTOOL_USER'],
          'key' => env['HTTP_X_GAPTOOL_KEY'],
          'url' => Gaptool::Data.get_config('url')
        }
      }.to_json

      erb :init, locals: {
        initkey: initkey,
        chef_branch: chef_branch,
        chef_repo: chef_repo,
        chef_environment: chef_environment,
        chef_version: Gaptool::Data.ensure_config('chef_version', '11.16.4'),
        json: jdata
      }
    end

    get '/hosts' do
      filter = if params['hidden']
                 proc { |s| !s['registered'] }
               else
                 proc { |s| !s['registered'] && !s['hidden'] == true }
               end
      json(Gaptool::Data.servers.map do |inst|
        Gaptool::Data.get_server_data inst
      end.select(&filter))
    end

    get '/apps' do
      json(Hash[Gaptool::Data.apps.map { |a| ["app:#{a}", Gaptool::Data.get_app_data(a)] }])
    end

    get '/app/:app/:environment/hosts' do
      app_data = Gaptool::Data.get_app_data(params[:app])
      unless app_data
        status 404
        error_response "app '#{params[:apps]}' not found"
      end

      role = app_data[params[:environment]]
      list = Gaptool::Data.servers_in_role_env role, params[:environment]
      filter = if params['hidden']
                 proc { |_| false }
               else
                 proc { |s| s['hidden'] }
               end
      json(list.map do |inst|
        data = Gaptool::Data.get_server_data(inst)
        Gaptool::Data.stringify_apps(data, client_version)
      end.delete_if(&filter))
    end

    get '/hosts/:role' do
      filter = if params['hidden']
                 proc { |s| !s['registered'] }
               else
                 proc { |s| !s['registered'] && !s['hidden'] == true }
               end
      servers = Gaptool::Data.servers_in_role(params[:role]).map do |inst|
        Gaptool::Data.get_server_data(inst)
      end.select(&filter)
      json servers
    end

    get '/instance/:id' do
      rs = Gaptool::Data.get_server_data(params[:id])
      if rs.nil?
        status 404
        error_response "instance with id '#{params[:id]}' not found"
      else
        json Gaptool::Data.stringify_apps(rs, client_version)
      end
    end

    patch '/instance/:id' do
      rs = Gaptool::Data.get_server_data(params[:id])
      if rs.nil?
        status 404
        error_response "instance with id '#{params[:id]}' not found"
      else
        data = JSON.parse(request.body.read)
        unless data['hidden'].nil?
          hidden = !!data['hidden']
          rs['hidden'] = hidden if hidden == true
          rs.delete('hidden') if hidden == false
        end
        rs['terminable'] = !!data['terminable'] unless data['terminable'].nil?
        Gaptool::Data.save_server_data params[:id], rs
        json Gaptool::Data.stringify_apps(rs, client_version)
      end
    end

    get '/hosts/:role/:environment' do
      if params[:role] == 'ALL'
        list = Gaptool::Data.servers_in_env params[:environment]
      else
        list = Gaptool::Data.servers_in_role_env params[:role], params[:environment]
      end
      filter = if params['hidden']
                 proc { |_| false }
               else
                 proc { |s| s['hidden'] }
               end
      servers = list.map do |inst|
        data = Gaptool::Data.get_server_data(inst)
        Gaptool::Data.stringify_apps(data, client_version)
      end.delete_if(&filter)

      json servers
    end

    get '/host/:role/:environment/:instance' do
      json Gaptool::Data.stringify_apps(Gaptool::Data.get_server_data(params[:instance]), client_version)
    end

    get '/ssh/:role/:environment/:instance' do
      data = Gaptool::Data.get_server_data params[:instance]
      host = data['hostname']
      key, pubkey = Gaptool::EC2.putkey(host)
      json hostname: host, key: key, pubkey: pubkey
    end

    get '/version' do
      version = settings.version
      json server_version: version, api: { v0: '/' }
    end

    post '/rehash' do
      json Gaptool::EC2.rehash
    end
  end
end
