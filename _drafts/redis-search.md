---
title: "Redis Search"
date: 2017-04-29
categories: redis
---

When I first started using Redis I loved the speed and the powerful data structures that fit my code like hand into a glove.  Over the years I used Redis for data analysis, caching, running background jobs and even permanent data storage.

The one feature I missed is built in support for searching records by other than the key.  Coming from strong SQL background it was very frustrating not be to able to do `select * from users where name = ...`.  

In this post I will discuss several options on how we can still search data in Redis.  To make things interesting let's build an applciation using Redis as the primary DB to store our records.  We wll use Ruby [ohm](https://github.com/soveran/ohm) library.  To keep things simple we will have only one model `User` with `name` and `email`.  

{% highlight ruby %}
class User < Ohm::Model
  attribute :name
  attribute :email
  index :name
  index :email  
end
{% endhighlight %}

When we create user records data in Redis will look like this:



{% highlight ruby %}

{% endhighlight %}




{% highlight ruby %}

{% endhighlight %}





http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index

http://josephndungu.com/tutorials/fast-autocomplete-search-terms-rails

http://www.rubygemsearch.com/ruby-gems/detail?id=redis-search

http://vladigleba.com/blog/2014/05/30/how-to-do-autocomplete-in-rails-using-redis/

http://redisearch.io/

https://github.com/huacnlee/redis-search

https://github.com/RedisLabsModules/secondary

https://redis.io/topics/indexes


{% highlight ruby %}

{% endhighlight %}
