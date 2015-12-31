#!/usr/bin/env ruby

ENV.each do |k, v|
  newk = nil
  newk = k.gsub(/.*_ENV_/, '') if k.include? '_ENV'
  newk = k.gsub(/REDIS_1/, 'REDIS') if k.include? 'REDIS_1'
  ENV[newk] = v if newk
end

exec(*ARGV) unless ARGV.empty?
