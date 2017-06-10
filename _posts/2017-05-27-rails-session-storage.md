---
title: "Rails session storage"
date: 2017-05-27
categories: rails redis mongo
---

When we build applications on a singleton server things are very simple.  But then we need to start scaling out (usually better approach than scaling up) and we need to worry about session state management.  Here is a great [article by Justin Weiss](http://www.justinweiss.com/articles/how-rails-sessions-work/) and [video of his talk](https://www.youtube.com/watch?v=mqUbnZIY3OQ) on Rails sessions.

* TOC
{:toc}

### Sticky sessions

The simplest thing on AWS Elastic Load Balancer is to enable [sticky sessions](http://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-sticky-sessions.html).  ELB will create a cookie and the next time the request comes back it will be sent to the same EC2 instance as before.  

The downside is that if we need to take server out of the load balancer to do maintenance / deploy code there could still be users on it.  To help with that we need to use dedicated state server or DB to store session info.  

### Redis

In [Ruby on Rails](http://rubyonrails.org/) applications we can enable [Redis](https://redis.io/) session storage using [redis-rails](https://github.com/redis-store/redis-rails).  

{% highlight ruby %}
# config/environments/development.rb
config.redis_host = 'localhost'
# config/initializers/session_store.rb
AppName::Application.config.session_store :redis_store, {
  servers: [
    { host: Rails.application.config.redis_host,
    port: 6379, db: 0, namespace: "session" },
  ],
  expire_after: 1.day
}
# data in Redis
{"db":0,"key":"session:63f3a232ca05b895b0d9adb1b292903e","ttl":7192,
  "type":"string","value":"...","size":138}
{% endhighlight %}

Redis will purge the data after one day with [TTL](https://redis.io/commands/ttl).

### Mongo

We have been using this approach for a couple of years with [mongo_session_store-rails4](https://rubygems.org/gems/mongo_session_store-rails4) gem.  

{% highlight ruby %}
# config/initializers/session_store.rb
Rails.application.config.session_store :mongoid_store
MongoSessionStore.collection_name = "sessions"
{% endhighlight %}

Documents in Mongo will have **ID** (`zzv-ATGWb5lG-w7AwwI438pXHtk`) and **DATA** (`#<BSON::Binary:0x00000008468ce8>`).  We can also modify the default model class to add [TTL indexes](https://docs.mongodb.com/manual/core/index-ttl/) which will purge old records.  

{% highlight ruby %}
class Sessions
  include Mongoid::Document
  field :data
  field :created_at, 	type: DateTime
  field :updated_at, 	type: DateTime
  # create index to clean out the collection
  index({updated_at: 1}, {expire_after_seconds: 1.day})  
end
{% endhighlight %}

### ActiveRecord / SQL

We need to follow instructions on [activerecord-session_store](https://github.com/rails/activerecord-session_store) to install the gem and created SQL table where data will be stored.  

{% highlight ruby %}
Rails.application.config.session_store :active_record_store,
  :key => '_my_app_session'
{% endhighlight %}

**Sessions** table will have **ID** (primary key), **session_id** (`ea2c0d7d8b5799c0f48966c9312f95e8`), **data**, **created_at** and **updated_at**.  Since MySQL / Postgres do not have TTL process we will need to create a background job to clean out these records.

{% highlight ruby %}
class SessionCleanJob < ApplicationJob
  queue_as :low
  def perform(*args)
    # delete all session records older than X time
  end
end
{% endhighlight %}

Which approach should we use depends on our needs.  If we are already using Redis for other tasks such as [caching]({% post_url 2017-03-27-redis-cache-pregen %}) or [background jobs]({% post_url 2017-05-26-bulk-data-import2 %}) then it may make sense to store our session data.  On the other hand if we do not yet have Redis and our primary DB is not under strain then it's probably simpler to store sessions there.  

### Links

* [http://stackoverflow.com/questions/10494431/sticky-and-non-sticky-sessions](http://stackoverflow.com/questions/10494431/sticky-and-non-sticky-sessions)
* [http://stackoverflow.com/questions/1553645/pros-and-cons-of-sticky-session-session-affinity-load-blancing-strategy](http://stackoverflow.com/questions/1553645/pros-and-cons-of-sticky-session-session-affinity-load-blancing-strategy)
* [https://www.safaribooksonline.com/library/view/rails-cookbook/0596527314/ch04s15.html](https://www.safaribooksonline.com/library/view/rails-cookbook/0596527314/ch04s15.html)
* [http://guides.rubyonrails.org/security.html](http://guides.rubyonrails.org/security.html)
