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
            "hostname"=> instance.public_dns_name,
            "apps" => roles[role].to_s,
            "instance"=> instance.instance_id
          }
          Gaptool::Data::addserver(iid, data, nil)
        end
      end
      return {"action" => "complete"}
    end
  end
end
