Gem::Specification.new do |s|
  s.name = "gaptool-server"
  s.version = File.read('VERSION').strip

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matt Bailey", "Francesco Laurita", "Giacomo Bagnoli"]
  s.date = Time.new.strftime("%Y-%m-%d")
  s.description = "gaptool-server for managing cloud resources"
  s.email = "ops@gild.com"
  s.executables = Dir['bin/*'].map {|x| x.sub(/^bin\//, "")}
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc",
    "VERSION"
  ]
  s.files = Dir['lib/*'] + Dir['tasks/*'] + Dir['test/*']
  s.files.concat ['config.ru', 'Rakefile', 'Gemfile']
  s.homepage = "http://github.com/gild/gaptool-server"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.summary = "gaptool-server for managing cloud resources"
  s.required_ruby_version = '~> 2.1'

  s.add_runtime_dependency 'sinatra', "~> 1.4"
  s.add_runtime_dependency 'sinatra-contrib', "~> 1.4"
  s.add_runtime_dependency 'puma', "~> 2.11", '>= 2.11.1'
  s.add_runtime_dependency 'redis', "~> 3.1"
  s.add_runtime_dependency 'aws-sdk', "~> 1.54"
  s.add_runtime_dependency 'net-ssh', "~> 2.9"
  s.add_runtime_dependency 'peach', "~> 0.5"
  s.add_runtime_dependency 'airbrake', "~> 4.2"
  s.add_runtime_dependency 'racksh', "~> 1.0"
  s.add_runtime_dependency 'pry', "~> 0.10"
  s.add_runtime_dependency 'redis-namespace', '~> 1.5'
  s.add_runtime_dependency 'json', '~> 1.8'
  s.add_runtime_dependency 'rake', '~> 10'

  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'rspec-mocks', '~> 3.1'
  s.add_development_dependency 'fakeredis', '~> 0.5'
  s.add_development_dependency 'simplecov', '~> 0.9'
end
