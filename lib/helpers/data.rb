require 'json'
require 'securerandom'

module Gaptool
  module Data

    def self.addserver(instance, data, secret)
      role = data['role']
      environment = data['environment']
      if role.nil? || environment.nil?
        raise ArgumentError, "Missing role or environment"
      end

      if secret.nil? || secret.empty?
        raise ArgumentError, "Missing/empty secret"
      end

      if instance.nil? || instance.empty?
        raise ArgumentError, "Missing instance"
      end

      unless data['chef_runlist'].nil?
        data['chef_runlist'] = [*data['chef_runlist']]
        data['chef_runlist'] = data['chef_runlist'].to_json
      end

      $redis.sadd("instances", instance)
      $redis.sadd("role:#{role}:instances", instance)
      $redis.sadd("environment:#{environment}:instances", instance)
      unless secret.nil?
        data['registered'] = false
        $redis.sadd('instances:unregistered', instance)
        $redis.set("instances:secrets:#{data['role']}:#{data['environment']}:#{secret}", instance)
      end
      save_server_data instance, data
    end

    def self.save_server_data(instance, data)
      key = "instance:#{instance}"
      $redis.multi do
        $redis.del(key)
        $redis.hmset(key, *data.select{ |k,v| !v.nil? && ((v.is_a?(String) && !v.empty?) || !!v == v)}.flatten)
      end
    end

    def self.register_server(role, environment, secret)
      key = "instances:secrets:#{role}:#{environment}:#{secret}"
      instance = $redis.get(key)
      return nil if instance.nil? || instance.empty?
      $redis.hdel("instance:#{instance}", "registered")
      $redis.srem('instances:unregistered', instance)
      $redis.del(key)
      instance
    end

    def self.rmserver(instance)
      data = get_server_data instance
      unless data.nil?
        $redis.srem("instances", instance)
        $redis.srem("role:#{data['role']}:instances", instance)
        $redis.srem("environment:#{data['environment']}:instances", instance)
        $redis.del("instance:#{instance}")
      end
    end

    def self.get_config(key)
      $redis.hget('config', key)
    end

    def self.set_config(key, value)
      $redis.hset('config', key, value)
    end

    def self.get_server_data(instance, opts={})
      rs = $redis.hgetall("instance:#{instance}")
      return nil if rs.nil? || rs.empty?
      rs['instance'] = instance
      if !rs['chef_runlist'].nil? && !rs['chef_runlist'].empty?
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
      if !rs['terminate'].nil? && rs['terminate'] == "false"
        rs['terminate'] = false
      else
        rs.delete('terminate')
      end
      rs
    end

    def self.get_app_data(app)
      $redis.hgetall("app:#{app}")
    end

    def self.get_role_data(role)
      $redis.hgetall("role:#{role}")
    end

    def self.get_ami_for_role(role, zone)
      zone = zone.chop
      $redis.hget("amis:#{role}", zone) || $redis.hget("amis", zone)
    end

    def self.get_runlist_for_role(role)
      rl = $redis.hget("role:#{role}", "chef_runlist")
      unless rl.nil?
        JSON.parse rl
      end
    end

    def self.zones
      $redis.hgetall('amis').keys
    end

    def self.servers_in_role(role)
      $redis.smembers("role:#{role}:instances")
    end

    def self.servers_in_env(env)
      $redis.smembers("environment:#{env}:instances")
    end

    def self.servers_in_role_env(role, env)
      $redis.sinter("role:#{role}:instances", "environment:#{env}:instances")
    end

    def self.servers
      $redis.smembers("instances")
    end

    def self.roles
      Hash[$redis.smembers("roles").map {|r| [r, apps_in_role(r)] }]
    end

    def self.apps
      $redis.smembers("apps")
    end

    def self.apps_in_role(role)
      $redis.smembers("role:#{role}:apps")
    end

    def self.useradd(user, key=nil)
      key = SecureRandom.hex(64) unless key
      $redis.hset('users', user, key)
      {username: user, key: key}
    end

    def self.userdel(user)
      $redis.hdel('users', user)
    end

    def self.users
      $redis.hgetall('users')
    end

    def self.user(user)
      userdesc = {username: user, key: $redis.hget('users', user)}
      return userdesc[:key].nil? ? nil : userdesc
    end
  end
end
