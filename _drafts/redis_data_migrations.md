---
title: "Redis data migrations"
date: 2016-08-31
categories:
---

When you use Redis for caching changing data structure is much simpler.  New code generates new data in new format and you let old data expire.

But if you are using Redis to permanently store some or all of your application data?  You can change the code but you still need to write a data migration.

In Rails you have ability to create migrations not just for schema but for data as well.

### Redis as secondary DB

With ActiveRecord you can use the default `rails g migration`.  It will create a table in your DB where it will track all migrations (classes will have unique timestampled names).

If you are using MongoDB you can use https://github.com/adacosta/mongoid_rails_migrations gem.  It will create a DataMigrations collection that will serve the same purposes.

Now your migrations will look like this:

{% highlight ruby %}
class MyMigration < Mongoid::Migration
  def self.up
    # your code here to change Redis data here
  end
  def self.down
    # change data back to the old format
  end
end
{% endhighlight %}

You can easily put your custom code that will restricture Redis data in the `up` and `down` methods.  You using the MySQL table / Mongo collection to track which migration classes have been executed.

### Redis as only DB

You need a place somewhere to keep track of which migrations were ran and which have not.

You also need ability to generate the migration classes.

And you need `rake db:migrate` tasks which will run the migration classes which have not yet been ran.

I created a gem for this https://github.com/dmitrypol/redis_rails_migrations


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}

