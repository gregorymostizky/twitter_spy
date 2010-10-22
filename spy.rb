unless ARGV.size == 4
	puts "Usage: consumer_token consumer_secret access_token access_secret"
	exit
end

require 'twitterstream'
require 'couchrest'
require 'cgi'
require 'time'

#db = CouchRest.database!("http://127.0.0.1:5984/twilitr")
db_tags = CouchRest.database!("http://127.0.0.1:5984/hashtags")
db_links = CouchRest.database!("http://127.0.0.1:5984/links")


ts = TwitterStream.new({:consumer_token => ARGV[0],
	:consumer_secret => ARGV[1],
	:access_token => ARGV[2],
	:access_secret => ARGV[3]})

r_url = /((http|https):\/\/((\w|-|,)+(\.|\/)?)+)/

puts "Connected"

#ts.filter(:track => "#ruby,#rails,#kontera") do |status|
ts.sample do |status|
  user = status["user"]
  next unless user
  puts "#{user['screen_name']}: #{status['text']}"
  
  url = $1 if status['text'] =~ r_url
 
  # save to couch
  #db.save_doc(status.merge({"eurl" => url}))

  # save hashtags data if available
  tags = status['entities']['hashtags'].map { |h| h['text'] }
  tags.each do |h|
    next if h =~ /^_/  #dont process special tags that start with _
    hh = CGI.escape(h)

    # save each tag
    begin
      couch_doc = db_tags.get(hh)
    rescue RestClient::ResourceNotFound
      couch_doc = {}
    end

    couch_doc['tag'] = h
    couch_doc['seen_count'] = (couch_doc['seen_count'] or 0) + 1
    couch_doc['last_seen'] = Time.now

    couch_doc['related_tags'] ||= {}
    tags.each do |rh|
      next if rh == h
      couch_doc['related_tags'][rh] ||= 0
      couch_doc['related_tags'][rh] += 1
    end

    couch_doc['related_users'] ||= {}
    couch_doc['related_users'][user['screen_name']] ||= 0
    couch_doc['related_users'][user['screen_name']] += 1
    couch_doc['texts'] ||= []
    couch_doc['texts'] << status['text']
    db_tags.save_doc({'_id' => hh}.merge(couch_doc))
  end

  # save urls data if available 
  links = status['entities']['urls'].map { |u| u['url'] }
  links.each do |l|
    ll = CGI.escape(l)
    puts ll

    # save each link
    begin
      couch_doc = db_links.get(ll)
    rescue RestClient::ResourceNotFound
      couch_doc = {}
    end

    couch_doc['link'] = l
    couch_doc['seen_count'] = (couch_doc['seen_count'] or 0) + 1
    couch_doc['last_seen'] = Time.now
    couch_doc['related_tags'] ||= {}

    tags.each do |h|
      couch_doc['related_tags'][h] ||= 0
      couch_doc['related_tags'][h] += 1
    end
    
    couch_doc['related_users'] ||= {}
    couch_doc['related_users'][user['screen_name']] ||= 0
    couch_doc['related_users'][user['screen_name']] += 1

    couch_doc['texts'] ||= []
    couch_doc['texts'] << status['text']

    db_links.save_doc({'_id' => ll}.merge(couch_doc))


  end
  	
end


