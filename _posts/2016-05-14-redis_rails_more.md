---
title: "Doing more with Redis and Rails"
date: 2016-05-14
categories: redis mongo
---

Recently I had a chance to present at [RedisConf](http://redisconference.com/) on various ways Redis can be used to quickly scale Rails applications.  This is a blog post is an expansion of the ideas that I discussed.  You also might want to read my previous posts about Redis [here]({% post_url 2016-03-18-sidekiq_batches %}) and [here]({% post_url 2015-10-15-redis_rails_tips %}).

* TOC
{:toc}

When we think of scalability we usually think of dealing with terabytes of data and millions of users.  We think of a dev team laboring for many months to build great technologies.  But there is another kind of scalabilty when your MVP starts getting more traffic and you need to QUICKLY scale the application, often by yourself.

## Caching

First I want to say that caching should not be used as bandaid solution.  We want to have well written code with optimized DB queries / indexes.  So use caching wisely.

At the core of Rails caching is the concept of Cache Key and Cached Content.  Once you create it, you do not change it.  You do not need to write observers or use callbacks to update your cache when your data changes.  You simply create new key with new content and you let the old one expire using TTL.  This approach obviously takes more RAM to store stale content but it significantly simplifies your code.  Here is a more in-depth [article](https://signalvnoise.com/posts/3113-how-key-based-cache-expiration-works) by DHH.

To enable caching you put this in your production.rb.

{% highlight ruby %}
config.cache_store = :readthis_store,
{ expires_in: 1.hour,
namespace: my_namespace,
redis: { host: 'host_name', port: 6379, db: 0 },
driver: :hiredis }
{% endhighlight %}

You can see that I am using [readthis gem](https://github.com/sorentwo/readthis) (more on why later).  I set default application TTL to 1 hour, specify Redis connection string and namespace for my keys in and [hiredis](https://github.com/redis/hiredis-rb) driver.

### View caching

You can implement caching in different layers in Rails.  You can do Fragment (view) layer caching where you will cache actual HTML of all or portions of your pages.

{% highlight ruby %}
# in users/show.html.erb
<% cache do %>
<% end %>
# cache key will look like this:
my_namespace:
views/
users/
1- # this is the primary key of the record
20160426034225854000000/  # timestamp of the record
56709796a00c700d3d99fb1edb14e6f6e5  # hash of the show.html.erb page
{% endhighlight %}

If the user record changes or you deploy a new template, it will require new cache key.

To cache index.html.erb you need to create a key based on all records on the page:

{% highlight ruby %}
<% cache [controller_name, action_name, @users.map(&:id),
@users.maximum(:updated_at) ] do %>
<% end %>
# cache key
my_namespace:
views/
users/ # controller
index/ # action
1/2/3/ # IDs of users
33/56/23/2/6/2016/4/154/false/UTC/ # most recently updated user timestamp
6f030def79c9b9dead7dcbea51cde05d #hash of erb file
{% endhighlight %}

The same can be done with Jbuilder files

{% highlight ruby %}
json.array!(@users) do |user|
  json.cache! user do
    json.extract! user, :id, :name
  end
end
# cache key
my_namespace:
jbuilder/
users/
1-
20160426034225854000000/
56709796a00c700d3d99fb1edb14e6f6e5
{% endhighlight %}

### Method caching

Let's imagine you have a online fundraising system where Users give Donations to Fundraisers.

{% highlight ruby %}
class Fundraiser
 def total_raised
   Rails.cache.fetch([cache_key, __method__], expires_in: 15.minutes) do
      donations.sum(:amount)
    end
  end
 def number_of_donations
   Rails.cache.fetch([cache_key, __method__]) do
      donations.count
    end
  end
end
# cache keys
my_namespace:
fundraisers/
1-
20160426035927682000000/
total_raised
#
my_namespace:
fundraisers/
1-
20160426035927682000000/
number_of_donations
{% endhighlight %}

By appending method name to cache_key I ensure their uniqueness.  You also see how to override default application cache_key expiration.

#### Cache busting

You might be asking what if a donation is given after this content is cached.  Currently the application will show stale data until Redis purges the key (which might be OK).  Better solution is to define `touch: true` on the parent-child relationship.  When child record is created/updated it will touch timestamp of a parent (forcing new key).

{% highlight ruby %}
class Donation
 belongs_to :user
 belongs_to :fundraiser,  touch: true # will bust campaign.total_raised
end
class User
  def total_given
    # cache will not bust since touch is not set
    Rails.cache.fetch([cache_key, __method__]) do
      donations.sum(:amount)
    end
  end
end
{% endhighlight %}

You also can have a situation where you want to bust child's cache when specific parent attribute changes (you are using parent attribute w/in child's method).  Best way is to use a callback to conditionally update children timestamps if specific parent attribute changed.

{% highlight ruby %}
class Child
  belongs_to :parent
  def method_name
    Rails.cache.fetch([cache_key, __method__]) do
      parent.attribute_name
    end
  end
end
class Parent
  has_many :children
  field :attribute_name
  after_save do
    children.update_all(updated_at: Time.now) if self.attribute_name_changed?
  end
end
{% endhighlight %}

This will bust ALL cached methods for all children.  If you want to selectively bust specific cached method then do this:

{% highlight ruby %}
class Parent
  after_save do
    return unless self.attribute_name_changed?
    children.each do |child|
      Rails.cache.delete([child.cache_key, 'method_name'])
    end
  end
end
{% endhighlight %}

#### Other classes

Method level cache can be applied to other classes, not just models.  Here I am using object.cache_key and also including self.class.name to ensure key uniqueness.  And you can include parameters in cache keys.

{% highlight ruby %}
# serializer
class UserSerializer < ActiveModel::Serializer
 def method_name parameter
   Rails.cache.fetch([object.cache_key, self.class.name, __method__, parameter]) do
   # code here
   end
 end
# cache key
my_namespace:
users/
1-
20160426035927682000000/
UserSerializer/
method_name/
parameter

# decorator
class UserDecorator < Draper::Decorator
 def method_name
   Rails.cache.fetch([object.cache_key, self.class.name, __method__]) do
   # code here
   end
 end
# cache key
my_namespace:
users/
1-
20160426035927682000000/
UserDecorator/
method_name
{% endhighlight %}

#### Caching data froml external APIs

Let's imagine an app where users can view weather data for specific zipcodes.  Obviously you are going to call 3rd party API to get the data.  In your MVP you can call on every user request but with more traffic this will become slow and $ expensive.  You could create an hourly background job to fetch weather data for all zipcodes, parse JSON and load it into your DB.

Or you could implement 1 line caching solution (which also costs less because it will only fetch data users actually need).  In this case we have no user ID or timestamp so the cache key is based on class, method and parameter.  We will need to expire it using default Redis TTL.

{% highlight ruby %}
class WeatherServiceObject
 def get_weather_data zip_code
   Rails.cache.fetch([self.class.name, __method__, zip_code],
   expires_in: 30.minutes) do
   # call the API
   end
 end
# cache key
my_namespace:
WeatherServiceObject/
get_weather_data/
zip_code
{% endhighlight %}

#### Caching controller action output

{% highlight ruby %}
class CacheController < ApplicationController
 def index
   render plain: index_cache
 end
 def show
   render plain: show_cache
 end
 def index_cache
   Rails.cache.fetch([self.class.name, __method__]) do
   end
 end
 def show_cache
   Rails.cache.fetch([self.class.name, __method__, params[:id] ]) do
   end
 end
# cache key
my_namespace:CacheController/show_cache/3
{% endhighlight %}

## Caching vs pre-generating data in your DB

As you can see caching can be implemented fairly quickly and changed easily but the downside is you cannot use results in your DB queries.  Earlier in this post I described caching total_raised and number_of_donations methods.  In order to get fundraisers that have at least X number of donations or raised Y dollars I would need fetch all records and loop through them.  Here is a simple way to pregenerate data in DB.

{% highlight ruby %}
class Donation
 # simple counter_cache relationship to do donations_count
 belongs_to :fundraiser, counter_cache: true
 # or a custom callback to do more complex logic
 after_create  do   fundraiser.inc(total_raised: amount)       end
 after_destroy do   fundraiser.inc(total_raised: amount * -1)  end
end
class Fundraiser
 field :donations_count, type: Integer # default for counter_cache
 field :total_raised,    type: Integer
end
# queries
Fundraiser.gt(donations_count: 5)
Fundraiser.gt(total_raised: 0)
{% endhighlight %}

### Storing data in the main DB AND in Redis

[redis-objects](https://github.com/nateware/redis-objects) is an interesting gem.  Let's imagine we are building an application for TV show like American Idol where in a few minutes we have to record millions of votes cast by viewers.  In our main DB we will have a table Performers with usual info (name, bio, etc).  But to increment record in traditional DB and persist it to disk will put a lot of stress on your servers.  This is where Redis can help us.  We create tmp_vote_counter in Redis and only save to main DB once the voting is done.  But as far as your Performer model is concerned it's just a method call.

{% highlight ruby %}
class Performer
 field :name, type: String
 field :bio,  type: String
 field :vote_counter, type: Integer

 include: Redis::Objects
 counter :tmp_vote_counter

 # record final vote count after audience is done voting
 def record_votes_permanently
   self.vote_counter = self.tmp_vote_counter
   self.tmp_vote_counter.reset
 end
end
class VoteController < ApplicationController
  def create
    performer.tmp_vote_counter.incr
  end
end
{% endhighlight %}

[Ohm](https://github.com/soveran/ohm) gem provides even more functionality but it's more suited for situations where Redis is your primary DB.  I am not quite ready to let go of features provided by SQL (or Mongo) and prefer to use Redis as my secondary DB.

## Background jobs
In an earlier post I described using Sidekiq to import records in batches of jobs.  Here are additional ideas for background jobs:

Cache warming - you could create a job to run periodically and warm up your cache.  This will help so the first user that hits specific page will have faster load time and keep system load more even.  But you need to be careful so that duration of these jobs is not greater than frequency.  In the past I selectively pre-cached only specific pages and let less traffic pages load on demand.

Report generation - some of our reports were getting slow so in addition to doing code optimization we switched them to run in the background and email user the results.

## Dev and test

You often find that you need to implement caching once your application begins to slow down.  In an earlier blog post I write how to use rack-mini-profiler to analyze which pages have slow methods or large number of DB queries.  You also can you use [New Relic gem](https://github.com/newrelic/rpm).  Just browse to http://localhost:3000/newrelic and you will see lots of useful stats.  And you don't even need to sign up for their service.

Functional testing of your code is pretty much the same when you implement caching.  But what is really important is performance testing.  The approach I usually take is to identify the bottlenecks, implement caching (or other code improvements), deploy to one of the prod servers and run a series of tests using tools like [Siege](https://www.joedog.org/siege-home/) or [wrk](https://github.com/wg/wrk).  Then if I am satisfied, deploy the code to other prod servers.

## DevOps

The reason I like [readthis](https://github.com/sorentwo/readthis) gem is because of Readthis.fault_tolerant = true option.  This way Rails app will not crash if it can't connect to Redis.  redis-store gem has an [issue](https://github.com/redis-store/redis-rails/issues/14) on this with some monkey patch ideas but readthis solution is more robust.

We run our sites on AWS and use ElastiCache with multi AZ replication group. Use Group Primary Endpoint in your config files (NOT individual cache clusters).  AWS will sometimes switch your nodes so read-write will become read only.  If you are talking directly to a node you will get an error "You can't write against a read only slave".

You could run your own Redis on EC2 instances (which also gives you controler over which version of Redis to use) but then you are responsible for backups, failover, etc.  And you could also use a hosted solution like [RedisLabs](https://redislabs.com/).  Services like Heroku provide very simple integrations with free trials but higher long term costs.

For monitoring I primarily use AWS BytesUsedForCache to make sure I do not run out of RAM.  I also have a /health controller endpoint in my application where I check for Redis connection.  The URL gets pinged every minute by 3rd party service and will email/text an alert in case of errors.  I also would like implement a monitor on my Sidekiq background jobs (threshold of number of jobs in error state or number of retries).

[redis-dump](https://github.com/delano/redis-dump) is not actively maintained but allows you to dump Redis data into JSON files and then restore on a different server.  I've used it to move data from prod into dev.

If you do not want to integrate with service like [LogEntries](https://logentries.com/) or [Rollbar](https://rollbar.com) you can try [Logster](https://github.com/discourse/logster) gem.  Just browse to http://yourwebsite.com/logs.  Your can trigger your own alerts based on certain thresholds.

## Additional links
* Sample app that I built - https://github.com/dmitrypol/rails_redis
* http://guides.rubyonrails.org/caching_with_rails.html
* http://railscasts.com/episodes/115-model-caching-revised
* http://brandonhilkert.com/blog/sidekiq-as-a-microservice-message-queue/
* http://www.nateberkopec.com/2015/07/15/the-complete-guide-to-rails-caching.html
* http://www.justinweiss.com/articles/a-faster-way-to-cache-complicated-data-models/
