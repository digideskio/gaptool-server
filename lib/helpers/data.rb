require 'json'

module DataHelper

  def addserver(instance, data, secret)
    role = data['role']
    environment = data['environment']
    if role.nil? or environment.nil?
      raise
    end

    unless data['chef_runlist'].nil?
      data['chef_runlist'] = [*data['chef_runlist']]
      data['chef_runlist'] = data['chef_runlist'].to_json
    end

    $redis.sadd("instances", instance)
    $redis.sadd("role:#{role}:instances", instance)
    $redis.sadd("environment:#{environment}:instances", instance)
    $redis.hmset("instance:#{instance}", *data.flatten)
    unless secret.nil?
      $redis.sadd('instances:unregistered', instance)
      $redis.set("instances:secrets:#{data['role']}:#{data['environment']}:#{secret}", instance)
    end
  end

  def register_server(role, environment, secret)
    key = "instances:secrets:#{role}:#{environment}:#{secret}"
    instance = $redis.get(key)
    unless instance.nil?
      $redis.srem('instances:unregistered', instance)
      $redis.del(key)
      instance
    end
  end

  def rmserver(instance)
    data = get_server_data instance
    unless data.nil?
      $redis.srem("instances", instance)
      $redis.srem("role:#{data['role']}:instances", instance)
      $redis.srem("environment:#{data['environment']}:instances", instance)
      $redis.del("instance:#{instance}")
    end
  end

  def get_config(key)
    $redis.hget('config', key)
  end

  def get_server_data(instance, opts={})
    rs = $redis.hgetall("instance:#{instance}")
    if rs['chef_runlist'].nil?
      rs['chef_runlist'] = get_config('default_runlist') || 'recipe[init]'
    else
      rs['chef_runlist'] = JSON.parse rs['chef_runlist']
    end
    %w(chef_repo chef_branch).each do |v|
      if rs[v].nil? || rs[v].empty?
        rs[v] = get_config(v.gsub(/_/, ''))
      end
    end
    if opts[:initkey]
      rs['initkey'] = get_config('initkey')
    end
    rs
  end

  def get_app_data(app)
    $redis.hgetall("app:#{app}")
  end

  def get_role_data(role)
    $redis.hgetall("role:#{role}")
  end

  def get_ami_for_role(role, zone)
    zone = zone.chop
    $redis.hget("amis:#{role}", zone) || $redis.hget("amis", zone)
  end

  def get_runlist_for_role(role)
    rl = $redis.hget("role:#{data['role']}", "chef_runlist")
    unless rl.nil?
      JSON.parse rl
    end
  end

  def zones
    $redis.hgetall('amis').keys
  end

  def servers_in_role(role)
    $redis.smembers("role:#{role}:instances")
  end

  def servers_in_env(env)
    $redis.smembers("environment:#{env}:instances")
  end

  def servers_in_role_env(role, env)
    $redis.sinter("role:#{role}:instances", "environment:#{env}:instances")
  end

  def servers
    $redis.smembers("instances")
  end

  def roles
    Hash[$redis.smembers("roles").map {|r| [r, apps_in_role(r)] }]
  end

  def apps
    $redis.smembers("apps")
  end

  def apps_in_role(role)
    $redis.smembers("role:#{role}:apps")
  end

end
