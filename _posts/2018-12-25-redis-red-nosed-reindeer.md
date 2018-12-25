---
title: "Redis the Red-Nosed Reindeer"
date: 2018-12-25
categories: redis
---

During Christmas Santa delivers presents to children around the world.  To do this he supposedly "makes his list and checks it twice".  But what if Santa had better software tools to keep track of all the presents that need to be delivered to millions of homes?  

Since speed is essential to doing this in a limited amount of time could we use [Redis](https://redis.io) as the DB for this application?  And which Redis data structures / features should we use?

* TOC
{:toc}

## Hashes

Desipite the mentioning of Santa using "list" Redis Hashes can be a better data structure.  We will use the physical address as the Redis key and children / presents will be individual key / value pairs.  We will assume that each home has one or more children and each child receives only one present.  Here is a Python code sample:

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
address = '123 main st'
presents = {'child1': 'present1', 'child2': 'present2'}
r.hmset(address, presents)
{% endhighlight %}

## Geo

Santa needs to be efficient in finding the addresses to make deliveries to.  This is where Redis `geo` data types can help.  

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
address = '123 main st'
r.geoadd('addresses', -122.334371, 47.605024, address)
{% endhighlight %}

Then Santa can execute `r.georadiusbymember('addresses', address, 10, 'mi'))` to get the addresses within 10 miles of his current location.  

## Lists

Another way Santa can save time is to determine the optimum route ahead of time (the traveling salesman problem) and then load those addresses into a Redis List.  

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
address = '123 main st'
r.lpush('addresses_list', address)
{% endhighlight %}

Then Santa will do `r.rpop('addresses_list')` and use the address to lookup children / presents in the separate Hash.  This also removes homes that already received their presents from the inventory so Santa does not waste precious time visiting them again.  

Another use case for Lists is when Santa is supervising his elves to assemble all the presents.  He can use the same `lpush` command to queue a task.  Different worker elves can watch the queue and `rpop`.  Redis guarantees that only one worker elf will pick up each present assembly task.  

## Sorted Sets

Given the importance of making deliveries on time and different timezones we could use Sorted Sets to load addresses with the estimated delivery time as the score.  

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
address = '123 main st'
delivery_time = ...
r.zadd('addresses_zset', address, delivery_time)
{% endhighlight %}

This way Santa can use `r.zrange('addresses_zset', 0, 10, withscores = True)` to get the next 10 deliveries and the times they need to be done by.  The problem is that it will not allow Santa to take the optimum route like the Lists solution above. 

## Sets

It is important that not just all homes get their deliveries but that all children in each home receive their presents.  Otherwise it will be very sad holiday for some.  We can use Set to track all children and ensure their uniquness.  

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
child = ...
r.sadd('children', child)
{% endhighlight %}

The problem is that will get slower and slower to insert and lookup children as the numer of records increases.  So Sets might not be a good choice here.  

## Strings

We also want to track the address of each child (so we can "check it twice").  For that we can use multiple Strings.  

{% highlight python %}
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
child = ...
address = '123 main st'
r.set(child, address)
{% endhighlight %}

When we get the Hash for each home we can look up the child record and ensure it's mapped to the same address. 

## Streams and Pub/Sub

To communicate with his reindeer Santa can use Redis Streams with `xadd` and `xread` so that they all receive the message to stop or start.  Alternatively Pub/Sub is a great fire and forget mechanism but then some of the reindeer might not get the message if they are not paying attention.

## Performance

But how will this solution scale?  To store one million Redis hashes, geo records and other keys (depending on the design chosen) required between 200 and 300 MB RAM.  Since there are approximately 132 million households in the US that will require between 26 and 40 GB RAM which can be done on a high end laptop.  

Redis has been tested to do well over a million operations per second.  If we assume that Santa has only one day (86400 seconds) to make his deliveries this should give us enough time to lookup appropriate information.  Given that we are performing numerous multi-key operations we could use Lua scrits or pipelining to speed things up.  

So as long some of the elves can write decent quality code they should be able to load the computer onboard of Santa's sled with the appropriate data.  Given that network connections can still be slow at times it is best to have all the data locally.  
