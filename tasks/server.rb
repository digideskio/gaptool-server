namespace :server do
  desc "Set terminable flag to true/false for the instance :instance"
  task :set_terminable, [:instance, :value] do |t, args|
    if args[:instance].nil? || args[:value].nil?
      puts "You must specify instance and true/false"
      return
    end
    DH.set_server_data_attr args[:instance], 'terminable', (args[:value] == "true" ? "true" : "false")
    puts DH.get_server_data args[:instance]
  end

  desc "Remove a server from the gaptool database (no actions on AWS)"
  task :rm, [:instance] do |t, args|
    if args[:instance].nil?
      puts "You must select an instance"
      return 1
    end
    DH.rmserver(instance)
  end
end
