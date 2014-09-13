# encoding: utf-8
module GaptoolBaseHelpers

  def configure_ec2 zone
    AWS.config(:access_key_id => $redis.hget('config', 'aws_id'),
               :secret_access_key => $redis.hget('config', 'aws_secret'),
               :ec2_endpoint => "ec2.#{zone}.amazonaws.com")
  end

  def putkey(host)
    @key = OpenSSL::PKey::RSA.new 2048
    @pubkey = "#{@key.ssh_type} #{[@key.to_blob].pack('m0')} GAPTOOL_GENERATED_KEY"
    ENV['SSH_AUTH_SOCK'] = ''
    Net::SSH.start(host, 'admin',
                   :key_data => [$redis.hget('config', 'gaptoolkey')],
                   :config => false, :keys_only => true,
                   :paranoid => false) do |ssh|
      ssh.exec! "grep -v GAPTOOL_GENERATED_KEY ~/.ssh/authorized_keys > /tmp/pubkeys"
      ssh.exec! "echo #{@pubkey} >> /tmp/pubkeys"
      ssh.exec! "mv /tmp/pubkeys ~/.ssh/authorized_keys"
    end
    return @key.to_pem
  end

  def get_or_create_securitygroup(role, environment, zone, groupname=nil)
    configure_ec2 zone.chop
    @ec2 = AWS::EC2.new
    groupname = groupname || "#{role}-#{environment}"
    @ec2.security_groups.each do |group|
      if group.name == groupname
        return group.id
      end
    end
    internet = ['0.0.0.0/0']
    sg = @ec2.security_groups.create(groupname)
    sg.authorize_ingress :tcp, 22, *internet
    return sg.id
  end
end
