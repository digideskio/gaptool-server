# encoding: utf-8
Dir.chdir(File.dirname(__FILE__))
require_relative 'lib/helpers/data'
require_relative 'lib/helpers/redis'
class DataHelperIncluder
  include DataHelper
end

DH = DataHelperIncluder.new
$stdout.sync = true

def sys(cmd)
  IO.popen(cmd) do |f|
    until f.eof?
      puts f.gets
    end
  end
end

def printimages
  puts %x[docker images | grep '^gild/gaptool']
end

namespace :docker do
  namespace :build do
    task :image do
      sys(['./scripts/build_docker_images.sh'])
      printimages
    end

    desc "Build the release image"
    task :release do
      sys(['./scripts/build_docker_images.sh', '-t', 'release'])
      printimages
    end

    task :all => [:image]
  end

  namespace :push do
    task :release do
      sys(['docker', 'push', 'gild/gaptool:release'])
    end

    desc 'Push all tags to the Docker Hub'
    task :all do
      sys(['docker', 'push', 'gild/gaptool'])
    end
  end

  desc 'Build the docker image'
  task :build => 'build:image'

  desc "Push the release image to the Docker Hub"
  task :push => 'push:release'

  task :up => [:build, :recreate]

  desc "Run tests w/ docker"
  task :test => :up do
    sys(%q(fig run --rm gaptool rake test))
  end

  desc "Stop docker containers"
  task :stop do
    sys(%q(fig stop))
  end

  desc "Start docker containers"
  task :start do
    sys(%q(fig start))
  end

  desc "Restart docker containers"
  task :restart => [:stop, :start]

  desc "Stop and remove docker containers (alias 'rm')"
  task :remove => :stop do
    sys(%q(fig rm --force))
  end

  task :rm => :remove

  desc "Recreate docker containers without building"
  task :recreate do
    sys(%q(fig up -d))
  end
end

namespace :user do
  desc "Add a new user. rake user:create <username>"
  task :create do
    if ARGV[1].nil?
      abort('rake user:create <username>')
    end
    puts DH.useradd(ARGV[1])[:key]
  end

  desc "Rename a user. rake user:rename <oldname> <newname>"
  task :rename do
    if ARGV[1].nil? || ARGV[2].nil
      abort('Missing required arguments')
    end
    user = DH.user(ARGV[1])
    DH.userdel(user[:username])
    DH.adduser(ARGV[2], user[:key])
    puts "User #{ARGV[1]} renamed to #{ARGV[2]}"
  end

  desc "Delete a user. rake user:delete <username>"
  task :delete do
    if ARGV[1].nil?
      abort('rake user:delete <username>')
    end
    puts DH.userdel(ARGV[1])
  end

  desc "Set user key. rake user:setkey <username> <key>"
  task :setkey do
    if ARGV[1].nil? || ARGV[2].nil
      abort('Missing required arguments')
    end
    user = DH.user(ARGV[1])
    if user.nil?
      abort('Unknown user')
    end
    puts DH.useradd(ARGV[1], ARGV[2])
  end
end

desc "Bring up docker containers"
task :docker => 'docker:up'

desc "Start the shell"
task :shell do
  exec "racksh #{Shellwords.join(ARGV[1..-1])}"
end
task :sh => :shell

desc "Start the HTTP server"
task :server do
  exec "unicorn #{Shellwords.join(ARGV[1..-1])}"
end

task :help do
  puts "Available tasks"
  exec "rake -T"
end

task :test do
  Dir.glob('./test/*_test.rb') { |f| require f }
end

task :default => :help
