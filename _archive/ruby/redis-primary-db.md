---
title: "Redis as primary DB"
date: 2016-09-24
categories: redis
---

Redis makes a great choice for secondary DB.  It can be used for [caching]({% post_url 2016-05-14-redis-rails-more %}), [temp data storage]({% post_url 2016-09-14-redis-tmp-data %}) or [background queue]({% post_url 2016-09-24-redis-microserv-deux %}).  But what if we were to build a system where Redis was THE primary database?  

How many of us have attended a conference or a large meeting where the presenter was using too many buzzwords?  There is a great game called [buzzword bingo](https://en.wikipedia.org/wiki/Buzzword_bingo)?  As a POC let's build a simple application backed by Redis to play buzzword bingo.

If we were modeling it with relational database or [Mongoid](https://github.com/mongodb/mongoid) we could create the following tables/models:

{% highlight ruby %}
class User
  field :email
  has_many :user_games
end
class Game
  field :name
  has_many :user_games
end
class UserGame
  belongs_to :user
  belongs_to :game
  field :buzzwords, type: Array
  field :buzzword_matches, type: Array
end
{% endhighlight %}

`buzzwords` array would contain random set of 25 for each `user_game`.  When users `match` the buzzword the position of the buzzword (0, 3, 24, etc) would be added to `buzzword_matches` array.  Then the code would check if a [row, column or diagonal](https://en.wikipedia.org/wiki/Bingo_(U.S.)) has been completed.  There are other ways to model it with [Mongoid hashes](https://docs.mongodb.com/ruby-driver/master/tutorials/5.1.0/mongoid-documents/#fields) or creating separate records for each `match`.  

In Redis we do not have separate tables / collections.  What we can do is define namespaced keys.  We also do not have [primary keys](http://www.w3schools.com/sql/sql_primarykey.asp) or [Mongo ObjectIds](https://docs.mongodb.com/manual/reference/method/ObjectId/).  With [SecureRandom](http://ruby-doc.org/stdlib-2.3.0/libdoc/securerandom/rdoc/SecureRandom.html) we can generate fairly random game IDs.  `SecureRandom.hex(5)` will create alphanumeric strings like "12c56f343f".  Combined with user's email it will create a unique combination for each `UserGame`.

User woud `create` a game and `invite` friends by email to play.  Game `show` page will load

Since we are not using traditional ORM solution we do not have many common tools.

I like using [form objects](https://robots.thoughtbot.com/activemodel-form-objects) to properly save the data to Redis.  



Set default TTL of 2 hours.  


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}











As a POC let's look at building [Instagram clone](https://www.instagram.com/).  Instagram was using [Redis](http://instagram-engineering.tumblr.com/post/12202313862/storing-hundreds-of-millions-of-simple-key-value) but apparently they eventually switched to [Cassandra](https://www.quora.com/Why-did-Instagram-abandon-Redis-for-Cassandra).  But their primary DB was Posgres.  

Many ideas in this blog were inspired by [this article](http://redis.io/topics/twitter-clone) on buliding Twitter clone with Redis.  


### Data models:

Users

Images

Votes

Followers

Following


#### ORM

https://github.com/soveran/ohm

https://github.com/nateware/redis-objects


{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}

http://tylerstroud.com/2014/11/18/storing-and-querying-objects-in-redis/

https://www.sitepoint.com/semi-relational-data-modeling-redis-ohm/