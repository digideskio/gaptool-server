unless File.exist?('/.dockerenv')
  namespace :gem do
    desc 'Build the gem'
    task build: :clean do
      sys(%w(gem build gaptool-server.gemspec))
    end

    desc 'Clean built file'
    task :clean do
      Dir.glob('*.gem') do |f|
        puts " * #{f}"
        File.unlink(f)
      end
    end

    desc 'Push'
    task push: :build do
      version = File.read('VERSION').strip
      sys(%W(gem push gaptool-server-#{version}.gem))
    end
  end
end
