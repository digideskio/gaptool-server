require_relative "ec2"
require_relative "data"

module Gaptool
  module EC2
    def self.rehash()
      Gaptool::Data::servers.each do |inst|
        Gaptool::Data::rmserver inst
      end
      roles = Gaptool::Data::roles
      Gaptool::Data::zones.each do |zone|
        Gaptool::EC2::configure_ec2 zone
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
            "zone"=> instance.availability_zone,
            "role"=> role,
            "environment"=> environment,
            "hostname" => instance.public_dns_name,
            "launch_time" => instance.launch_time.to_s,
            "apps" => roles[role].to_s,
            "instance"=> instance.instance_id,
            "security_group" => instance.security_groups[0].name
          }
          Gaptool::Data::addserver(iid, data, nil)
        end
      end
      return {"action" => "complete"}
    end

    def self.rehash_property(property)
      Gaptool::Data::servers.each do |id|
        rehash_property_for_instance(property, id)
      end
    end

    def self.rehash_properties_for_instance(instance_id)
      %w[hostname itype security_group].each do |property|
        self.rehash_property_for_instance(property, instance_id)
      end.all?
    end

    def self.rehash_property_for_instance(property, instance_id)
      data = Gaptool::Data::get_server_data(instance_id)
      property = property.to_s
      return false if data[property].nil? || data[property].empty?
      Gaptool::EC2::configure_ec2 data['zone']
      ec2 = AWS::EC2.new
      instance = ec2.instances[instance_id]
      case property
      when "hostname"
        data[property] = instance.public_dns_name
      when "itype"
        data[property] = instance.instance_type
      when "security_group"
        data[property] = instance.security_groups[0].name
      else
        return false
      end
      Gaptool::Data.save_server_data(instance_id, data)
      true
    end
  end
end
