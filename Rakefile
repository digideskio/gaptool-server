# encoding: utf-8
Dir.chdir(File.dirname(__FILE__))

require 'shellwords'
require 'rspec/core/rake_task'
require_relative 'lib/helpers/redis'
require_relative 'lib/helpers/init'
require_relative 'lib/helpers/rehash'

DH = Gaptool::Data
$stdout.sync = true

def sys(cmd)
  IO.popen(cmd) do |f|
    until f.eof?
      puts f.gets
    end
  end
  $?.to_i
end

Dir.glob('tasks/*.rb').each { |r| load r}

unless File.exists?('/.dockerenv')
  desc "Start the shell"
  task :shell do
    exec "racksh #{Shellwords.join(ARGV[1..-1])}"
  end
  task :sh => :shell

  desc "Start the HTTP server"
  task :server do
    exec "unicorn #{Shellwords.join(ARGV[1..-1])}"
  end

  desc "Tag git with VERSION"
  task :tag do
    exec "git tag v$(cat VERSION)"
  end
end

task :help do
  puts "Available tasks"
  exec "rake -T"
end

RSpec::Core::RakeTask.new :test do |task|
  task.pattern = Dir['test/*_test.rb']
end

task :default => :help
