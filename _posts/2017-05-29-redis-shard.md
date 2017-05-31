---
title: "Redis data sharding"
date: 2017-05-29
categories: redis
---

One of the limitations of Redis is that all data is stored in RAM.  If we cannot scale up we need to scale out and [shard](https://en.wikipedia.org/wiki/Shard_(database_architecture)) our data.  

* TOC
{:toc}

### Simple algorithm

I want to share one of my first experiences with Redis sharding.  I was not directly invovled in the project but worked closely with the team.  The system was tracking phone calls so we sharded on the last integer of the number dialed.  This gave us very uniform 10 shards.  

In this case we are separating keys by hosts but we could just as easily specify different namespaces, ports or DB values.  Since our goal is scalability, we do not want to increase the size of our keys (and consume more RAM) by adding namespace to it.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS0 = Redis.new(host: 'host0', port: 6379, db: 0, driver: :hiredis)
REDIS1 = Redis.new(host: 'host1', port: 6379, db: 0, driver: :hiredis)
...
REDIS9 = Redis.new(host: 'host9', port: 6379, db: 0, driver: :hiredis)
{% endhighlight %}

Here we have an API that recevies HTTP requests with 2 params `phone_from` and `phone_to`:

{% highlight ruby %}
# app/controllers/phone_controller.rb
class PhoneController < ApplicationController
  def create
    PhoneTracker.new(phone_from: params[:phone_from],
      phone_to: params[:phone_to]).perform
  end
end
# app/services/phone_tracker.rb
class PhoneTracker
  def initialize(phone_from:, phone_to:)
    @phone_from = phone_from
    @phone_to = phone_to
  end
  def perform
    # grab the last digit of the phone number
    shard_number = @phone_to.last
    # get the Redis connection to the right shard
    redis = "REDIS#{shard_number}".constantize
    # each value is a sorted set with the score being the number of calls from
    redis.zincrby(@phone_to, 1, @phone_from)
  end
end
{% endhighlight %}

### More complex example

Alas, in many situations we do not have a number that we can split into 10 buckets.  What if we are tracking [unique visitors](https://en.wikipedia.org/wiki/Unique_user#Unique_visitor) to our website using combination of IP and [user agent](https://en.wikipedia.org/wiki/User_agent)?  Here is a [preivous post]({% post_url 2017-05-28-redis-etl %}) where I used [murmurhash](https://github.com/ksss/digest-murmurhash).  To split data into 4 shards we simply `% 4` to get the right Redis connection.  

{% highlight ruby %}
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :visitor_check
private
  def visitor_check
    key = Digest::MurmurHash1.rawdigest("#{request.remote_ip}:#{request.user_agent}")
    shard_number = key % 4
    redis = "REDIS#{shard_number}".constantize
    redis.incr(key)
  end
end
# data in Redis
{"db":0,"key":"1556211668","ttl":-1,"type":"string","value":"5","size":1}
{% endhighlight %}

### Rebalancing data after adding / removing nodes

What if later we need to add more Redis servers (going from 4 to 6)?  We can change our code to `% 6` but we also need to move some of the records from the current 4 Redis servers to the new ones?  Full confession - I have not implemented this in real production system, these are just general thoughts.  

{% highlight ruby %}
class RedisReshard
  def perform
    [1..4].each do |shard|
      redis = "REDIS#{shard}".constantize
      # this will grab ALL keys which is NOT what we want to do in real life
      keys = redis.keys("*")
      keys.each do |key|
        # check if key needs to be moved to new shard
        new_shard = key % 6
        if shard != new_shard
          new_redis = "REDIS#{new_shard}".constantize
          value = redis.get(key)
          # check if data is present in the new shard already
          new_value = new_redis.get(key)
          new_redis.set(key, value + new_value)
          # remove data from the old shard
          redis.del(key)
        end
      end
    end
  end
end
{% endhighlight %}

The challenge is to run this on a real production system while data is actively used.  Can't say I am looking forward to trying this for real if I ever have to ;-).  Read the links below for better ideas on paritioning and clustering.  

### Links

* [http://redis.io/topics/partitioning](http://redis.io/topics/partitioning)
* [http://redis.io/topics/cluster-tutorial](http://redis.io/topics/cluster-tutorial)
* [http://instagram-engineering.tumblr.com/post/10853187575/sharding-ids-at-instagram](http://instagram-engineering.tumblr.com/post/10853187575/sharding-ids-at-instagram)
* [http://highscalability.com/blog/2014/9/8/how-twitter-uses-redis-to-scale-105tb-ram-39mm-qps-10000-ins.html](http://highscalability.com/blog/2014/9/8/how-twitter-uses-redis-to-scale-105tb-ram-39mm-qps-10000-ins.html)
* [http://artemyankov.com/sharding-redis-is-easy/](http://artemyankov.com/sharding-redis-is-easy/)
