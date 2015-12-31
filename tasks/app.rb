namespace :app do
  desc 'Add an application'
  task :add, [:app, :role, :environment] do |_t, args|
    [:app, :role, :environment].each do |arg|
      abort("Missing parameter #{arg}") if args[arg].nil? || args[arg].empty?
    end
    ex = DH.get_app_data(args[:app])
    unless ex.nil?
      puts "Updating application #{args[:app]} (#{args[:environment]}) to #{args[:role]}"
      DH.remove_app(args[:app])
      ex.delete(args[:environment])
    end
    DH.add_app(args[:app], args[:role], args[:environment])
    ex.each do |env, role|
      DH.add_app(args[:app], role, env)
    end
    puts "Added app #{args[:app]}, role #{args[:role]}, environment: #{args[:environment]}"
  end

  desc 'Remove an application'
  task :del, [:app] do |_t, args|
    unless args[:app].nil? || args[:app].empty?
      DH.remove_app(args[:app])
      puts "Removed app #{args[:app]}"
    end
  end

  desc 'Print app info'
  task :info, [:app] do |_t, args|
    info = DH.get_app_data(args[:app])
    if info.nil? || info.empty?
      puts "No such app #{args[:app]}"
    else
      puts " * #{app} #{info.map { |k, v| "#{k}: #{v}" }.join(', ')}"
    end
  end

  desc 'Copy all apps for a role to a new env'
  task :newenv, [:role, :oldenv, :newenv, :newrole] do |_t, args|
    [:role, :oldenv, :newenv].each do |k|
      abort "Missing parameter #{k}" if args[k].nil?
    end
    newrole = args[:newrole] || args[:role]
    DH.apps_in_role(args[:role], args[:oldenv]).each do |app|
      puts " * app: #{app} to role #{newrole} (#{args[:newenv]})"
      DH.add_app(app, newrole, args[:newenv])
    end
  end
end

desc 'List apps'
task :app do
  puts 'Apps:'
  DH.apps.each do |app|
    info = DH.get_app_data(app)
    puts " * #{app} #{info.map { |k, v| "#{k}: #{v}" }.join(', ')}"
  end
end
