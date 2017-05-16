---
title: "Redis Search"
date: 2017-05-13
categories: redis
---

When I first started using [Redis](https://redis.io/) I loved the speed and the powerful data structures.  Over the years I used Redis for data analysis, caching, queuing background jobs and permanent data storage.

The one feature I missed is built in support for searching records by value (not key).  Coming from strong SQL background it was frustrating to be unable to do equivalent of `select first_name, last_name from users where email = ...`.  In this post I will provide high level overview of different approaches on how to implement search in Redis.  

* TOC
{:toc}

### Using client library

As POC we will build an application using Redis as the primary DB with Ruby [Ohm](https://github.com/soveran/ohm) library.  To keep things simple we will start with only one model `User` with `name` and `email` attributes.  

#### Users

{% highlight ruby %}
# config/initializers/ohm.rb
Ohm.redis = Redic.new("redis://127.0.0.1:6379/1")
# app/models/user.rb
class User < Ohm::Model
  attribute :name
  attribute :email
  index :name
  index :email  
end
{% endhighlight %}

When we create user records we will have a [Redis Hash](https://redis.io/topics/data-types#hashes) with User name and email.  The key will be combination of model and ID.

{% highlight ruby %}
{"db":1,"key":"User:1","ttl":-1,"type":"hash","value":
  {"name":"john smith","email":"john.smith@gmail.com"},"size":39}
{% endhighlight %}

Ohm library will also create several [Redis Sets](https://redis.io/topics/data-types#sets).  It will create a Set with key `User:all` and list of IDs for all users.  This way we can find User by ID.

{% highlight ruby %}
{"db":1,"key":"User:all","ttl":-1,"type":"set","value":["1"],"size":2}
# in rails console
User[1]
<User:0x00000005e4ef80 @attributes={:name=>"John Smith",
  :email=>"john.smith@gmail.com"}, @memo={}, @id=1>
{% endhighlight %}

Separately there will be Sets with keys prefixed with `User:indices` and based on attributes (`email:..` and `name:...`).  Set members are IDs of records that match the criteria (in this case only `[1]`).  This enables search for user by name or email since we defined `index` for those fields.

{% highlight ruby %}
{"db":1,"key":"User:indices:name:john smith","ttl":-1,"type":"set",
  "value":["1"]..}
{"db":1,"key":"User:indices:email:john.smith@gmail.com","ttl":-1,"type":"set",
  "value":["1"]..}
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

To make things a little bit more complicated we will introduce `Article` model which belongs_to `User`.  

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

Since Ohm library allows us to search only by exact match (`email: 'john.smith@gmail.com'`) it does not make sense to index `body` as it will be very long.  But we could index `title`.  

Here is the Hash with core Article data:

{% highlight ruby %}
{"db":1,"key":"Article:1","ttl":-1,"type":"hash","value":
  {"body":"Different approaches on how to implement search in Redis",
  "title":"Redis Search",
  "user_id":"1"}...}
{% endhighlight %}

Here are the Sets with index info.  Notice that the library automatically created index for `user_id` in addition to `title`.  

{% highlight ruby %}
# search by Article ID - Article[1]
{"db":1,"key":"Article:all","ttl":-1,"type":"set","value":["1"],"size":1}
# search by User ID - Article.find(user_id: 1)
{"db":1,"key":"Article:indices:user_id:1","ttl":-1,"type":"set","value":["1"]...}
# search by Title - Article.find(title: 'Redis Search')
{"db":1,"key":"Article:indices:title:Redis Search","ttl":-1,"type":"set","value":["1"]...}
# list of all indexes for Articles
{"db":1,"key":"Article:1:indices","ttl":-1,"type":"set","value":
  ["Article:indices:user_id:1","Article:indices:title:Redis Search"],...}
{% endhighlight %}

To search Articles by user we can do this:

{% highlight ruby %}
@articles = Article.find(user_id: 1)
# or this
@articles = User[1].articles
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

Now are are able to create indexes and search for exact match on our records or relationship attributes.  We are using regular Redis DB to both store and search our data.  

### RediSearch module

At [RedisConf 2016](http://www.redisconf.com/) they announced support for modules to extend Redis capabilities.  I found [RediSearch](http://redisearch.io/) module to be interesting.  It adds commands such as `FT.CREATE`, `FT.ADD` and `FT.SEARCH` to build full text search indexes (not just exact match) in Redis.  Module installation instructions can be found at [http://redisearch.io/Quick_Start/](http://redisearch.io/Quick_Start/)

To simplify development I have been working on [redi_search_rails](https://github.com/dmitrypol/redi_search_rails) gem.  It integrates into application models and provides handy methods like `ft_create` and `ft_search`.  We can install it from [RubyGems](https://rubygems.org/gems/redi_search_rails) or [GitHub](https://github.com/dmitrypol/redi_search_rails).  

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

Since RediSearch supports full text search we can index the `body` and search for keywords w/in it.  In this application we are using Redis to actually store the Users and Articles records AND to create RediSearch indexes.  But we could store Users and Articles in [MySQL](https://www.mysql.com/) or [MongoDB](https://www.mongodb.com) and redi_search_rails will work the same.

To index data we run these commands in `rails console`

{% highlight ruby %}
User.ft_create
User.ft_add_all
Article.ft_create
Article.ft_add_all
{% endhighlight %}

Now completely different records are created in Redis.  RediSearch module will create Hashes to store the indexed attributes.  In my RediSearchRails library I am using [GlobalID](https://github.com/rails/globalid) to create unique IDs.  

{% highlight ruby %}
{"db":0,"key":"gid://application_name/User/1","ttl":-1,"type":"hash","value":
  {"name": "john smith","email": "john.smith@gmail.com"}, ...}
{"db":0,"key":"gid://application_name/Article/1","ttl":-1,"type":"hash","value":
  {"body": "Different approaches on how to implement search in Redis",
  "title": "Redis Search"}, ...}
{% endhighlight %}

RediSearch will also create custom data types.  There will `ft_index`, one for each Index that we created:

{% highlight ruby %}
{"db":0,"key":"idx:User*","ttl":-1,"type":"ft_index0",..}
{"db":0,"key":"idx:Article*","ttl":-1,"type":"ft_index0",..}
{% endhighlight %}

And multiple keys of `ft_invidx` data type based on different keywords:

{% highlight ruby %}
{"db":0,"key":"ft:User/john*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:User/smith*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:User/gmail*","ttl":-1,"type":"ft_invidx",..}
...
#
{"db":0,"key":"ft:Article/redis*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:Article/search*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:Article/different*","ttl":-1,"type":"ft_invidx",..}
{"db":0,"key":"ft:Article/approach*","ttl":-1,"type":"ft_invidx",..}
...
{% endhighlight %}


Now we can execute full text search commands.  RediSearch module will use the custom indexes to find appropriate keys and return search results.

{% highlight ruby %}
@users = User.ft_search(keyword: 'john')
[1, "gid://redi-search-demo/User/1", ["name", "john smith",
  "email", "john.smith@gmail.com"]]
@users = User.ft_search_format(keyword: 'john')
[<OpenStruct id="gid://redi-search-demo/User/1", name="john smith",
  email="john.smith@gmail.com">]
{% endhighlight %}

### Benchmark(eting) stats

I started with a simple text file with 10K users with names and email addresses.  On disk file size was about 400KB.  Once loaded into RediSearch it created 22.5K keys and RDB file was 1.7 MB in size.  

I then indexed 1 million users.  The indexing process took about 6 minutes.  It created 1.5 million keys and RDB file was 202MB.  Last I indexed 10 million users which took almost 60 minutes.  There were 12 million keys and RDB file was 1.9GB.  

In all three cases search results via Ruby `User.ft_search(keyword: 'John')` and via redis-cli `FT.SEARCH User john`) were nearly instanteneous.  Tests were performed on a Dell workstation with 16GB RAM.  Obviously the results will vary widely depending on the types of records indexed.  

### Conclusion

As we can see the two approaches are very different.  RediSearch allows us to implement full text search across documents.  The library is under active development by [RedisLabs](https://redislabs.com/) and other contributors.  

RediSearch supports other interesting features such as indexing numeric values (prices, dates, ...) and `FT.SUGADD` / `FT.SUGGET` for  auto-completing suggestions.  I plan to cover those in a future blog post.  I look forward to when it officially moves out of beta and becomes supported by Redis hosting providers.  

On the other hand [Ohm](https://github.com/soveran/ohm) secondary indexes allow us to do exact match and build relationships between records bringing it close to the ORM like functionality.  It also works with regular Redis w/o requiring installing additonal modules directly on the server.  

### Links
* [https://redislabs.com/solutions/use-cases/redis-full-text-search/](https://redislabs.com/solutions/use-cases/redis-full-text-search/)
* [https://github.com/RedisLabsModules/secondary](https://github.com/RedisLabsModules/secondary)
* [https://redis.io/topics/indexes](https://redis.io/topics/indexes)
* [http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index](http://patshaughnessy.net/2011/11/29/two-ways-of-using-redis-to-build-a-nosql-autocomplete-search-index)
* [http://josephndungu.com/tutorials/fast-autocomplete-search-terms-rails](http://josephndungu.com/tutorials/fast-autocomplete-search-terms-rails)
* [http://vladigleba.com/blog/2014/05/30/how-to-do-autocomplete-in-rails-using-redis/](http://vladigleba.com/blog/2014/05/30/how-to-do-autocomplete-in-rails-using-redis/)
* [https://github.com/huacnlee/redis-search](https://github.com/huacnlee/redis-search)
