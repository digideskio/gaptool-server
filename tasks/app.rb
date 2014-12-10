namespace :app do
  desc "Add an application"
  task :add, [:app, :role] do |t, args|
    abort("Missing parameters") if args[:app].nil? || args[:app].empty? || args[:role].nil? || args[:role].empty?
    ex = DH.get_app_data(args[:app])
    unless ex.nil?
      puts "Updating application #{args[:app]}" unless ex.nil?
      DH.remove_app(args[:app])
    end
    DH.add_app(args[:app], args[:role])
    puts "Added app #{args[:app]} in role #{args[:role]}"
  end

  desc "Remove an application"
  task :del, [:app] do |t, args|
    unless args[:app].nil? || args[:app].empty?
      DH.remove_app(args[:app])
      puts "Removed app #{args[:app]}"
    end
  end

  desc "Print app info"
  task :info, [:app] do |t, args|
    info = DH.get_app_data(args[:app])
    if info.nil? || info.empty?
      puts "No such app #{args[:app]}"
    else
      puts " * #{args[:app]} => #{info["role"]}"
    end

  end
end

desc "List apps"
task :app do
  puts "Apps:"
  DH.apps.each do |app|
    info = DH.get_app_data(app)
    puts " * #{app} => #{info["role"]}"
  end
end
