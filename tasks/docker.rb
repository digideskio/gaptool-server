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
    task :test => :build do
      sys(%w(fig run --rm gaptool rake test))
    end

    desc "Rehash instances"
    task :rehash => :build do
      sys(%w(fig run --rm gaptool rake rehash))
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

    desc "Run a command in the docker container"
    task :run do
      exit sys(%W(fig run --rm gaptool #{ARGV[1..-1].shelljoin}))
    end

    desc "Run a rake task inside the docker container"
    task :rake do
      exit sys(%W(fig run --rm gaptool rake #{ARGV[1..-1].shelljoin}))
    end
  end

  desc "Bring up docker containers"
  task :docker => 'docker:up'
end
