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

      # TODO: I can call the /complete here, after piped the output of
      # /register to bash, or in the bash template, at the end of
      # /register itself.

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

      # TODO: Attention here:
      # lib/helpers/data.rb#L83 deletes the keys:
      # redis.multi do |m|
      #   m.hdel("instance:#{instance}", 'secret')
      #   m.hdel("instance:#{instance}", 'registered')
      #   m.srem('instances:unregistered', instance)
      #   m.del(key)
      opts = { mark_as: 'in_progress' }
      args = [data['role'], data['environment'], data['secret'], opts]
      instance_id = Gaptool::Data.register_server(*args)
      # TODO: Attention
      # We need to leave the secret in place, mark the machine as 'in
      # progress', then use the secret as a parameter for the /complete
      # call so we can validate its that machine. It will be during the
      # handling of the /complete endpoint that we will remove the
      # secret.
      # Then it's simply a matter of writing a rake task
      # (executed via cron) that every 15 min or so checks for the
      # machines 'in progress' or 'not yet registered' that are up for
      # more than $threshold minutes.

      fail Forbidden, "Can't register instance: wrong secret or missing role/environment" unless instance_id

      hostname = Gaptool::EC2.get_ec2_instance_data(data['zone'].chop, instance_id)[:hostname]
      Gaptool::Data.set_server_data_attr(instance_id, 'hostname', hostname)
      initkey = Gaptool::Data.get_config('initkey')
      jdata = Gaptool::Data.server_chef_json(instance_id, env, 'identity' => initkey)
      # force runlist
      jdata['run_list'] ||= Gaptool::Data.default_runlist

      erb :init, locals: {
        initkey: initkey,
        chef_branch: jdata['chefbranch'],
        chef_repo: jdata['chefrepo'],
        chef_environment: jdata['environment'],
        chef_version: Gaptool::Data.ensure_config('chef_version', '11.16.4'),
        json: jdata.to_json
        # TODO: Add data parameters to call the /complete in the init
        # template
      }
    end

    post '/complete/' do
      # TODO: WIP here
      data = JSON.parse request.body.read
      data = require_parameters(%w(role zone environment secret), data)
      args = [data['role'], data['environment'], data['secret']]
      instance_id = Gaptool::Data.register_server(*args)

      failmsg = "Can't register the completion: wrong secret or missing role/environment"
      raise(Forbidden, failmsg) unless instance_id
      # TODO: If the complete is arrived OK, notify OK
      # TODO: If the complete is arrived FAILED ensure to kill the
      # machine.
      # TODO: If after 50 minutes we didn't received a COMPLETE OK, kill
      # the machine
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

    get '/instance/:id/attrs' do
      begin
        data = JSON.parse(request.body.read.to_s)
      rescue
        data = {}
      end
      rs = Gaptool::Data.server_chef_json(params[:id], env, data)
      if rs.nil?
        status 404
        error_response "instance with id '#{params[:id]}' not found"
      else
        json rs
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

    get '/version' do
      version = settings.version
      json server_version: version, api: { v0: '/' }
    end

    post '/rehash' do
      json Gaptool::EC2.rehash
    end
  end
end
