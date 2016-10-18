---
title: "Storing complex data structures in Redis"
date: 2016-10-16
categories: redis
---

We use various data structures (linked lists, arrays, hashes, etc) in our applications.  They are usually implemented in memory but what if we need persistence AND speed?  This is where in memory DB like [Redis](http://redis.io/) can be very useful.  

Redis has a number of powefull [data types](http://redis.io/topics/data-types-intro) but what if we need something more complex?  In this post I would like to go through commonly used data structures and see how they can be implemented using underlying Redis data types.  

One of the advantages of these approaches is that we can restart some of the application processes or even shutdown parts of the system for maintenance.  Data will be stored in Redis awaiting to be processed.

I will use examples in [Ruby on Rails](http://rubyonrails.org/).  First, let's create a Redis connection in initializer file.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
{% endhighlight %}


#### Linked lists

https://www.tutorialspoint.com/data_structures_algorithms/linked_list_algorithms.htm

[Redis Lists](http://redis.io/topics/data-types#lists)


#### Sets

http://redis.io/topics/data-types#sets


#### Hashes

Redis already has [hashes](http://redis.io/topics/data-types#hashes) built in.  Previously I wrote about using Redis hashes for [application-side joins]({% post_url 2016-10-11-redis-application-join %}).  

{% highlight ruby %}
# store data in Redis
users = User.some_scope.only(:first_name, :last_name, :email)
RedisHash.new.set(records: users)
#
class RedisHash
  def set(records:)
    records.each do |record|
      key = [record.class.name, record.id.to_s].join(':')
      data = record.attributes.except(:_id, :id)
      REDIS.mapped_hmset(key, data)
    end
  end
end
# data in Redis
{"db":0,"key":"gid://your-app-name/User/user_id1","ttl":-1,"type":"hash",
  "value":{"email":"user1@email.com","first_name":"first 1","last_name":"last 1"},...}
{"db":0,"key":"gid://your-app-name/User/user_id1","ttl":-1,"type":"hash",
  "value":{"email":"user2@email.com","first_name":"first 2","last_name":"last 2"}...}
...
{% endhighlight %}

Now when fetching records we need to go to Redis instead of using of querying main DB.  We use [OpenStruct](http://ruby-doc.org/stdlib-2.3.0/libdoc/ostruct/rdoc/OpenStruct.html) to return an object to access attributes using `user.email` vs. `user['email']`.  

{% highlight ruby %}
class RedisHash
  def get(record_id:, record_class:)
	  key = [record_class, record_id.to_s].join(':')
	  data = REDIS.hgetall(key)
	  return OpenStruct.new(data)
  end
end
# user has_many articles and article belongs_to user
Articles.each do |a|
  puts a.user #	query DB
  puts RedisHash.new.get(record_id: d.user_id, record_class: 'User') # fetch from Redis
end
{% endhighlight %}


#### Arrays

Let's imagine we have an array of email addresses `emails = ['email1', 'email2', '@email3']` that we need send messages to.  Since this process can take a long time it would be nice to persist the data.  We can persist our array as Redis Lists.

{% highlight ruby %}
# save the records
REDIS.lpush('array', emails)
# data in Redis
{"db":0,"key":"array","ttl":-1,"type":"list","value":["email3","email2","email1"]...}
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

Alternatively we can persist our array as Redis Sets.  Sets do not allow repeated members so that will ensure our email addresses are unique (which could be desirable or not).  There are a few different ways we can fetch needed records from Redis.  

We can use `REDIS.smembers('array')` which will return all records at once (but we might not want that).  We will then use `REDIS.srem(array, email)` (which is O(n) complexity) to remove records after sending each one.  But if our application crashes in the middle of sending we will still have unsent email addresses saved in Redis.  

We can use combination of `REDIS.srandmember('array', 10)` to fetch emails in batches of 10.  Then we loop through the batch, send the messages and `REDIS.srem(array, email)`.  `srandmember` is also O(n) complexity.  

We can use `REDIS.spop(array)` which will remove and return a random member with O(1) complexity but we will have to send emails one at a time.  Usually the performance impact of making an outbound request to send email is greater than Redis operations so I would lean away from using `spop`.  

{% highlight ruby %}
# save the records
REDIS.sadd('array', emails)
# data in Redis
{"db":0,"key":"array","ttl":-1,"type":"set","value":["email3","email1","email2"]...}
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


#### Ranges


#### Stacks and Queues

[Stacks](https://www.tutorialspoint.com/data_structures_algorithms/stack_algorithm.htm) and [Queues](https://www.tutorialspoint.com/data_structures_algorithms/dsa_queue.htm) can be implemented with Redis Lists.  Let's imagine an API endpoint that receives messages `http://localhost:3000/stack?my_param=foo`

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

To process messages we create another Ruby class.  It which can be run via daemon, [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) or even cron).

{% highlight ruby %}
class ProcessStack
  def perform
    while REDIS.llen('stack') > 0
      item = REDIS.lpop('stack')	#	grab first item
    end
  end
end
{% endhighlight %}

For Queues the design similar.  We can use `lpush` and `rpop` or swtich to `rpush` and `lpop`.  

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
      item = REDIS.lpop('queue') #	grab last item
    end
  end
end
{% endhighlight %}


#### Binary trees


#### Graphs

https://www.tutorialspoint.com/data_structures_algorithms/graph_data_structure.htm



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}


https://www.sitepoint.com/ruby-interview-questions-linked-lists-and-hash-tables/
