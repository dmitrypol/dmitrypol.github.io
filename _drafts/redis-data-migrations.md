---
title: "Redis data migrations"
date: 2017-05-28
categories: redis
---

When we use [Redis](https://redis.io/) for caching changing data stored in Redis is simple.  Updated code generates new cached content and we let old cache expire or manually `flushdb`.  But what if we are using Redis to [permanently store]({% post_url 2017-03-05-redis-leaderboard %}) our application data?  We can change the code but then we need to write a data migration.

* TOC
{:toc}

In [Ruby on Rails](http://rubyonrails.org/) we have ability to create migrations not just for schema but for data.

### ActiveRecord / SQL

With [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) we can use the default `rails g migration redis_data`.  It will use a table in the primary DB where it will track all migrations.  Ruby migration classes with timestamped filenames will be stored in `db/migrate` folder.  

{% highlight ruby %}
class RedisData < ActiveRecord::Migration[5.0]
  def self.up
    # migration code to change Redis data
  end
  def self.down
    # rollback code to change Redis data back
  end
end
{% endhighlight %}

We also can combine migrating data/schema in primary DB with updating related data in Redis in the same `up` or `down` methods.  More details on structuring and testing these classes in [previous post on complex migrations]({% post_url 2016-10-27-rails-complex-data-migrations %}).  

### MongoDB

When using [MongoDB](https://www.mongodb.com/) with [Mongoid](https://github.com/mongodb/mongoid) we can leverage [mongoid_rails_migrations](https://github.com/adacosta/mongoid_rails_migrations) gem.  It will create a `DataMigrations` collection in Mongo.

Migration classes will also be stored in `db/migrate` but now they will look like this:

{% highlight ruby %}
class RedisDataMigration < Mongoid::Migration
  def self.up
  end
  def self.down
  end
end
{% endhighlight %}

Just like in default rails migration the gem uses this `DataMigrations` collection to track which migration classes have been executed.  It supports ability to do default `rake db:migrate`, `rollback` and apply/remove individual migration classes.  

### Redis as the primary DB

We need a place somewhere to keep track of which migrations were ran and which were not.  Since the classes will have a similar naming convention of `timestamp_description.rb` we can use `timestamp` as the unique identifier.  This can be recorded in [Redis Set](https://redis.io/topics/data-types#sets).

We also need ability to generate the migration classes via `rails g migration`

And we need `rake db:migrate` tasks which will execute the migration classes which have not yet been applied.

I am working on a gem for this [https://github.com/dmitrypol/redis_rails_migrations](https://github.com/dmitrypol/redis_rails_migrations).  


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}

