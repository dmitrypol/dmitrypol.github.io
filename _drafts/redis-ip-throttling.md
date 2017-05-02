---
title: "Redis and IP Throttling"
date: 2017-04-01
categories: redis
---

Recently one of our websites was hit by a scraper.  We could see the requests in our logs as they were querying our site for different keywords.  Instead of adding a bunch of IPs to our firewalls we decided to implement more intelligent throttling.  

We chose [rack-attack](https://github.com/kickstarter/rack-attack) Ruby gem.  It leverages [Redis](https://redis.io/)  which we already were using for [caching]({% post_url 2017-03-27-redis-cache-pregen %}) and [background jobs]({% post_url 2017-03-16-sendgrid-webhooks-background-jobs %}).  

* TOC
{:toc}

### Basic configuration

[rack-attack](https://github.com/kickstarter/rack-attack) allows us to `limit` the number of requests our application will accept from the same IP in a given time `period`.  It then builds a Redis key based on `Time.now.to_i/:period}` and `request.ip`.  On the first request from a new IP it does Redis `INCR` operation (which will either create a key if it doesn't exist or increment it).  It also sets `TTL` equal to our time `period`.  Once the Redis key value exceeds our limit this will block the request at [rack](http://rack.github.io/) layer (which is more efficient).  Here is their [wiki page](https://github.com/kickstarter/rack-attack/wiki/Example-Configuration) with more details.  

Data in Redis will look like this (`4977978` is `Time.now.to_i/:period`):

{% highlight ruby %}
  {"db":0,"key":"...4977978...220.53.5.168","ttl":237,"type":"string","value":"10”}
{% endhighlight %}

This approach will keep out most scrapers but someone determined can easily figure out the thresholds.  It also varies whether we want to truly restrict someone from abusing our system or just limit the stress on the servers.  

### Advanced configuration

To keep out more malicious users we can implement [exponential backoff](https://github.com/kickstarter/rack-attack/wiki/Advanced-Configuration#exponential-backoff).  This will create multiple keys for each IP / time period (using more RAM).  

{% highlight ruby %}
throttle('req/ip/1', limit: 300, period: 5.minutes) do |req|
  req.ip
end
throttle('req/ip/2', :limit => 600, :period => 30.minutes) do |req|
  req.ip
end
{% endhighlight %}

There is a clever example on the wiki page showing us to how create multiple levels in the same loop.  

But what if we have lots of legitimate users behind the same IP?  rack-attack allows to add IPs to either [safelist or blocklist](https://github.com/kickstarter/rack-attack/wiki/Advanced-Configuration#blacklisting-from-railscache).  We could put IPs in config file but that would require a code deploy to change them.  Why not use Redis to store these IPs in separate keys?

{% highlight ruby %}
  {"db":0,"key":"safelist:102.232.240.209","ttl":602795,"type":"string",...}
  {"db":0,"key":"blocklist:45.0.186.198","ttl":504795,"type":"string",...}
{% endhighlight %}

To add/remove these records we built a simple GUI for our internal users.  We also set default TTL of 1 week so these IPs do not remain in the system permanently.  

### Customer specific configuration

IP throttling can be used for websites but it is also very common for APIs.  We may have multiple customers using our API and we want to control access for each one.  The configuration examples above apply to entire application so we need something more flexible.  

Let's assume that when request hits our servers the customer passes `customer_id` param.  Let's also assume that we have Free, Pro and Enterprise tiers with the following limits:
* Free tier - 100 requests per hour.
* Pro tier - 100 requests per minute and 5K requests per hour.
* Enterprise tier - 200 requests per minute and 10K requests per hour.

{% highlight ruby %}
class Customer
  extend Enumerize
  field :tier, type: String
  enumerize :tier, in: [:free, :pro, :enterprise]
end
{% endhighlight %}

We might not want to query our primary DB during the IP check so we will load data into Redis (`tier` is namespace and 123 and 456 are customer_ids).

{% highlight ruby %}
  {"db":0,"key":"tier:123","ttl":-1,"type":"string",value:"free"}
  {"db":0,"key":"tier:456","ttl":-1,"type":"string",value:"pro"}
end
{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


To have even more flexibility we can store unique configuration for each customer in Redis hashes.  
{% highlight ruby %}
  {"db":0,"key":"tier:789","ttl":-1,"type":"hash",value:"{60:100, 3600:1000, 86400:10000}"}
{% endhighlight %}

This will allow 100 requests per minute, 1K requests per hour and 10 requests per day.  Key is number of `period` (number of seconds) and value is `limit` (max requests).


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
