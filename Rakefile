# encoding: utf-8
Dir.chdir(File.dirname(__FILE__))
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_group 'helpers', 'lib/helpers'
    add_group 'routes', 'lib/routes'
    add_group 'app', 'lib/app'
  end
end

require 'rspec/core/rake_task'
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

unless File.exists?('/.dockerenv')
  namespace :docker do
    namespace :build do
      task :image do
        sys(%w(./scripts/build_docker_images.sh))
        printimages
      end

      desc "Build the release image"
      task :release do
        sys(%w(./scripts/build_docker_images.sh -t release))
        printimages
      end

      task :all => [:image]
    end

    namespace :push do
      task :release do
        sys(%w(docker push gild/gaptool:release))
      end

      desc 'Push all tags to the Docker Hub'
      task :all do
        sys(%w(docker push gild/gaptool))
      end
    end

    desc 'Build the docker image'
    task :build => 'build:image'

    desc "Push the release image to the Docker Hub"
    task :push => 'push:release'

    task :up => [:build, :recreate]

    desc "Run tests w/ docker"
    task :test => :up do
      sys(%w(fig run --rm gaptool rake test))
    end

    desc "Stop docker containers"
    task :stop do
      sys(%w(fig stop))
    end

    desc "Start docker containers"
    task :start do
      sys(%w(fig start))
    end

    desc "Restart docker containers"
    task :restart => [:stop, :start]

    desc "Stop and remove docker containers (alias 'rm')"
    task :remove => :stop do
      sys(%w(fig rm --force))
    end

    task :rm => :remove

    desc "Recreate docker containers without building"
    task :recreate do
      sys(%w(fig up -d))
    end
  end
  desc "Bring up docker containers"
  task :docker => 'docker:up'
end

namespace :user do
  desc "Add a new user. rake user:create <username>"
  task :create, [:username] do |t, args|
    puts DH.useradd(args[:username])[:key]
  end

  desc "Rename a user. rake user:rename <oldname> <newname>"
  task :rename, [:oldname, :newname] do |t, args|
    user = DH.user(args[:oldname])
    abort("Unknown user #{args[:oldname]}") if user.nil?
    DH.userdel(user[:username])
    DH.useradd(args[:newname], user[:key])
    puts "User #{args[:oldname]} renamed to #{args[:newname]}"
  end

  desc "Delete a user. rake user:delete <username>"
  task :delete, [:username] do |t, args|
    DH.userdel(args[:username])
  end

  desc "Set user key. rake user:setkey <username> <key>"
  task :setkey, [:username, :key] do |t, args|
    user = DH.user(args[:username])
    abort("Unknown user #{args[:username]}") if user.nil?
    puts DH.useradd(args[:username], args[:key])
  end
end

desc "List users"
task :user do
  puts DH.users.keys.join(" ")
end

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

RSpec::Core::RakeTask.new :test do |task|
  task.pattern = Dir['test/*_test.rb']
end

task :default => :help
