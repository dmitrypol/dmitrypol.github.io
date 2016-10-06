---
title: "Redis data sharding"
date: 2016-10-05
categories: redis
---

One of the downdsides of Redis is that all data is stored in RAM.  So if you cannot scale up you need to scale out and shard your data.  

I first want to share one of my first experiences with sharding.  I was not directly invovled in the project but worked closely with the team.  The system was tracking phone calls so we sharded on the last integer of the number dialed.  This gave us very uniform 10 shards.  

In tihs case I am separating keys by hosts but you could just as easily specify different namespaces, ports or DB values.  Since my goal is scalability, I do not want to increase the size of my key by adding namespace to it.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS0 = Redis.new(host: 'host0', port: 6379, db: 0, driver: :hiredis)
REDIS1 = Redis.new(host: 'host1', port: 6379, db: 0, driver: :hiredis)
REDIS2 = Redis.new(host: 'host2', port: 6379, db: 0, driver: :hiredis)
REDIS3 = Redis.new(host: 'host3', port: 6379, db: 0, driver: :hiredis)
REDIS4 = Redis.new(host: 'host4', port: 6379, db: 0, driver: :hiredis)
REDIS5 = Redis.new(host: 'host5', port: 6379, db: 0, driver: :hiredis)
REDIS6 = Redis.new(host: 'host6', port: 6379, db: 0, driver: :hiredis)
REDIS7 = Redis.new(host: 'host7', port: 6379, db: 0, driver: :hiredis)
REDIS8 = Redis.new(host: 'host8', port: 6379, db: 0, driver: :hiredis)
REDIS9 = Redis.new(host: 'host9', port: 6379, db: 0, driver: :hiredis)
{% endhighlight %}

Imagine an API that recieves HTTP requests with 2 params `phone_from` and `phone_to`.  

{% highlight ruby %}
# app/controllers/phone_controller.rb
class PhoneController < ApplicationController
  def create
  	PhoneTracker.new(phone_from: params[:phone_from], phone_to: params[:phone_to]).perform
  end
end
# app/services/phone_tracker.rb
class PhoneTracker
	def initialize(phone_from:, phone_to:)
		@phone_from = phone_from
		@phone_to = phone_to
	end
	def perform
  		# => grab last digit of the phone number
  		last_nubmer = @phone_to.last
  		# => get the Redis connection to the right shard
  		redis = "REDIS#{last_nubmer}".constantize
  		# each value is a sorted set with the score being the number of calls from
  		redis.zincrby(@phone_to, 1, @phone_from)
	end
end
{% endhighlight %}


### Other sharding approaches

Alas, in many situations data does not fall into nice 10 buckets.  What is we are tracking [unique visitors](https://en.wikipedia.org/wiki/Unique_user#Unique_visitor) to our website using combination of IP and [user agent](https://en.wikipedia.org/wiki/User_agent)?  And we want to split into 4 shards?  

{% highlight ruby %}
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :visitor_check
private
  def visitor_check
    key = Digest::MurmurHash1.hexdigest "#{request.remote_ip}:#{request.user_agent}"
    REDIS_VISIT_COUNT.incr key
  end
end
{% endhighlight %}

We are using [murmurhash](https://github.com/ksss/digest-murmurhash)


### Reballancing data after adding / removing nodes





{% highlight ruby %}

{% endhighlight %}


http://redis.io/topics/partitioning
http://redis.io/topics/cluster-tutorial
http://instagram-engineering.tumblr.com/post/10853187575/sharding-ids-at-instagram
https://en.wikipedia.org/wiki/Shard_(database_architecture)
http://highscalability.com/blog/2014/9/8/how-twitter-uses-redis-to-scale-105tb-ram-39mm-qps-10000-ins.html
http://artemyankov.com/sharding-redis-is-easy/