---
title: "Redis and Rube Goldberg machines"
date: 2018-04-03
categories: redis
---

Ruby Goldberg machines are deliberately complex contraptions that require the designer to perform a series of excessively convoluted steps to accomplish a very simple task (turn on a light switch).  In my career I worked on some applications that also were a little too complex.  

For "fun" exercise we will build a system using Redis performing a simple task such as writing something to a log file.  Except to make it more interesting we will push data through multiple Redis data structures.  

* TOC
{:toc}

If we did not need to push data through Redis we would have a simple class in our Ruby on Rails application that wrote to a log file.  

{% highlight ruby %}
class RedisRubeGoldberg
  def perform input
    # some code here
    Rails.logger.info input
  end
end
{% endhighlight %}

To make out code work with Redis we will modify it like this.  We will create a `@uuid` which will be used as various Redis keys.  Then we will call methods such as `string` and `list` to read/write data from different Redis data structures.  At the end we will grab data from the last data structure (in this case `sorted_set`) and actually write it to a log file.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new host: 'localhost', ...
class RedisRubeGoldberg
  def initialize
    @uuid = SecureRandom.uuid
  end
  def perform input
    string input
    list
    hash
    set
    sorted_set
    output
  end
private
  def string input
    ...
  end
  ...
end
{% endhighlight %}

### String

Here we use a basic `set` command to write data to a key `@uuid` with value of `input`.  We have to pass `input` to the method but in the future methods we will get it from Redis.  We are also logging method name so we can verify our program execution through all the steps.  

{% highlight ruby %}
def string input
  Rails.logger.info __method__
  REDIS.set @uuid, input
end
{% endhighlight %}

### List

We use `get` operation to read the data from Redis String.  Then we remove the `@uuid` key otherwise we will not be able to create a new record with the same key.  And finally we do `lpush` to insert data into a Redis List.  

{% highlight ruby %}
def list
  Rails.logger.info __method__
  data = REDIS.get @uuid
  REDIS.del @uuid
  REDIS.lpush @uuid, data
end
{% endhighlight %}

### Hash

We are following similar pattern of getting data out of Redis only now we are using `rpop` command.  Once the last item is removed from Redis List that key will be deleted so we do not need to call `REDIS.del` but there is no harm in doing it.  Then we insert it into Hash specifying 'data' string as the field and **data** variable as the value.  

{% highlight ruby %}
def hash
  Rails.logger.info __method__
  data = REDIS.rpop @uuid
  REDIS.del @uuid
  REDIS.hset @uuid, 'data', data
end
{% endhighlight %}

### Set

We extract data from Redis Hash using `hget`, delete the key and add the same data to Set with `sadd` command.  

{% highlight ruby %}
def set
  Rails.logger.info __method__
  data = REDIS.hget @uuid, 'data'
  REDIS.del @uuid
  REDIS.sadd @uuid, data
end
{% endhighlight %}

### Sorted Set

Since we know that our Redis Set has only one member we can call `.first` on the results of `smembers` command.  We use `zadd` command and specify epoch time as the member score.  

{% highlight ruby %}
def sorted_set
  Rails.logger.info __method__
  data = REDIS.smembers(@uuid).first
  REDIS.del @uuid
  REDIS.zadd @uuid, Time.now.to_i, data
end
{% endhighlight %}

And we modify the main `perform` method to get data out of Redis with `zrange` command.  

{% highlight ruby %}
def output
  Rails.logger.info __method__
  data = REDIS.zrange(@uuid, 0, -1).first
  REDIS.del @uuid
  Rails.logger.info data
end
{% endhighlight %}

Obviously this is a crazy exercise but it does illustrate a point of how can we store different data in Redis.  

### Links
* https://en.wikipedia.org/wiki/Rube_Goldberg_machine
* https://www.rubegoldberg.com
* https://redis.io
