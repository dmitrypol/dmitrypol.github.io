---
title: "Redis Search"
date: 2017-05-07
categories: redis
---

When I first started using Redis years ago I loved the speed and the powerful data structures that fit my code like hand into a glove.  Over time I used Redis for data analysis, caching, queueing background jobs and permanent data storage.

The one feature I missed is built in support for searching records by other than the key.  Coming from strong SQL background it was very frustrating not be to able to do `select * from users where name = ...`.  In this post I will discuss several options on how we can implement search in Redis.  

### Client library

As POC let's build an applciation using Redis as the primary DB to store our records.  We wll use Ruby [ohm](https://github.com/soveran/ohm) gem.  To keep things simple we will start with only one model `User` with `name` and `email` attributes.  

{% highlight ruby %}
class User < Ohm::Model
  attribute :name
  attribute :email
  index :name
  index :email  
end
{% endhighlight %}

When we create user records we will have a [Redis Hash](https://redis.io/topics/data-types#hashes) with User name and email attributes

{% highlight ruby %}
{"db":1,"key":"User:1","ttl":-1,"type":"hash","value":{"name":"john smith","email":"john.smith@gmail.com"},"size":39}
{% endhighlight %}

Separately the library will create [Redis Sets](https://redis.io/topics/data-types#sets) to enable us to search for user by name or email since we defined `index` for those fields above.  

{% highlight ruby %}
{"db":1,"key":"User:indices:name:john smith","ttl":-1,"type":"set","value":["1"],"size":1}
{"db":1,"key":"User:indices:email:john.smith@gmail.com","ttl":-1,"type":"set","value":["1"],"size":1}
{"db":1,"key":"User:1:_indices","ttl":-1,"type":"set","value":["User:indices:name:john smith","User:indices:email:john.smith@gmail.com"],"size":67}
{% endhighlight %}

Now we can query for users like this:

{% highlight ruby %}
@users = User.find(email: 'john.smith@gmail.com')
<Ohm::Set:0x00000003cc7f10 @model=User, @namespace="User", @key="User:indices:email:john.smith@gmail.com"> 
@users.to_a
[<User:0x00000003c94e80 @attributes={:name=>"john smith", :email=>"john.smith@gmail.com"}, @_memo={}, @id="1">] 
{% endhighlight %}

We can also do loop and dispaly `@users` in our UI.  

{% highlight ruby %}
<% @users.each do |user| %>
<%= user.id %>
<%= user.name %>
<%= user.email %>
<% end %>
{% endhighlight %}


Let's make things just a little bit more complicated and introduce `Article` model which belongs_to `User`.  



{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}





{"db":1,"key":"User:all","ttl":-1,"type":"set","value":["1"],"size":1}
{"db":1,"key":"User:id","ttl":-1,"type":"string","value":"1","size":1}




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
