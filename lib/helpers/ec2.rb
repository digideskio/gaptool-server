# encoding: utf-8
require 'aws-sdk'
require 'securerandom'
require 'logger'
require 'airbrake'
require_relative 'redis'

module Gaptool
  module EC2
    def self.logger
      @logger ||= Logger.new(STDERR)
    end

    def self.configure_ec2(zone)
      return if ENV['DRYRUN']
      id = ENV['AWS_ACCESS_KEY_ID']
      secret = ENV['AWS_SECRET_ACCESS_KEY']
      AWS.config(access_key_id: id, secret_access_key: secret,
                 ec2_endpoint: "ec2.#{zone}.amazonaws.com")
    end

    def self.putkey(host)
      return 'FAKEKEY', 'FAKEPUB' if ENV['DRYRUN']
      key = OpenSSL::PKey::RSA.new 2048
      pubkey = "#{key.ssh_type} #{[key.to_blob].pack('m0')} GAPTOOL_GENERATED_KEY"
      ENV['SSH_AUTH_SOCK'] = ''
      Net::SSH.start(host, 'admin',
                     key_data: [Gaptool.redis.hget('config', 'gaptoolkey')],
                     config: false, keys_only: true,
                     paranoid: false) do |ssh|
        ssh.exec! 'grep -v GAPTOOL_GENERATED_KEY ~/.ssh/authorized_keys > /tmp/pubkeys'
        ssh.exec! "echo #{pubkey} >> /tmp/pubkeys"
        ssh.exec! 'mv /tmp/pubkeys ~/.ssh/authorized_keys'
      end
      [key.to_pem, pubkey]
    end

    def self.get_or_create_securitygroup(role, environment, zone, groupname = nil)
      return "sg-test#{SecureRandom.hex(2)}" if ENV['DRYRUN']
      configure_ec2 zone.chop
      ec2 = AWS::EC2.new
      groupname ||= "#{role}-#{environment}"
      ec2.security_groups.each do |group|
        return group.id if group.name == groupname
      end
      internet = ['0.0.0.0/0']
      sg = ec2.security_groups.create(groupname)
      sg.authorize_ingress :tcp, 22, *internet
      sg.id
    end

    def self.create_ec2_instance(ec2opts, data, retries = 3, sleeptime = 0.5)
      if ENV['DRYRUN']
        id = "i-test#{SecureRandom.hex(2)}"
        return { id: id,
                 hostname: "test-#{id}.#{data[:zone].chop}.compute.amazonaws.com",
                 instance: nil,
                 launch_time: Time.now.to_i }
      end
      configure_ec2 data[:zone].chop
      ec2 = AWS::EC2.new

      i = 0
      begin
        instance = ec2.instances.create(ec2opts)
        logger.debug("Spawned instance #{instance.id}")
      rescue => e
        i += 1
        raise if i > retries
        logger.error("Error while creating instance: #{e}: sleeping #{sleeptime}s and retrying (#{i}/#{retries})")
        sleep sleeptime
        retry
      end

      i = 0
      begin
        hostname = instance.public_dns_name
      rescue => e
        i += 1
        if i > retries
          logger.error("Could not get hostname for instance #{instance} after #{retries} retries, setting to nil")
          hostname = nil
          Airbrake.notify_or_ignore(
            e,
            error_class: 'EC2 public dns fail',
            parameters: { instance: instance.id, role: data['role'], environment: data['environment'], hostname: nil }
          )
        else
          logger.error("Error getting hostname for instance: #{e}: sleeping #{sleeptime}s and retrying (#{i}/#{retries})")
          sleep sleeptime
          retry
        end
      end

      i = 0
      begin
        launch_time = instance.launch_time.to_i
        fail unless launch_time.is_a? Integer

      rescue => e
        i += 1
        if i > retries
          logger.error("Cloud not get launch time for instance #{instance} after #{retries} retries. Setting to now()")
          launch_time = Time.now.to_i
          Airbrake.notify_or_ignore(
            e,
            error_class: 'EC2 get launch_time fail',
            parameters: { instance: instance.id, role: data['role'], environment: data['environment'], hostname: nil }
          )
        else
          logger.error("Error getting launch_time for instance: #{e}: sleeping #{sleeptime}s and retrying (#{i}/#{retries})")
          sleep sleeptime
          retry
        end
      end

      logger.info { "Instance #{instance.id} launch_time: #{launch_time} #{instance.launch_time}" }

      {
        id: instance.id,
        instance: instance,
        hostname: hostname,
        launch_time: launch_time
      }
    end

    def self.tag_ec2_instance(instance, key, value, retries = 5, sleeptime = 0.5)
      return true if ENV['DRYRUN']
      i = 0
      begin
        instance.add_tag(key, value: value)
        logger.debug("Added tag #{key}=#{value} to #{instance.id}")
        true
      rescue => e
        i += 1
        raise if i > retries
        logger.error("Error adding tag #{key} to #{instance.id}: #{e}: sleeping #{sleeptime}s and retrying (#{i}/#{retries})")
        sleep sleeptime
        retry
      end
    end

    def self.terminate_ec2_instance(zone, id)
      return if ENV['DRYRUN']
      configure_ec2 zone
      ec2 = AWS::EC2.new
      instance = ec2.instances[id]
      instance.terminate
    end

    def self.get_ec2_instance_data(zone, id)
      if ENV['DRYRUN']
        return {
          hostname: 'fake.hostname.gild.com'
        }
      end
      configure_ec2 zone
      ec2 = AWS::EC2.new
      instance = ec2.instances[id]
      {
        hostname: instance.dns_name
      }
    end

    def self.retag
      logger = Logger.new(STDOUT)
      Gaptool::Data.servers.each do |id|
        data = Gaptool::Data.get_server_data(id)
        next if data.nil? || data['zone'].nil? || data['zone'].empty?
        Gaptool::EC2.configure_ec2 data['zone'].chop
        ec2 = AWS::EC2.new(region: data['zone'].chop)
        instance = ec2.instances[id]
        next if instance.tags.role && instance.tags.environment
        logger.info("Retagging instance #{id} in zone #{data['zone'].chop}")
        instance.tags.role = data['role']
        instance.tags.environment = data['environment']
      end
    end
  end
end
