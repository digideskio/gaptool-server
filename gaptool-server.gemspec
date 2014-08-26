# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "gaptool-server"
  s.version = "0.4.11"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Matt Bailey", "Francesco Laurita"]
  s.date = "2013-08-12"
  s.description = "gaptool-server for managing cloud resources"
  s.email = "m@mdb.io"
  s.executables = ["gaptool-server"]
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "LICENSE.txt",
    "Procfile",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/gaptool-server",
    "config.ru",
    "gaptool-server.gemspec",
    "lib/app.rb",
    "lib/helpers/gaptool-base.rb",
    "lib/helpers/init.rb",
    "lib/helpers/mongodb.rb",
    "lib/helpers/nicebytes.rb",
    "lib/helpers/partials.rb",
    "lib/helpers/redis.rb",
    "lib/helpers/rehash.rb",
    "lib/helpers/services.rb",
    "lib/models/init.rb",
    "lib/models/user.rb",
    "lib/public/css/common.css",
    "lib/public/js/manifest.txt",
    "lib/routes/init.rb",
    "lib/routes/main.rb",
    "lib/routes/mongodb.rb",
    "lib/routes/redis.rb",
    "lib/routes/rehash.rb",
    "lib/routes/services.rb",
    "lib/views/hosts.erb",
    "lib/views/init.erb",
    "setup.rb",
    "test/helper.rb",
    "test/test_gaptool-server.rb"
  ]
  s.homepage = "http://github.com/mattbailey/gaptool-server"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "2.0.5"
  s.summary = "gaptool-server for managing cloud resources"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sinatra>, [">= 0"])
      s.add_runtime_dependency(%q<thin>, ["~> 1.5.1"])
      s.add_runtime_dependency(%q<redis>, [">= 0"])
      s.add_runtime_dependency(%q<aws-sdk>, [">= 0"])
      s.add_runtime_dependency(%q<net-ssh>, [">= 0"])
      s.add_runtime_dependency(%q<peach>, [">= 0"])
      s.add_runtime_dependency(%q<bson_ext>, [">= 0"])
      s.add_runtime_dependency(%q<mongo>, [">= 0"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, [">= 0"])
      s.add_development_dependency(%q<bundler>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<simplecov>, [">= 0"])
      s.add_development_dependency(%q<shotgun>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
    else
      s.add_dependency(%q<sinatra>, [">= 0"])
      s.add_dependency(%q<thin>, ["~> 1.5.1"])
      s.add_dependency(%q<redis>, [">= 0"])
      s.add_dependency(%q<aws-sdk>, [">= 0"])
      s.add_dependency(%q<net-ssh>, [">= 0"])
      s.add_dependency(%q<peach>, [">= 0"])
      s.add_dependency(%q<bson_ext>, [">= 0"])
      s.add_dependency(%q<mongo>, [">= 0"])
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<rdoc>, [">= 0"])
      s.add_dependency(%q<bundler>, [">= 0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<simplecov>, [">= 0"])
      s.add_dependency(%q<shotgun>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
    end
  else
    s.add_dependency(%q<sinatra>, [">= 0"])
    s.add_dependency(%q<thin>, ["~> 1.5.1"])
    s.add_dependency(%q<redis>, [">= 0"])
    s.add_dependency(%q<aws-sdk>, [">= 0"])
    s.add_dependency(%q<net-ssh>, [">= 0"])
    s.add_dependency(%q<peach>, [">= 0"])
    s.add_dependency(%q<bson_ext>, [">= 0"])
    s.add_dependency(%q<mongo>, [">= 0"])
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<rdoc>, [">= 0"])
    s.add_dependency(%q<bundler>, [">= 0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<simplecov>, [">= 0"])
    s.add_dependency(%q<shotgun>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
  end
end

