---
title: "Redis as primary DB"
date: 2016-09-24
categories: redis
---

Redis makes a great choice for secondary DB.  It can be used for [caching]({% post_url 2016-05-14-redis_rails_more %}), [temp data storage]({% post_url 2016-09-14-redis_tmp_data %}) or [backgroudn queue]({% post_url 2016-09-24-redis_microserv_deux %}).  But what if we were to build a system where Redis was THE primary database?  

As a POC let's look at building [Instagram clone](https://www.instagram.com/).  Instagram was using [Redis](http://instagram-engineering.tumblr.com/post/12202313862/storing-hundreds-of-millions-of-simple-key-value) but apparently they eventually switched to [Cassandra](https://www.quora.com/Why-did-Instagram-abandon-Redis-for-Cassandra).  But their primary DB was Posgres.  

Many ideas in this blog were inspired by [this article](http://redis.io/topics/twitter-clone) on buliding Twitter clone with Redis.  


### Data models:

Users

Images

Votes

Followers

Following


#### ORM

https://github.com/soveran/ohm

https://github.com/nateware/redis-objects


{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
