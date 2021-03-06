---
title: "Storing complex data structures in Redis"
date: 2017-06-21
categories: redis
---

We use various data structures (linked lists, arrays, hashes, etc) in our applications.  They are usually implemented in memory but sometimes we need persistence AND speed.  This is where in memory DB like [Redis](http://redis.io/) can be very useful.  

Redis has a number of powefull [data types](http://redis.io/topics/data-types-intro) but what if we need something more complex?  In this post I would like to go through commonly used data structures and see how they can be implemented using underlying Redis data types.  

One of the advantages of these approaches is that we can restart some of the application processes or even shutdown parts of the system for maintenance.  Data will be stored in Redis awaiting to be processed.

* TOC
{:toc}

I will use examples in [Ruby on Rails](http://rubyonrails.org/).  First, let's create a Redis connection in initializer.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
{% endhighlight %}

### Strings

Strings are stored as they are.  We can do basic GET and SET commands.  They will be stored in individual keys.  Alternatively they could be stored in Redis Lists with `lpush`.

### Hashes

Redis already has [hashes](http://redis.io/topics/data-types#hashes) built in.  Previously I wrote about using Redis hashes for [application-side joins]({% post_url 2016-10-22-redis-app-join-gem %}) and created [redis_app_join](https://rubygems.org/gems/redis_app_join) gem.

{% highlight ruby %}
include RedisAppJoin
# cache records
users = User.some_scope.only(:first_name, :last_name, :email)
cache_records(records: users)
# data in Redis
{"db":0,"key":"User/user_id1","ttl":-1,"type":"hash",
  "value":{"email":"user1@email.com","first_name":"...","last_name":"..."},...}
# fetch records
users = fetch_records(record_class: 'User', record_ids: [id1, id2, ...])
{% endhighlight %}

The gem uses `mapped_hmset` to store and `hget` to fetch data.  It also uses [OpenStruct](http://ruby-doc.org/stdlib-2.3.0/libdoc/ostruct/rdoc/OpenStruct.html) to return an object to access attributes using `user.email` vs. `user['email']`.  

### Arrays

What if we have an array of email addresses `emails = ['user1@email.com', 'user2@email.com', ...]` that we need send messages to.  Since this process can take a long time it would be nice to persist the data.  

#### Using Lists

We can persist our array in [Redis Lists](http://redis.io/topics/data-types#lists).

{% highlight ruby %}
# save the records
REDIS.lpush('array', emails)
# data in Redis
{"db":0,"key":"array","ttl":-1,"type":"list","value":
  ["user2@email.com","user1@email.com",...]...}
#
class EmailSender
  def perform
    # check if there are still records using LLEN
    while REDIS.llen('array') > 0
      #	fetch email addresses in batches of 10
      emails = REDIS.lrange('array', 0, 9)
      emails.each do |email|
        # send email code here
        REDIS.lrem('array', 1, email) # O(n) complexity
      end
     end
   end
end
{% endhighlight %}

#### Using Sets

Alternatively we can persist our array in [Redis Sets](http://redis.io/topics/data-types#sets).  Sets do not allow repeated members so that will ensure our email addresses are unique (which could be desirable or not).  There are a few different ways we can fetch needed records from Redis.  

We can use `REDIS.smembers('array')` which will return all records at once (but we might not want that).  We will then use `REDIS.srem(array, email)` (which is O(n) complexity) to remove records after sending each one.  But if our application crashes in the middle of sending we will still have unsent email addresses saved in Redis.  

We can use combination of `REDIS.srandmember('array', 10)` to fetch emails in batches of 10.  Then we loop through the batch, send the messages and `REDIS.srem(array, email)`.  `srandmember` is also O(n) complexity.  

And we can use `REDIS.spop(array)` which will remove and return a random member with O(1) complexity but we will have to send emails one at a time.  Usually the performance impact of making an outbound request to send email is greater than Redis operations so I would stay away from using `spop`.  To scale this code we can make 10 `spop` iterations, store those emails in temp array and call email service provider API passing those addresses.

{% highlight ruby %}
# save the records
REDIS.sadd('array', emails)
# data in Redis
{"db":0,"key":"array","ttl":-1,"type":"set","value":["email1","email2", ...]...}
#
class EmailSender
  def perform
    # check if there are still records using SCARD
    while REDIS.scard('array') > 0
      #	fetch and remove records using options above
      #	send email
    end
  end
end
{% endhighlight %}


### Stacks and Queues

[Stacks](https://www.tutorialspoint.com/data_structures_algorithms/stack_algorithm.htm) and [Queues](https://www.tutorialspoint.com/data_structures_algorithms/dsa_queue.htm) can also be implemented with Redis Lists.  Let's imagine an API endpoint that receives messages `http://localhost:3000/stack?my_param=foo`

{% highlight ruby %}
# config/routes.rb
resources :stack, only: [:index]
class StackController < ApplicationController
  def index
    REDIS.lpush('stack', params[:my_param])
    render nothing: true, status: 200
  end
end
# data in Redis
{"db":0,"key":"stack","ttl":-1,"type":"list","value":["foo2","foo1","foo"]...}
{% endhighlight %}

To process messages we create another Ruby class.  It can be run via [daemon](https://github.com/thuehlinger/daemons), [ActiveJob](http://guides.rubyonrails.org/active_job_basics.html) or even cron).

{% highlight ruby %}
class ProcessStack
  def perform
    while REDIS.llen('stack') > 0
      item = REDIS.lpop('stack') # grab first item
    end
  end
end
{% endhighlight %}

For Queues the design is similar.  We can use `lpush` and `rpop` or swtich to `rpush` and `lpop`.  

{% highlight ruby %}
# config/routes.rb
resources :queue, only: [:index]
#
class QueueController < ApplicationController
  def index
    REDIS.rpush('queu', params[:my_param])
    render nothing: true, status: 200
  end
end
#
class ProcessQueue
  def perform
    while REDIS.llen('queue') > 0
      item = REDIS.lpop('queue') # grab last item
    end
  end
end
{% endhighlight %}

`lpop`, `rpop`, `lpush` and `rpush` are all O(1) complexity operations.  

### Sets

Redis already has a [Set](http://redis.io/topics/data-types#sets) data type so this is pretty straightforward.  Here is an example with [Ruby Set](http://ruby-doc.org/stdlib-2.3.1/libdoc/set/rdoc/Set.html).  

{% highlight ruby %}
set1 = Set.new([1,2,3])
REDIS.sadd('set1_array', set1.to_a)
REDIS.sadd('set1', set1)
#
{"db":0,"key":"set1_array","ttl":-1,"type":"set","value":["1","2","3"],"size":3}
{"db":0,"key":"set1","ttl":-1,"type":"set","value":["#<Set:0x007faed429db70>"],"size":23}
{% endhighlight %}

val1 = REDIS.spop('set1')

We can see [here](http://redis.io/commands#set) how to do powerful operations with by adding/removing items from different Sets.  

In a future post I will go into other data structures such as Sorted Sets, Ranges, Trees and Graphs.  
