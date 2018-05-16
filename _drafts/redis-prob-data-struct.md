---
title: "Redis and probabilistic data structures"
date: 2018-05-14
categories: redis
---

One of the first projects I did with Redis many years ago was using it to track monthly unique visitors.  We did it by hashing IP and UserAgent and using Redis TTL to purge records at the end of the month.

* TOC
{:toc}

### Separate keys  

It required a separate key to store each unique visitor.  Here is some basic code:

{% highlight ruby %}
ttl = Time.end_of_month
unique_visitor = Digest::SHA1.hexdigest("#{ip}-#{user_agent}")
if REDIS_CLIENT.get unique_visitor
  # returning visitor
else
  REDIS_CLIENT.setex unique_visitor, ttl, ''
  # 1st time visitor
end
{% endhighlight %}

The downside is the more visitors came to our site the more RAM we needed in Redis to store all those keys.  I did a quick test and it took roughly 100MB of RAM to store 1 million keys.  

### HyperLogLog

With scale memory usage can become a concern.  Can we sacrifice a little bit of accuracy to save a lot of RAM and $?  This is where probabilistic data structure like HyperLogLog can help.  

{% highlight ruby %}
unique_visitor = Digest::SHA1.hexdigest("#{ip}-#{user_agent}")
before = REDIS_CLIENT.pfcount 'unique_visitors_hll'
REDIS_CLIENT.pfadd 'unique_visitors_hll', unique_visitor
after = REDIS_CLIENT.pfcount 'unique_visitors_hll'
if before == after
  # returning visitor
else
  # new visitor
end
{% endhighlight %}

We count the size of our HyperLogLog, add the new element (hash of IP & UserAgent) and count again.  If the count has not changed that likely means we already seen this element before.  We also need a process to delete the HyperLogLog key monthly via `REDIS_CLIENT.del 'unique_visitors_hll'` or by using Redis TTL.  The upside is now storing similar 1 million IP & UA hashes only takes about 1 MB of RAM.

### Bloom Filter

Using HyperLogLog to do this uniqueness check is not very clean and we have to make multiple calls to Redis.  The best data structure is a Bloom Filter.  

Redis 4 which was released in 2017 introduced support for modules that allow us to extend Redis functionality.  One interesting module is *rebloom* which adds Bloom Filter datatype to Redis.  To install the module we need to clone the repo `https://github.com/RedisLabsModules/rebloom` and run `make`.  Then we modify `redis.conf` to have `loadmodule /path/to/rebloom/rebloom.so`

Now we can use the new `BF.ADD` command.  It will return `1` if it's absolutely sure that this is a new visitor and `0` if it might be a returning visitor.  It is possible to get a false positive but not false negative.  

{% highlight ruby %}
unique_visitor = Digest::SHA1.hexdigest("#{ip}-#{user_agent}")
if REDIS_CLIENT.call('BF.ADD', 'unique_visitors_bf', unique_visitor) == 1
  # new visitor
else
  # might be returning visitor
end
{% endhighlight %}

### Links

* https://github.com/RedisLabsModules/rebloom
* https://en.wikipedia.org/wiki/Category:Probabilistic_data_structures
* https://en.wikipedia.org/wiki/Skip_list
* https://dzone.com/articles/introduction-probabilistic-0
* http://stackoverflow.com/questions/27307169/what-are-probabilistic-data-structures
* https://highlyscalable.wordpress.com/2012/05/01/probabilistic-structures-web-analytics-data-mining/
* https://dzone.com/articles/hyperloglogs-in-redis

bf = "unique_request_bf:#{Time.now.strftime("%Y.%m.%d.%H")}"
hll = "unique_request_hll:#{Time.now.strftime("%Y.%m.%d.%H")}"
