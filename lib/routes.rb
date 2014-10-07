# encoding: utf-8
require 'set'
require_relative 'exceptions'
class GaptoolServer < Sinatra::Application

  get '/' do
    "You must be lost. Read the instructions."
  end

  get '/ping' do
    "PONG"
  end

  post '/init' do
    data = JSON.parse request.body.read
    data = data.delete_if { |k,v| v.nil? }
    required_keys = %w(role environment zone itype).to_set
    keys = data.keys.to_set
    unless keys > required_keys
      raise BadRequest, "Missing required_parameters: #{(required_keys - keys).to_a.join(" ")}"
    end

    # create shared secret to reference in /register
    secret = (0...8).map{65.+(rand(26)).chr}.join
    security_group = data['security_group'] || Gaptool::Data::get_role_data(data['role'])["security_group"]
    sgid = Gaptool::EC2::get_or_create_securitygroup(data['role'], data['environment'], data['zone'], security_group)
    image_id = data['ami'] || Gaptool::Data::get_ami_for_role(data['role'], data['zone'])
    data['chef_runlist'] = data['chef_runlist'].nil? ? Gaptool::Data::get_runlist_for_role(data['role']) : data['chef_runlist']
    data['terminate'] = data['terminate'].nil? ? true : !!data['terminate']

    id = Gaptool::EC2::create_ec2_instance(
    {
      :image_id => image_id,
      :availability_zone => data['zone'],
      :instance_type => data['itype'],
      :key_name => "gaptool",
      :security_group_ids => sgid,
      :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{$redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash"
     }, {
       role: data['role'],
       env: data['environment'],
       zone: data['zone']
     }
    )
    # Add host tag
    Gaptool::Data::addserver(id, data, secret)
    json instance: id
  end

  post '/terminate' do
    data = JSON.parse request.body.read
    host_data = Gaptool::Data::get_server_data data['id']
    raise NotFound, "No such instance: #{data['id']}" if host_data.nil?
    raise Conflict, "Instance #{data['id']} cannot be terminated" if host_data['terminate'] == false

    Gaptool::EC2::terminate_ec2_instance(data['zone'], data['id'])
    rmserver(data['id'])
    json data['id'] => {'status' => 'terminated'}
  end

  put '/register' do
    data = JSON.parse request.body.read
    instance_id = register_server data['role'], data['environment'], data['secret']
    raise Forbidden, "Can't register instance: wrong secret or missing role/environment" unless instance_id

    hostname = Gaptool::EC2::get_ec2_instance_data(data['zone'].chop, instance_id)[:hostname]
    apps = apps_in_role(data['role'])
    host_data = Gaptool::Data::get_server_data instance_id, initkey: true

    init_recipe = 'recipe[init]'
    run_list = [init_recipe]
    unless host_data['chef_runlist'].nil?
      run_list = [*eval(host_data['chef_runlist'])]
      unless run_list.include? init_recipe
        run_list.unshift(init_recipe)
      end
      data['chef_runlist'] = run_list.to_json
    end

    if run_list.length == 1 && run_list[0] == init_recipe
      host_data.delete('chef_runlist')
      Gaptool::Data::save_server_data instance_id host_data
    end

    chef_repo = host_data['chef_repo']
    chef_branch = host_data['chef_branch']
    # FIXME: remove init key from redis
    initkey = host_data['init_key']
    run_list = host_data['chef_runlist'].to_json

    jdata = {
      'hostname' => hostname,
      'recipe' => 'init',
      'number' => instance_id,
      'instance' => instance_id,
      'run_list' => run_list,
      'role' => data['role'],
      'environment' => data['environment'],
      'chefrepo' => chef_repo,
      'chefbranch' => chef_branch,
      'identity' => initkey,
      'appuser' => Gaptool::Data::get_config('appuser'),
      'apps' => apps
    }.to_json

    erb :init, locals: {
      initkey: initkey,
      chef_branch: chef_branch,
      chef_repo: chef_repo,
      json: jdata
    }
  end

  get '/hosts' do
    json servers.map do |inst|
      Gaptool::Data::get_server_data inst
    end
  end

  get '/apps' do
    out = {}
    apps.each do |app|
      out[app] = Gaptool::Data::get_app_data(app)
    end
    json out
  end

  get '/hosts/:role' do
    json servers_in_role(params[:role]).map do |inst|
      Gaptool::Data::get_server_data inst
    end
  end

  get '/instance/:id' do
    json Gaptool::Data::get_server_data(params[:id])
  end

  get '/hosts/:role/:environment' do
    if params[:role] == 'ALL'
      list = Gaptool::Data::servers_in_env params[:environment]
    else
      list = Gaptool::Data::servers_in_role_env params[:role], params[:environment]
    end
    json list.map do |inst|
      Gaptool::Data::get_server_data inst
    end
  end

  get '/host/:role/:environment/:instance' do
    json Gaptool::Data::get_server_data params[:instance]
  end

  get '/ssh/:role/:environment/:instance' do
    data = Gaptool::Data::get_server_data params[:instance]
    host = data['hostname']
    key, pubkey = Gaptool::EC2::putkey(host)
    json hostname: host, key: key, pubkey: pubkey
  end

  get '/version' do
    version = File.read(File.realpath(
      File.join(File.dirname(__FILE__), "..", "..", 'VERSION')
    )).strip
    json server_version: version, api: {v0: "/"}
  end

  post '/rehash' do
    json Gaptool::Rehash::rehash()
  end

end
