#!/usr/bin/ruby 
#
ENV.each do |k, v|
  if k.include? '_ENV'
    newk = k.gsub(/.*_ENV_/, '')
    ENV[newk] = v
  end
end

exec *ARGV
