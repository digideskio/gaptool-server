# encoding: utf-8
class GaptoolServer < Sinatra::Application

  get '/' do
    "You must be lost. Read the instructions."
  end

  get '/ping' do
    "PONG"
  end

  post '/init' do
    data = JSON.parse request.body.read
    configure_ec2 data['zone'].chop
    @ec2 = AWS::EC2.new

    # create shared secret to reference in /register
    @secret = (0...8).map{65.+(rand(26)).chr}.join
    security_group = data['security_group'] || get_role_data(data['role'])["security_group"]
    sgid = get_or_create_securitygroup(data['role'], data['environment'], data['zone'], security_group)
    image_id = data['ami'] || get_ami_for_role(data['role'], data['zone'])
    data['chef_runlist'] = data['chef_runlist'].nil? ? get_runlist_for_role(data['role']) : data['chef_runlist']
    data['terminate'] = data['terminate'].nil? ? true : !!data['terminate']

    instance = @ec2.instances.create(
      :image_id => image_id,
      :availability_zone => data['zone'],
      :instance_type => data['itype'],
      :key_name => "gaptool",
      :security_group_ids => sgid,
      :user_data => "#!/bin/bash\ncurl --silent -H 'X-GAPTOOL-USER: #{env['HTTP_X_GAPTOOL_USER']}' -H 'X-GAPTOOL-KEY: #{env['HTTP_X_GAPTOOL_KEY']}' #{$redis.hget('config', 'url')}/register -X PUT --data '#{data.to_json}' | bash"
    )
    # Add host tag
    instance.add_tag('Name', :value => "#{data['role']}-#{data['environment']}-#{instance.id}")
    instance.add_tag('gaptool', :value => "yes")
    addserver(instance.id, data, @secret)
    "{\"instance\":\"#{instance.id}\"}"
  end

  post '/terminate' do
    data = JSON.parse request.body.read
    configure_ec2 data['zone']
    host_data = get_server_data data['id']
    if host_data.nil?
      error 404
    end
    if host_data['terminate'] == false
      error 403
    end

    @ec2 = AWS::EC2.new
    @instance = @ec2.instances[data['id']]
    @instance.terminate
    rmserver(data['id'])
    out = {data['id'] => {'status'=> 'terminated'}}
    out.to_json
  end

  put '/register' do
    data = JSON.parse request.body.read
    configure_ec2 data['zone'].chop
    @ec2 = AWS::EC2.new
    instance_id = register_server data['role'], data['environment'], data['secret']
    error 403 unless instance_id
    @instance = @ec2.instances[instance_id]
    hostname = @instance.dns_name
    @apps = apps_in_role(data['role'])

    init_recipe = 'recipe[init]'
    @run_list = [init_recipe]
    unless host_data['chef_runlist'].nil?
      @run_list = [*eval(host_data['chef_runlist'])]
      unless @run_list.include? init_recipe
        @run_list.unshift(init_recipe)
      end
      data['chef_runlist'] = @run_list.to_json
    end

    data.merge!("hostname" => hostname)
    data.merge!("apps" => @apps.to_json)
    data.merge!("instance" => @instance.id)

    host_data = get_server_data instance_id, initkey: true
    @chef_repo = host_data['chef_repo']
    @chef_branch = host_data['chef_branch']
    # FIXME: remove init key from redis
    @initkey = host_data['init_key']
    @run_list = host_data['chef_runlist'].to_json

    @json = {
      'hostname' => hostname,
      'recipe' => 'init',
      'number' => @instance.id,
      'instance' => @instance.id,
      'run_list' => @run_list,
      'role' => data['role'],
      'environment' => data['environment'],
      'chefrepo' => @chef_repo,
      'chefbranch' => @chef_branch,
      'identity' => @initkey,
      'appuser' => $redis.hget('config','appuser'),
      'apps' => @apps
    }.to_json

    erb :init
  end

  get '/hosts' do
    servers.map do |inst|
      get_server_data inst
    end.to_json
  end

  get '/apps' do
    out = {}
    apps.each do |app|
      out[app] = get_app_data(app)
    end
    out.to_json
  end

  get '/hosts/:role' do
    servers_in_role(params[:role]).map do |inst|
      get_server_data inst
    end.to_json
  end

  get '/instance/:id' do
    get_server_data(params[:id]).to_json
  end

  get '/hosts/:role/:environment' do
    if params[:role] == 'ALL'
      list = servers_in_env params[:environment]
    else
      list = servers_in_role_env params[:role], params[:environment]
    end
    list.map do |inst|
      get_server_data inst
    end.to_json
  end

  get '/host/:role/:environment/:instance' do
    get_server_data params[:instance]
  end

  get '/ssh/:role/:environment/:instance' do
    data = get_server_data params[:instance]
    @host = data['hostname']
    @key = putkey(@host)
    {'hostname' => @host, 'key' => @key, 'pubkey' => @pubkey}.to_json
  end

  get '/version' do
    version = File.read(File.realpath(
      File.join(File.dirname(__FILE__), "..", "..", 'VERSION')
    )).strip
    return {"server_version" => version, "api" => {"v0"=> "/"}}.to_json
  end

end
