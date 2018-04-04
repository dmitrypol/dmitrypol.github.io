---
title: "Redis Streams and Consumer Groups"
date: 2018-04-03
categories: redis
---

In previous [post]({% post_url 2018-01-16-elasticsearch-redis-streams %}) we discussed Streams as a new data structure in Redis.  It is still not officially released but in the last few months there was an addition of Consumer Groups feature.  

* TOC
{:toc}

### Streams

To run Redis Streams we need to clone Redis Github repo unstable branch and execute `make`.  Please do NOT try this in production.  Now we can launch `redis-cli` and use the new Streams commands (they all begin with X).  Our app is a Ruby on Rails website for a nationwide retail store.  We are tracking what users are searching for and which zipcode they are coming from.  

{% highlight ruby %}
127.0.0.1:6379> xadd search_log:2018-04-03 * zip 98115 product tea
1522782152965-0
127.0.0.1:6379> xadd search_log:2018-04-03 * zip 98111 product coffee
1522782159781-0
{% endhighlight %}

We can get data using `xrange`, `xread` and `xlen`

{% highlight ruby %}
127.0.0.1:6379> xrange search_log:2018-04-03 - +
1) 1) 1522782152965-0
   2) 1) "zip"
      2) "98115"
      3) "product"
      4) "tea"
2) 1) 1522782159781-0
   2) 1) "zip"
      2) "98111"
      3) "product"
      4) "coffee"
127.0.0.1:6379> xread block 5000 streams search_log:2018-04-03 $
1) 1) "search_log:2018-04-03"
   2) 1) 1) 1522782159781-0
         2) 1) "zip"
            2) "98111"
            3) "product"
            4) "coffee"
127.0.0.1:6379> xlen search_log:2018-04-03
(integer) 2
{% endhighlight %}

To do the same from our application we will write this code

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_CLIENT = Redis.new host: 'localhost', ...
# app/services/
class StreamProducer
  def perform
    ...
    key = "search_log:#{Time.now.strftime("%Y-%m-%d")}"    
    REDIS_CLIENT.xadd(key, '*', 'zip', '98115', 'product', 'tea')
  end
end
{% endhighlight %}

And build a background process to consume this data.  

{% highlight ruby %}
class StreamConsumer
  def perform
    while true
      key = "search_log:#{Time.now.strftime("%Y-%m-%d")}"
      data = REDIS_CLIENT.xread('BLOCK', 5000, 'STREAMS', key, '$')
      ...
    end
  end
end
{% endhighlight %}

### Consumer Groups

Since our application will be running on multiple servers we will have multiple producers and multiple consumers even if we only have one `search_log:YYYY-MM-DD` stream.  Consumer Groups allow multiple clients to subscribe to stream and Redis will decide which messages go where.  This way we can easily add/remove consumers.  Items in the stream are NOT sharded which would require a fixed number of consumers.  


{% highlight ruby %}
xgroup create search_log:2018-04-03 group1 $
{% endhighlight %}




### Links
* https://github.com/antirez/redis
* http://antirez.com/news/114
* http://antirez.com/news/116
* https://gist.github.com/antirez/68e67f3251d10f026861be2d0fe0d2f4
* https://gist.github.com/antirez/4e7049ce4fce4aa61bf0cfbc3672e64d
