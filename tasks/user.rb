namespace :user do
  desc 'Add a new user. rake user:create <username>'
  task :create, [:username] do |_t, args|
    puts DH.useradd(args[:username])[:key]
  end

  desc 'Rename a user. rake user:rename <oldname> <newname>'
  task :rename, [:oldname, :newname] do |_t, args|
    user = DH.user(args[:oldname])
    abort("Unknown user #{args[:oldname]}") if user.nil?
    DH.userdel(user[:username])
    DH.useradd(args[:newname], user[:key])
    puts "User #{args[:oldname]} renamed to #{args[:newname]}"
  end

  desc 'Delete a user. rake user:delete <username>'
  task :delete, [:username] do |_t, args|
    DH.userdel(args[:username])
  end

  desc 'Set user key. rake user:setkey <username> <key>'
  task :setkey, [:username, :key] do |_t, args|
    user = DH.user(args[:username])
    abort("Unknown user #{args[:username]}") if user.nil?
    puts DH.useradd(args[:username], args[:key])
  end
end

desc 'List users'
task :user do
  puts DH.users.keys.sort.join("\n")
end
