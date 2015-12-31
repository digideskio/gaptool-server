# encoding: utf-8
Dir.chdir(File.dirname(__FILE__))

require 'shellwords'
require 'rspec/core/rake_task'
require_relative 'lib/helpers/redis'
require_relative 'lib/helpers/ec2'
require_relative 'lib/helpers/init'
require_relative 'lib/helpers/rehash'

DH = Gaptool::Data
EC2 = Gaptool::EC2
$stdout.sync = true

def sys(cmd)
  IO.popen(cmd) do |f|
    puts f.gets until f.eof?
  end
  $CHILD_STATUS.to_i
end

Dir.glob('tasks/*.rb').each { |r| load r }

unless File.exist?('/.dockerenv')
  desc 'Start the shell'
  task :shell do
    exec "racksh #{Shellwords.join(ARGV[1..-1])}"
  end
  task sh: :shell

  desc 'Start the HTTP server'
  task :server do
    exec "puma -p 3000 --preload -t 8:32 -w 3 #{Shellwords.join(ARGV[1..-1])}"
  end

  desc 'Bump the version'
  task :bump do
    version = File.read('VERSION').strip
    nver = version.next
    f = File.open('VERSION', 'w')
    f.write(nver)
    f.close
    puts "Bumped #{version} => #{nver}"
    exec "git commit -m 'Bump version to v#{nver}' VERSION"
    Rake::Task['tag'].invoke
    Rake::Task['gem:build'].invoke
  end

  desc 'Tag git with VERSION'
  task :tag do
    exec 'git tag v$(cat VERSION)'
  end

  desc 'Push the git tag and the gem version'
  task push: :tag do
    exec 'git push origin v$(cat VERSION)'
    Rake::Task['gem:push'].invoke
  end
end

task :help do
  puts 'Available tasks'
  exec 'rake -T'
end

RSpec::Core::RakeTask.new :test do |task|
  task.pattern = Dir['test/*_test.rb']
end

task default: :help
