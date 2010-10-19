unless ARGV.size == 4
	puts "Usage: consumer_token consumer_secret access_token access_secret"
	exit
end

require 'twitterstream'

ts = TwitterStream.new({:consumer_token => ARGV[0],
	:consumer_secret => ARGV[1],
	:access_token => ARGV[2],
	:access_secret => ARGV[3]})

ts.sample do |status|
	user = status["user"]
	next unless user
	puts "#{user['screen_name']}: #{status['text']}"
end


