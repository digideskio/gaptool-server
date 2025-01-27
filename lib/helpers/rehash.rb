require_relative 'ec2'
require_relative 'data'
require 'logger'

module Gaptool
  module EC2
    def self.rehash
      Gaptool::Data.servers.each do |inst|
        Gaptool::Data.rmserver inst
      end
      roles = Gaptool::Data.roles
      Gaptool::Data.zones.each do |zone|
        Gaptool::EC2.configure_ec2 zone
        @ec2 = AWS::EC2.new
        ilist = []
        @ec2.instances.each do |instance|
          if instance.tags['gaptool'] == 'yes' && instance.status == :running
            ilist << instance
          end
        end
        ilist.each do |instance|
          puts " - #{instance.tags['Name']}"
          role, environment, iid = instance.tags['Name'].split('-', 3)
          data = {
            'zone' => instance.availability_zone,
            'role' => role,
            'environment' => environment,
            'hostname' => instance.public_dns_name,
            'launch_time' => instance.launch_time.to_s,
            'apps' => roles[role].to_s,
            'instance' => instance.instance_id,
            'security_group' => instance.security_groups[0].name
          }
          Gaptool::Data.addserver(iid, data, nil)
        end
      end
      { 'action' => 'complete' }
    end

    def self.rehash_property(property)
      Gaptool::Data.servers.each do |id|
        rehash_property_for_instance(property, id)
      end
    end

    def self.rehash_properties_for_instance(instance_id)
      res = {}
      %w(hostname itype security_group).each do |property|
        res[property] = rehash_property_for_instance(property, instance_id, false)
      end
      Gaptool::Data.set_server_data_attributes(instance_id, res)
    end

    def self.rehash_property_for_instance(property, instance_id, save = true)
      logger = Logger.new(STDOUT)
      data = Gaptool::Data.get_server_data(instance_id)
      return false if data.nil? || data['zone'].nil? || data['zone'].empty?
      Gaptool::EC2.configure_ec2 data['zone'].chop
      ec2 = AWS::EC2.new(region: data['zone'].chop)
      logger.info("Updating #{property} for #{instance_id} in zone #{data['zone'].chop}")
      instance = ec2.instances[instance_id]
      return false if instance.nil?
      case property
      when 'hostname'
        value = instance.public_dns_name
      when 'itype'
        value = instance.instance_type
      when 'security_group'
        value = instance.security_groups[0].name
      when 'launch_time'
        value = instance.launch_time.to_i
      else
        return false
      end
      logger.info("Setting #{property} to #{value} for #{instance_id}")
      if save
        Gaptool::Data.set_server_data_attr(instance_id, property, value)
      else
        value
      end
    end
  end
end
