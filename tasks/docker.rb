def printimages
  puts `docker images | grep '^gild/gaptool'`
end

unless File.exist?('/.dockerenv')
  namespace :docker do
    namespace :build do
      task :image do
        sys(%w(./scripts/build_docker_images.sh -l))
        printimages
      end

      task all: [:image]
    end

    desc 'Build the docker image'
    task build: 'build:image'

    desc 'Push the release image to the Docker Hub'
    task push: 'push:release'

    task up: [:build, :recreate]

    desc 'Run tests w/ docker'
    task test: :build do
      sys(%w(docker-compose run --rm gaptool bundle exec rake test))
    end

    desc 'Stop docker containers'
    task :stop do
      sys(%w(docker-compose stop))
    end

    desc 'Start docker containers'
    task :start do
      sys(%w(docker-compose start))
    end

    desc 'Restart docker containers'
    task restart: [:stop, :start]

    desc "Stop and remove docker containers (alias 'rm')"
    task remove: :stop do
      sys(%w(docker-compose rm --force))
    end

    task rm: :remove

    desc 'Recreate docker containers without building'
    task :recreate do
      sys(%w(docker-compose up -d))
    end

    desc 'Run a command in the docker container'
    task :run do
      exit sys(%W(docker-compose run --rm gaptool #{ARGV[1..-1].shelljoin}))
    end
  end

  desc 'Bring up docker containers'
  task docker: 'docker:up'
end
