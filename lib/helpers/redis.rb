require 'redis'

# docker links support
unless ENV['REDIS_PORT_6379_TCP_ADDR'].nil?
  ENV['REDIS_HOST'] = ENV['REDIS_PORT_6379_TCP_ADDR']
  ENV['REDIS_PORT'] = ENV['REDIS_PORT_6379_TCP_PORT']
  ENV.delete('REDIS_PASS')
end

ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']
ENV['REDIS_DB'] = '0' unless ENV['REDIS_DB']

$redis = Redis.new(:host => ENV['REDIS_HOST'],
                   :port => ENV['REDIS_PORT'].to_i,
                   :password => ENV['REDIS_PASS'],
                   :db => ENV['REDIS_DB'].to_i)

