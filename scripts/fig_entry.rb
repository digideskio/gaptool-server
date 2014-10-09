#!/usr/bin/env ruby

ENV.each do |k, v|
  newk = nil
  if k.include? '_ENV'
    newk = k.gsub(/.*_ENV_/, '')
  end
  if k.include? 'REDIS_1'
    newk = k.gsub(/REDIS_1/, "REDIS")
  end
  ENV[newk] = v if newk
end

unless ARGV.empty?
  exec *ARGV
end
