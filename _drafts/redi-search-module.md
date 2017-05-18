---
title: "RediSearch Module"
date: 2017-05-15
categories: redis
---

In previous [post]({% post_url 2017-05-13-redis-search %}) I wrote about different ways we can search for records in Redis.  In this one I want to do a deep dive on [RediSearch module](http://redisearch.io/).  

* TOC
{:toc}

### Basic configuration

We will continue using Redis as the primary DB leveraging [Ohm](https://github.com/soveran/ohm) library.  But now we want to build more sophisticated indexes with RediSearch and use `NUMERIC` search.  And we will use [redi_search_rails](https://github.com/dmitrypol/redi_search_rails) library.

{% highlight ruby %}
# Gemfile
gem 'redi_search_rails'
# config/initializers/ohm.rb
Ohm.redis = Redic.new("redis://127.0.0.1:6379/1")
# config/initializers/redi_search_rails.rb
# put core data and RediSearch indexes in different Redis DBs, easier to view
REDI_SEARCH = Redis.new(db: 0)
# app/models/user.rb
class User < Ohm::Model
  attribute :name
  attribute :email
  attribute :status
  attribute :age
  attribute :height
  include RediSearchRails
  redi_search_schema   name: 'TEXT', email: 'TEXT', status: 'TEXT',
    age: 'NUMERIC', height: 'NUMERIC'
end
{% endhighlight %}

Generate random seed data:

{% highlight ruby %}
# repeat X times
User.create(name: random_name, email: random_email, age: rand(10..50),
  height: rand(3..6), status: ['pending', 'active', 'disabled'].sample )
# create indexes
User.ft_create
User.ft_add_all
{% endhighlight %}

When we look in Redis we see various keys.  There are [Hashes](https://redis.io/topics/data-types#hashes) which contain key / value pairs for name, email, status, age and height.  

{% highlight ruby %}
{"db":1,"key":"gid://app/User/1","ttl":-1,"type":"hash","value": {
  "name": "John Smith",
  "email": "john.smith@gmail.com",
  "status": "pending",
  "age": 39,
  "height": 5}, ...}
{% endhighlight %}

Separately we have custom data types for indexes:

{% highlight ruby %}
# general index
{"db":0,"key":"idx:User*","ttl":-1,"type":"ft_index0",..}
# numeric indexes
{"db":0,"key":"nm:User/height*","ttl":-1,"type":"numericdx",..}
{"db":0,"key":"nm:User/age*","ttl":-1,"type":"numericdx",..}
# indexed keywords
{"db":0,"key":"ft:User/john*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:User/smith*","ttl":-1,"type":"ft_invidx",..}
{% endhighlight %}

Now we can run `User.ft_search(keyword: 'active')` or in redis-cli we can do `FT.SEARCH User active`.  Similar searches can be done by name or email.  

{% highlight ruby %}
[2,
  "gid://app/User/1", ["name", "Wade Mayert", "email",
  "norma@lakinmohr.info", "status", "active", "age", "31", "height", "5"],
  "gid://app/User/3", ["name", "Ernie Feest", "email",
  "danielle@dooley.co", "status", "active", "age", "14", "height", "4"]
]
{% endhighlight %}

#### Numeric filter

We can use `numeric` indexes to filter search results if we want users of a certain age or height range.

{% highlight ruby %}
# redis-cli
FT.SEARCH User active FILTER age 10 20
# or via redi_search_rails
User.ft_search(keyword: 'active', filter: {numeric_field: 'age', min: 10, max: 20})
[1,
  "gid://app/User/1", ["name", "Tom Jones", "email",
  "foo@bar.com", "status", "active", "age", "15", "height", "4"],
]
{% endhighlight %}


### Advanced options

#### Pagination

But what if we have thousands of records match our search criteria?  We do not want to return all results at once.  

{% highlight ruby %}

{% endhighlight %}

#### Indexing existing keys

In our case we are using Redis both as primary DB and for RediSearch indexes.  The core attributes are stored in Hashes in both Ohm fields and in RediSearch indexes.  

{% highlight ruby %}
FT.ADDHASH

{% endhighlight %}




### Auto complete



{% highlight ruby %}

{% endhighlight %}



### Links




{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
