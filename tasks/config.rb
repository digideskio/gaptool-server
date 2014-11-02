namespace :config do
  desc "Add or update a new config key"
  task :set, [:key,:value] do |t, args|
    DH.set_config(args[:key], args[:value])
  end

  desc "Delete a key if set"
  task :del, [:key] do |t, args|
    DH.del_config(args[:key])
  end

  desc "Get a config"
  task :get, [:key] do |t,args|
    DH.get_config(args[:key])
  end
end

desc "List config"
task :config do
  puts 'Config:'
  DH.get_all_configs().keys.each do |k|
    puts " - #{k}"
  end
end
