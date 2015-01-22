namespace :role do
  desc "Set security group for a role"
  task :set_sg, [:role, :environment, :security_group] do |t, args|
    abort("Missing parameters") if args[:role].nil? || args[:environment].nil? || args[:role].empty? || args[:environment].empty? || args[:security_group].nil? || args[:security_group].empty?
    role = DH.get_role_data(args[:role])
    role['sg'].merge!(args[:environment] => args[:security_group])
    DH.save_role_data(args[:role], role)
  end
end
