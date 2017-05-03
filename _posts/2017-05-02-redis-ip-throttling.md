---
title: "Redis and IP Throttling"
date: 2017-05-02
categories: redis
---

Recently one of our websites was hit by a scraper.  We could see the requests in our logs as they were querying our site for different keywords.  Instead of adding a bunch of IPs to our firewalls we decided to implement more intelligent throttling.  

We chose [rack-attack](https://github.com/kickstarter/rack-attack) Ruby gem.  It leverages [Redis](https://redis.io/)  which we already were using for [caching]({% post_url 2017-03-27-redis-cache-pregen %}) and [background jobs]({% post_url 2017-03-16-sendgrid-webhooks-background-jobs %}).  

* TOC
{:toc}

### Basic configuration

[rack-attack](https://github.com/kickstarter/rack-attack) allows us to `limit` the number of requests our application will accept from the same IP in a given time `period`.  It then builds a Redis key based on `Time.now.to_i/:period` and `request.ip`.  On each request it does Redis `INCR` operation (which will either create a key if it doesn't exist or increment it).  During creation it sets `TTL` equal to our time `period`.  

Once the Redis key value exceeds the limit it will block the request at [rack](http://rack.github.io/) middleware layer.  When the key expires access will be allowed again.  Here is the [wiki page](https://github.com/kickstarter/rack-attack/wiki/Example-Configuration) with more details.  Data in Redis will look like this (`4977978` is `Time.now.to_i/:period`)

{% highlight ruby %}
{"db":0,"key":"..4977978..220.53.5.168","ttl":237,"type":"string","value":"10”}
{% endhighlight %}

This approach will keep out most scrapers but someone determined can easily figure out the thresholds.  It also depends whether we want to truly restrict someone from abusing the system or just limit the stress on out servers.  

### Advanced configuration

To keep out more malicious users we can implement [exponential backoff](https://github.com/kickstarter/rack-attack/wiki/Advanced-Configuration#exponential-backoff).  This will create multiple keys for each IP and time period (using more Redis RAM).  There is a clever example on the wiki page showing us to how create multiple levels in the same loop.  

{% highlight ruby %}
throttle('req/ip/1', limit: 300, period: 5.minutes) do |req|
  req.ip
end
throttle('req/ip/2', limit: 600, period: 30.minutes) do |req|
  req.ip
end
{% endhighlight %}

But what if we have lots of legitimate users behind the same IP?  We can add IPs to [safelist or blocklist](https://github.com/kickstarter/rack-attack/wiki/Advanced-Configuration#blacklisting-from-railscache).  We could put IPs in config file but that would require a code deploy to change.  Why not use Redis to store these IPs in separate keys?

{% highlight ruby %}
{"db":0,"key":"safelist:102.232.240.209","ttl":602795,"type":"string",...}
{"db":0,"key":"blocklist:45.0.186.198","ttl":504795,"type":"string",...}
{% endhighlight %}

To add/remove these records we built a simple GUI so our internal users can respond quickly if needed.  We also set default TTL of 1 week so these IPs do not remain in the system permanently.  

### Customer specific configuration for APIs

IP throttling can be used for websites but it is also very common for APIs.  We may have multiple customers using our API and we want to control access for each one.  The configuration examples above apply to entire application so we need something more flexible.  

Let's assume that when request hits our servers the customer passes `customer_id` param.  Let's also assume that we have Free, Pro and Enterprise tiers with the following limits:

* Enterprise - 200 requests per minute and 10K requests per hour.
* Pro - 100 requests per minute and 5K requests per hour.
* Free - 100 requests per hour.

We do not want to query our primary DB during the IP check so we will store this data in Redis with the help of [redis-objects](https://github.com/nateware/redis-objects) gem.  

{% highlight ruby %}
class Customer
  field :tier
  extend Enumerize
  enumerize :tier, in: [:free, :pro, :enterprise]
  include Redis::Objects
  value :tier_redis
  before_save { self.tier_redis = self.tier }
end
{% endhighlight %}

We are storing `tier` in both primary DB and in Redis (with `before_save` callback) because we need to query customers by `tier`.  Data in Redis will look like this:

{% highlight ruby %}
{"db":0,"key":"customer:1:tier_redis","ttl":-1,"type":"string","value":"free"..}
{"db":0,"key":"customer:2:tier_redis","ttl":-1,"type":"string","value":"pro"..}
{% endhighlight %}

Now the `throttle` check can be modified:

{% highlight ruby %}
tier = REDIS.get("customer:#{req.params[:customer_id]}:tier_redis")
case tier
when 'enterprise'
  levels = [{limit: 200, period: 1.minute}, {limit: 10000, period: 1.hour}]
when 'pro'
  levels = [{limit: 100, period: 1.minute}, {limit: 5000, period: 1.hour}]
else  # default for free and unknown
  levels = [{limit: 100, period: 1.hour}]
end
levels.each do |level|
  throttle("req/ip#{level}", limit: level[:limit], period: level:[period]) do |req|
    req.ip
  end
end
{% endhighlight %}

To have even more flexibility we can store unique configuration for each customer in Redis hashes.

{% highlight ruby %}
class Customer
  include Redis::Objects
  hash_key :throttle_hash
end
# data in Redis
{"db":0,"key":"customer:3:throttle_hash","ttl":-1,"type":"hash",
  value: "{60:100, 3600:1000, 86400:10000}"}
{% endhighlight %}

This will allow 100 requests per minute, 1K requests per hour and 10 requests per day.  Key is `period` (number of seconds) and value is `limit` (max requests).  How we use the hash to configure `throttle`.

{% highlight ruby %}
if req.params[:customer_id].present?
  throttle_hash = REDIS.hget("customer:#{req.params[:customer_id]}:throttle_hash")
  throttle_hash.each do |key, value|
    throttle("req/ip#{key}", limit: value, period: key) do |req|
      req.ip
    end  
  end
end
{% endhighlight %}

### Links
* [http://stackoverflow.com/questions/34774086/how-do-i-rate-limit-page-requests-by-ip-address](* http://stackoverflow.com/questions/34774086/how-do-i-rate-limit-page-requests-by-ip-address)
* [https://github.com/dryruby/rack-throttle](https://github.com/dryruby/rack-throttle)
* [https://github.com/jeremy/rack-ratelimit](https://github.com/jeremy/rack-ratelimit)
* [http://nginx.org/en/docs/http/ngx_http_limit_req_module.html](http://nginx.org/en/docs/http/ngx_http_limit_req_module.html)
* [http://blog.lebrijo.com/rate-limiting-solution-for-a-rails-app/](http://blog.lebrijo.com/rate-limiting-solution-for-a-rails-app/)
* [https://blog.codinghorror.com/dictionary-attacks-101/](https://blog.codinghorror.com/dictionary-attacks-101/)
* [https://devcentral.f5.com/articles/implementing-the-exponential-backoff-algorithm-to-thwart-dictionary-attacks](https://devcentral.f5.com/articles/implementing-the-exponential-backoff-algorithm-to-thwart-dictionary-attacks)



{% highlight ruby %}

{% endhighlight %}
