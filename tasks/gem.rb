namespace :gem do

  desc "Build the gem"
  task :build => :clean do
    sys(%w(gem build gaptool-server.gemspec))
  end

  desc "Clean built file"
  task :clean do
    sys(%w(rm -vf *.gem))
  end

  desc "Bump the version"
  task :bump do
    version = File.read('VERSION').strip
    nver = version.next
    f = File.open('VERSION', 'w')
    f.write(nver)
    f.close
    puts "Bumped #{version} => #{nver}"
  end

  desc "Push"
  task :push => :build do
    sys(%w(gem push gaptool-server*.gem))
  end
end
