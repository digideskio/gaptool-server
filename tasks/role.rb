require 'pp'

namespace :role do
  desc "Set security group for a role"
  task :set_sg, [:role, :environment, :security_group] do |t, args|
    abort("Missing parameters") if args[:role].nil? || args[:environment].nil? || args[:role].empty? || args[:environment].empty? || args[:security_group].nil? || args[:security_group].empty?
    role = DH.get_role_data(args[:role], args[:environment])
    role['sg'].merge!(args[:environment] => args[:security_group])
    DH.save_role_data(args[:role], role)
  end

  desc "Set ami for role"
  task :set_amis, [:role, :region, :ami_id] do |t, args|
    abort("Missing parameters") if args[:role].nil? || args[:region].nil? || args[:role].empty? || args[:region].empty? || args[:ami_id].nil? || args[:ami_id].empty?
    role = DH.get_role_data(args[:role])
    role['amis'].merge!(args[:region], args[:ami_id])
    DH.save_role_data(args[:role], role)
  end

  desc "Set runlist for role; Runlist must be a comma separated string of recipes and roles. e.g. 'recipe[recipe],role[otherrole]'"
  task :set_chef_runlist, [:role, :chef_runlist] do |t, args|
    abort("Missing parameters") if args[:role].nil? || args[:chef_runlist].nil? || args[:role].empty? || args[:chef_runlist].empty?
    role = DH.get_role_data(args[:role])
    rl = args[:chef_runlist].strip.split(",").map{|x| x.strip}.to_json
    role['chef_runlist'] = rl
    DH.save_role_data(args[:role], role)
    puts "Added runlist for role #{role}"
  end

  desc "Remove a role, if there are no instances running"
  task :remove, [:role] do |t, args|
    abort("Missing parameters") if args[:role].nil? || args[:role].empty?
    res = DH.remove_role(args[:role])
    if res == true
      puts "Removed role #{args[:role]}"
    else
      puts "Cannot remove role: #{res.inspect}"
    end
  end
end

desc "List all roles (environment is optional but needed to display apps)"
task :role, [:environment] do |t, args|
  env = args[:environment]
  puts "Roles:"
  DH.roles(env).each do |role, info|
    puts "* #{role}:"
    puts "  - apps: #{info['apps'].join(", ")}"
    puts "  - sg: #{info['sg'].values.join(", ")}"
    puts "  - amis: #{info['amis'].map{|k,v| "#{v} (#{k})"}.join(", ")}"
    puts "  - runlist: #{info['chef_runlist'].to_a.join(", ")}"
  end
end
