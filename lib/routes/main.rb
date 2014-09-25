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
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'),
               :secret_access_key => $redis.hget('config', 'aws_secret'),
               :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    # create shared secret to reference in /register
    @secret = (0...8).map{65.+(rand(26)).chr}.join
    data.merge!("secret" => @secret)
    security_group = data['security_group'] || $redis.hget("role:#{data['role']}", "security_group")
    sgid = gt_securitygroup(data['role'], data['environment'], data['zone'], security_group)
    image_id = data['ami'] || $redis.hget("amis:#{data['role']}", data['zone'].chop) || $redis.hget("amis", data['zone'].chop)
    chef_runlist = $redis.hget("role:#{data['role']}", "chef_runlist")

    terminate = true
    unless data['terminate'].nil?
      terminate = false
    end

    unless data['chef_runlist'].nil?
      chef_runlist = data['chef_runlist'].to_json
    end
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
    # Create temporary redis entry for /register to pull the instance id
    # with an expire of 24h
    host_key = "instance:#{data['role']}:#{data['environment']}:#{@secret}"
    $redis.hmset(host_key, 'instance_id', instance.id,
                 'chef_branch', data['chef_branch'],
                 'chef_repo', data['chef_repo'],
                 'chef_runlist', chef_runlist,
                 'terminate', terminate)
    $redis.expire(host_key, 86400)
    "{\"instance\":\"#{instance.id}\"}"
  end

  post '/terminate' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'),
               :secret_access_key => $redis.hget('config', 'aws_secret'),
               :ec2_endpoint => "ec2.#{data['zone']}.amazonaws.com")
    keys = $redis.keys("*:*:#{data['id']}")
    if keys.nil? || keys.empty?
      error 404
    end
    if keys.length >= 1
      error 409
    end
    data = $redis.hgetall(keys.first)
    if data['terminate'] == false
      error 403
    end

    @ec2 = AWS::EC2.new
    @instance = @ec2.instances[data['id']]
    res = @instance.terminate
    res = $redis.del($redis.keys("*#{data['id']}"))
    out = {data['id'] => {'status'=> 'terminated'}}
    out.to_json
  end

  put '/register' do
    data = JSON.parse request.body.read
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'),
               :secret_access_key => $redis.hget('config', 'aws_secret'),
               :ec2_endpoint => "ec2.#{data['zone'].chop}.amazonaws.com")
    @ec2 = AWS::EC2.new
    host_key = "instance:#{data['role']}:#{data['environment']}:#{data['secret']}"
    host_data = $redis.hgetall(host_key)
    unless host_data
        error 403
    end
    @instance = @ec2.instances[host_data['instance_id']]
    hostname = @instance.dns_name
    $redis.del(host_key)
    @apps = []
    $redis.keys("app:*").each do |app|
      if $redis.hget(app, 'role') == data['role']
        @apps << app.gsub('app:', '')
      end
    end

    init_recipe = 'recipe[init]'
    @run_list = [init_recipe]
    unless host_data['chef_runlist'].nil?
      @run_list = [*eval(host_data['chef_runlist'])]
      unless @run_list.include? init_recipe
        @run_list.unshift(init_recipe)
      end
      data['chef_runlist'] = @run_list.to_json
    end

    data.merge!("capacity" => $redis.hget('capacity', data['itype']))
    data.merge!("hostname" => hostname)
    data.merge!("apps" => @apps.to_json)
    data.merge!("instance" => @instance.id)
    data['terminate'] = host_data['terminate'].nil? ? 'true' : host_data['terminate']
    hash2redis("host:#{data['role']}:#{data['environment']}:#{@instance.id}", data)

    @chef_repo = host_data['chef_repo'] && !host_data['chef_repo'].empty? ? host_data['chef_repo'] : $redis.hget('config', 'chefrepo')
    @chef_branch = host_data['chef_branch'] && !host_data['chef_branch'].empty? ? host_data['chef_branch'] : $redis.hget('config', 'chefbranch')
    @initkey = $redis.hget('config', 'initkey')
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
      'identity' => $redis.hget('config','initkey'),
      'appuser' => $redis.hget('config','appuser'),
      'apps' => @apps
    }.to_json

    erb :init
  end

  get '/hosts' do
    out = []
    $redis.keys("host:*").each do |host|
      out << $redis.hgetall(host)
    end
    out.to_json
  end

  get '/apps' do
    out = {}
    $redis.keys("app:*").each do |app|
      out.merge!(app => $redis.hgetall(app))
    end
    out.to_json
  end

  get '/hosts/:role' do
    out = []
    $redis.keys("host:#{params[:role]}:*").each do |host|
      out << $redis.hgetall(host)
    end
    out.to_json
  end

  get '/instance/:id' do
    $redis.hgetall($redis.keys("host:*:*:#{params[:id]}").first).to_json
  end

  get '/hosts/:role/:environment' do
    out = []
    unless params[:role] == "ALL"
      $redis.keys("host:#{params[:role]}:#{params[:environment]}*").each do |host|
        out << $redis.hgetall(host)
      end
    else
      $redis.keys("host:*:#{params[:environment]}:*").each do |host|
        out << $redis.hgetall(host)
      end
    end
    out.to_json
  end

  get '/host/:role/:environment/:instance' do
    $redis.hgetall("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}").to_json
  end

  get '/ssh/:role/:environment/:instance' do
    @host = $redis.hget("host:#{params[:role]}:#{params[:environment]}:#{params[:instance]}", 'hostname')
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
