---
title: "Rails cache with variable TTL"
date: 2017-05-25
categories: redis
---

[Method level caching](http://guides.rubyonrails.org/caching_with_rails.html#low-level-caching) can be a useful tool to scale our applications.  When the underlying data changes we need to bust cache by creating new `cache_key`.  But the old cached content still remains in RAM ([Redis](https://redis.io/) or [Memcached](https://memcached.org/)) until it is purged with [TTL](https://redis.io/commands/ttl).  

We do not want to set TTL too long because it will waste RAM.  At the same time we do not want to set it too short because it will purge valid cache.  That cache will then need to be regenerated.  

We can start with simple application level configuration where we set default TTL of 1 hour.  

{% highlight ruby %}
# config/environments/production.rb
config.cache_store = :redis_store, {
  expires_in: 1.hour,
  namespace: 'cache',
  redis: { host: 'localhost', port: 6379, db: 0 },
  driver: :hiredis }
{% endhighlight %}

We then adjust it for different methods.  

{% highlight ruby %}
class User < ApplicationRecord
  def method1
    Rails.cache.fetch([cache_key, __method__], expires_in: 1.day) do
      # code here
    end
  end
  def method2
    Rails.cache.fetch([cache_key, __method__], expires_in: 10.minutes) do
      # code here
    end
  end
end
# data in Redis
{"db":0,"key":"cache:user/1-1495838092/method1","ttl":75210, "type":"string",...}
{"db":0,"key":"cache:user/1-1495838092/method2","ttl":478, "type":"string",...}
{% endhighlight %}

We are also customizing Redis cache key by appending method name to it.  This avoids cache_key collision in the same model.  

But sometimes data attributes change less frequently for different records of the same class.  How can we change our TTL depending on circumstances?  For example, users may be `active` or `inactive`.  When they are `active` their data changes often and we want shorter TTL.  When they become inactive the data is not updated and can be cached for longer.  

We can wrap this logic in a private method:

{% highlight ruby %}
class User < ApplicationRecord
  extend Enumerize
  enumerize :status, in: [:active, :inactive]
  def method1
    Rails.cache.fetch([cache_key, __method__], expires_in: get_ttl) do
    end
  end
private
  def get_ttl
    return 1.day if status == :inactive
    return 10.minutes if status == :active
    return 1.hour
  end  
end
{% endhighlight %}

This will allow us to make much better use of our Redis RAM for caching purposes.  

### Links
* Previous post on [cache busting]({% post_url 2016-11-18-rails-cache-bust %}).
* Previous post on [cache pre-generating]({% post_url 2017-03-27-redis-cache-pregen %}).
* [https://redis.io/topics/lru-cache](https://redis.io/topics/lru-cache)
* [http://antirez.com/news/109](http://antirez.com/news/109)
