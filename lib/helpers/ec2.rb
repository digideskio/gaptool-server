require 'aws-sdk'
require 'securerandom'

# encoding: utf-8
module Gaptool
  module EC2

    def self.configure_ec2 zone
      return if ENV['DRYRUN']
      id = ENV['AWS_ACCESS_KEY_ID']
      secret = ENV['AWS_SECRET_ACCESS_KEY']
      AWS.config(access_key_id: id, secret_access_key: secret,
                 ec2_endpoint: "ec2.#{zone}.amazonaws.com")
    end

    def self.putkey(host)
      return "FAKEKEY", "FAKEPUB" if ENV['DRYRUN']
      key = OpenSSL::PKey::RSA.new 2048
      pubkey = "#{key.ssh_type} #{[key.to_blob].pack('m0')} GAPTOOL_GENERATED_KEY"
      ENV['SSH_AUTH_SOCK'] = ''
      Net::SSH.start(host, 'admin',
                     :key_data => [$redis.hget('config', 'gaptoolkey')],
                     :config => false, :keys_only => true,
                     :paranoid => false) do |ssh|
        ssh.exec! "grep -v GAPTOOL_GENERATED_KEY ~/.ssh/authorized_keys > /tmp/pubkeys"
        ssh.exec! "echo #{pubkey} >> /tmp/pubkeys"
        ssh.exec! "mv /tmp/pubkeys ~/.ssh/authorized_keys"
      end
      return key.to_pem, pubkey
    end

    def self.get_or_create_securitygroup(role, environment, zone, groupname=nil)
      return "sg-test#{SecureRandom.hex(2)}" if ENV['DRYRUN']
      configure_ec2 zone.chop
      ec2 = AWS::EC2.new
      groupname = groupname || "#{role}-#{environment}"
      ec2.security_groups.each do |group|
        if group.name == groupname
          return group.id
        end
      end
      internet = ['0.0.0.0/0']
      sg = ec2.security_groups.create(groupname)
      sg.authorize_ingress :tcp, 22, *internet
      return sg.id
    end

    def self.create_ec2_instance(ec2opts, data)
      if ENV['DRYRUN']
        id = "i-test#{SecureRandom.hex(2)}"
        return {id: id,
                hostname: "test-#{id}.#{data[:zone].chop}.compute.amazonaws.com",
                launch_time: Time.now.to_s}
      end
      configure_ec2 data[:zone].chop
      ec2 = AWS::EC2.new

      instance = ec2.instances.create(ec2opts)
      instance.add_tag('Name', value: "#{data[:role]}-#{data[:env]}-#{instance.id}")
      instance.add_tag('gaptool', :value => "yes")
      launch_time = instance.launch_time.to_s
      launch_time = launch_time.empty? ? Time.now.to_s : launch_time
      {
        id: instance.id,
        hostname: instance.public_dns_name,
        launch_time: launch_time
      }
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
      return {
        hostname: instance.dns_name
      }
    end
  end
end
