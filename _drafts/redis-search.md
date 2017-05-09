---
title: "Redis Search"
date: 2017-05-08
categories: redis
---

When I first started using [Redis](https://redis.io/) I loved the speed and the powerful data structures.  Over the years I used Redis for data analysis, caching, queuing background jobs and permanent data storage.

The one feature I missed is built in support for searching records by value (not key).  Coming from strong SQL background it was frustrating to be unable to do equivalent of `select first_name, last_name from users where email = ...`.  In this post I will discuss several options on how we can implement search in Redis.  

* TOC
{:toc}

### Client library

As POC let's build an application using Redis as the primary DB to store our records.  We will use Ruby [Ohm](https://github.com/soveran/ohm) gem.  To keep things simple we will start with only one model `User` with `name` and `email` attributes.  

#### Users

{% highlight ruby %}
class User < Ohm::Model
  attribute :name
  attribute :email
  index :name
  index :email  
end
{% endhighlight %}

When we create user records we will have a [Redis Hash](https://redis.io/topics/data-types#hashes) with User name and email.

{% highlight ruby %}
{"db":1,"key":"User:1","ttl":-1,"type":"hash","value":
  {"name":"john smith","email":"john.smith@gmail.com"},"size":39}
{% endhighlight %}

Separately the Ohm library will create several [Redis Sets](https://redis.io/topics/data-types#sets).  It will create a Set with key `User:all` and list of IDs for all users in the system.  This way we can find User by ID.

{% highlight ruby %}
{"db":1,"key":"User:all","ttl":-1,"type":"set","value":["1"],"size":2}
# in rails c
User[1]
<User:0x00000005e4ef80 @attributes={:name=>"John Smith",
  :email=>"john.smith@gmail.com"}, @memo={}, @id=1>
{% endhighlight %}

Separately there will be Sets with keys prefixed with `User:indices` and based on attributes (`email:..` and `name:...`).  Set values are IDs of records that match the criteria (in this case only `[1]`).  This enables search for user by name or email since we defined `index` for those fields.

{% highlight ruby %}
{"db":1,"key":"User:indices:name:john smith","ttl":-1,"type":"set","value":["1"]..}
{"db":1,"key":"User:indices:email:john.smith@gmail.com","ttl":-1,"type":"set","value":["1"]..}
{% endhighlight %}

And it will create a Set for each record with the list of indexes that this record matches.

{% highlight ruby %}
{"db":1,"key":"User:1:indices","ttl":-1,"type":"set","value":
  ["User:indices:name:john smith","User:indices:email:john.smith@gmail.com"]..}
{% endhighlight %}

To search for users by their attributes we can do this:

{% highlight ruby %}
@users = User.find(email: 'john.smith@gmail.com')
<Ohm::Set:0x00000003cc7f10 @model=User, @namespace="User",
  @key="User:indices:email:john.smith@gmail.com">
@users.to_a
[<User:0x00000003c94e80 @attributes={:name=>"john smith",
  :email=>"john.smith@gmail.com"}, @memo={}, @id="1">]
{% endhighlight %}

#### Articles

Let's make things a little bit more complicated and introduce `Article` model which belongs_to `User`.  We can do it in Ohm like this:

{% highlight ruby %}
class User < Ohm::Model
  collection :articles, :Article
end
class Article < Ohm::Model
  attribute :title
  attribute :body
  reference :user, :User
  index :title
end
{% endhighlight %}

Since Ohm library allows us to search only by exact match (email = 'john.smith@gmail.com') it does not make sense to implement index on `body` as it will be very long.  But we could index `title`.  

Here is the Hash with core data:

{% highlight ruby %}
{"db":1,"key":"Article:1","ttl":-1,"type":"hash","value":
  {"body":"Different approaches on how to implement search in Redis",
  "title":"Redis Search",
  "user_id":"1"}...}
{% endhighlight %}

And here are the Sets with index info.  Notice that the library automatically created index for `user_id` in addition to `title`.  

{% highlight ruby %}
# search by Article ID
{"db":1,"key":"Article:all","ttl":-1,"type":"set","value":["1"],"size":1}
# search by User ID
{"db":1,"key":"Article:indices:user_id:1","ttl":-1,"type":"set","value":["1"]...}
# search by Title
{"db":1,"key":"Article:indices:title:Redis Search","ttl":-1,"type":"set","value":["1"]...}
# list of all indexes for Articles
{"db":1,"key":"Article:1:indices","ttl":-1,"type":"set","value":
  ["Article:indices:user_id:1","Article:indices:title:Redis Search"],...}
{% endhighlight %}

To search Articles by user we can do this:

{% highlight ruby %}
@articles = Article.find(user_id: 1)
<Ohm::Set:0x00000005b83e40 @model=Article, @namespace="Article",
  @key="Article:indices:user_id:1">
#
@articles.to_a
[
  <Article:0x00000005b7cc30 @attributes={:title=>"Redis Search",
  :body=>"Different approaches on how to implement search in Redis",
  :user_id=>"1"}
  , @memo={}, @id="1">
]
{% endhighlight %}

To search by article title we can do this `Article.find(title: 'Redis Search')` and data comes back in the same `Ohm::Set` format.  

So now are are able to create indexes and search for exact match on our records or relationship attributes.  

### RediSearch

At last year's [RedisConf](http://www.redisconf.com/) they announced support for modules to extend Redis capabilities.  [RediSearch](http://redisearch.io/) module allows to to execute commands `FT.CREATE`, `FT.ADD` and `FT.SEARCH` to build full text search indexes in Redis and search for those records.  

To simplify integration I have been working on [redi_search_rails](https://github.com/dmitrypol/redi_search_rails) Ruby gem.  It integrates into models and provides handy methods like `ft_create` or `ft_search`.  Let's add it to our application.  


{% highlight ruby %}
# Gemfile
gem 'redi_search_rails'
# config/initializers/redi_search_rails.rb
REDI_SEARCH = Redis.new(db: 0)
# app/models/user.rb
class User < Ohm::Model
  ...
  include RediSearchRails
  redi_search_schema   name: 'TEXT', email: 'TEXT'
end
class Article < Ohm::Model
  ...
  include RediSearchRails
  redi_search_schema   title: 'TEXT', body: 'TEXT'
end
{% endhighlight %}

Since RediSearch supports full text search we can index the `body` and search for keywords w/in the body.

In this application we are using Redis to actually store the Users and Articles records AND to create RediSearch indexes.  But we could store Users and Articles in [MySQL](https://www.mysql.com/) or [MongoDB](https://www.mongodb.com) and redi_search_rails will work the same.

To index records we just run these commands in `rails c`

{% highlight ruby %}
User.ft_create
User.ft_add_all
Article.ft_create
Article.ft_add_all
{% endhighlight %}

Now completely different records are created in Redis

{% highlight ruby %}
{% endhighlight %}


{% highlight ruby %}
@users = User.ft_search_format(keyword: 'john')
{% endhighlight %}






### Links
* [http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index](http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index)
* [http://josephndungu.com/tutorials/fast-autocomplete-search-terms-rails](http://josephndungu.com/tutorials/fast-autocomplete-search-terms-rails)
* [http://vladigleba.com/blog/2014/05/30/how-to-do-autocomplete-in-rails-using-redis/](http://vladigleba.com/blog/2014/05/30/how-to-do-autocomplete-in-rails-using-redis/)
* [https://github.com/huacnlee/redis-search](https://github.com/huacnlee/redis-search)
* [https://github.com/RedisLabsModules/secondary](https://github.com/RedisLabsModules/secondary)
* [https://redis.io/topics/indexes](https://redis.io/topics/indexes)


{% highlight ruby %}

{% endhighlight %}
