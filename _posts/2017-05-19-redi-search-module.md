---
title: "RediSearch Module"
date: 2017-05-19
categories: redis
---

In previous [post]({% post_url 2017-05-13-redis-search %}) I wrote about different ways we can search for records in Redis.  In this article I want to do a deeper dive on [RediSearch module](http://redisearch.io/).  

* TOC
{:toc}

### Basic search

We will use Redis as the primary DB leveraging [Ohm](https://github.com/soveran/ohm) library.  But now we want to build more sophisticated indexes with RediSearch, use `NUMERIC` filter and other advanced options.  And we will continue using [RediSearchRails](https://github.com/dmitrypol/redi_search_rails) library.

{% highlight ruby %}
# Gemfile
gem 'redi_search_rails'
# config/initializers/ohm.rb
Ohm.redis = Redic.new("redis://127.0.0.1:6379/0")
# config/initializers/redi_search_rails.rb
REDI_SEARCH = Redis.new(host: 'localhost', post: 6379, db: 0)
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
10.times do |i|
  User.create(name: random_name, email: random_email, age: rand(10..50),
    height: rand(3..6), status: ['pending', 'active', 'disabled'].sample )
end
# create indexes
User.ft_create
User.ft_add_all
{% endhighlight %}

When we look in Redis we see various keys for RediSearch.  There are [Hashes](https://redis.io/topics/data-types#hashes) which contain key / value pairs for name, email, status, age and height.  RediSearchRails uses [GlobalID](https://github.com/rails/globalid) to create unique key.

{% highlight ruby %}
{"db":0,"key":"gid://app/User/1","ttl":-1,"type":"hash","value": {
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

Now we can run `User.ft_search(keyword: 'active')` or in redis-cli do `FT.SEARCH User active`.  Similar searches can be done by name or email.  We could search for all users with `gmail` address because RediSearch will index `gmail` as keyword.

{% highlight ruby %}
[2,
  "gid://app/User/1", ["name", "Stacy Mayert", "email",
  "norma@lakinmohr.info", "status", "active", "age", "31", "height", "5"],
  "gid://app/User/3", ["name", "Ernie Feest", "email",
  "danielle@dooley.co", "status", "active", "age", "14", "height", "4"]
]
{% endhighlight %}

[RediSearchRails](https://github.com/dmitrypol/redi_search_rails) library also provides additional `ft_add_all`, `ft_del_all`, `ft_search_format` and `ft_search_count` methods (not present in RediSearch module).  `ft_search_format` will return data as an array of hashes which is common pattern in ORMs like [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) or [Mongoid](https://github.com/mongodb/mongoid).  

{% highlight ruby %}
User.ft_search_format(keyword: 'active')
[
  {"id": "gid://app/User/1", "name": "Tom", "age": "100", "status": "active", ..},
  {"id": "gid://app/User/2", "name": "Mary", "age": "50", "status": "active", ..},
  ...
]
{% endhighlight %}


### Advanced options

#### Numeric filter

`numeric` indexes allow us to filter search results if we want users of a certain age or height range.

{% highlight ruby %}
# redis-cli
FT.SEARCH User active FILTER age 10 20
# or via RediSearchRails
User.ft_search(keyword: 'active', filter: {numeric_field: 'age', min: 10, max: 20})
[1,
  "gid://app/User/1", ["name", "Tom Jones", "email",
  "tom@gmail.com", "status", "active", "age", "15", "height", "4"],
]
{% endhighlight %}

#### Indexing data already in Redis

In our case we are using Redis both as primary DB and for RediSearch indexes.  The core attributes (name, email, ...) are stored as Hashes in Ohm records and then created separately by RediSearch.  We can use `FT.ADDHASH` to index existing hashes and avoid creating duplicates.  

{% highlight ruby %}
# we could create the Hash via direct Redis API call
user = Redis.new.hmset("gid://app/User/5", "name", "Bob", "email", "foo@bar.com",
 "age", "100", "status", "active")
# or via ORM
user = User.new(name: 'Bob', email: 'foo@bar.com', age: '100', status: 'active')
# now we pass GlobalID as the key to existing Redis hash
User.ft_addhash(redis_key: user.to_global_id.to_s)
# ft_search works the same
User.ft_search(keyword: 'bob')
  [1, "user1", ["name", "Bob", "age", "100", ...]]
{% endhighlight %}

#### Pagination

What if we have thousands of records that match our search criteria?  We do not want to return all results at once.  RediSearch supports `LIMIT offset num` (default offset is 0 and num is 10).  We can easily get the total number of results and request them in batches.

{% highlight ruby %}
num_records = User.ft_search_count(keyword: 'bob')
(0..num_records).step(5) do |n|
  User.ft_search_format(keyword: 'Tom', offset: 0 + n, num: n)    
end
{% endhighlight %}

### Auto complete

RediSearch module also has `FT.SUGADD`, `FT.SUGGET`, `FT.SUGDEL` and `FT.SUGLEN` methods.  Using these commands we can build an autocomplete indexes to search for users by specific attributes.  These Redis keys are completely separate from the other indexes.  RediSearchRails library creates a Redis key by combining model name with attribute (`User:name`).  

{% highlight ruby %}
user1 = User.new(name: 'Mary')
user2 = User.new(name: 'Maya')
User.ft_sugadd(record: user1, attribute: 'name')
User.ft_sugadd(record: user2, attribute: 'name')
User.ft_sugget(attribute: 'name', prefix: 'm')
["Mary", "Maya"]
# data in Redis
{"db":0,"key":"User:name*","ttl":-1,"type":"trietype0",..}
{% endhighlight %}

In addition to methods supported by RediSearch module RediSearchRails library adds `ft_sugadd_all` and `ft_sugdel_all`.  They accept attribute name (`User.ft_sugadd_all(attribute: 'name')`) and will loop through all records adding/deleting strings to auto-complete dictionaries for that attribute.  This can be useful when we have a table with specific records and we want to build auto-complete search on specific attribute.

### Conclusion

There are many other advanced options in RediSearch module.  For example, we can use GEO filters, stem keywords and do much more advanced querying.  I am working on adding support for these to RediSearchRails library.  I also want to add extra features to my library such as custom sopwords configuration and ability to specify minimum keyword length to index.  


{% highlight ruby %}

{% endhighlight %}
