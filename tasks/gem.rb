unless File.exists?('/.dockerenv')
  namespace :gem do

    desc "Build the gem"
    task :build => :clean do
      sys(%w(gem build gaptool-server.gemspec))
    end

    desc "Clean built file"
    task :clean do
      Dir.glob("*.gem") do |f|
        puts " * #{f}"
        File.unlink(f)
      end
    end

    desc "Bump the version"
    task :bump do
      version = File.read('VERSION').strip
      nver = version.next
      f = File.open('VERSION', 'w')
      f.write(nver)
      f.close
      puts "Bumped #{version} => #{nver}"
      exec "git commit -m 'Bump version to v#{nver}' VERSION"
      Rake::Task["tag"].invoke
      Rake::Task["gem:build"].invoke
    end

    desc "Push"
    task :push => :build do
      version = File.read('VERSION').strip
      sys(%W(gem push gaptool-server-#{version}.gem))
    end
  end
end
