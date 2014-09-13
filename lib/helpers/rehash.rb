module RehashHelpers
  def rehash()
    servers.each do |inst|
      rmserver inst
    end
    layout = roles()
    puts layout
    zones.each do |zone|
      @ec2 = AWS::EC2.new(:access_key_id => $redis.hget('config', 'aws_id'),
                          :secret_access_key => $redis.hget('config', 'aws_secret'),
                          :ec2_endpoint => "ec2.#{zone}.amazonaws.com")
      ilist = []
      @ec2.instances.each do |instance|
        if instance.tags['gaptool'] == 'yes' && instance.status == :running
          ilist << instance
        end
      end
      ilist.each do |instance|
        puts " - #{instance.tags['Name']}"
        role, environment, iid = instance.tags['Name'].split('-')
        data = {
          "zone"=> instance.availability_zone,
          "itype"=> instance.instance_type,
          "role"=> role,
          "environment"=> environment,
          "hostname"=> instance.public_dns_name,
          "apps" => layout[role].to_s,
          "instance"=> instance.instance_id
        }
        puts data
        addserver(data['instance'], data, nil)
      end
    end
    return {"action" => "complete"}
  end
end
