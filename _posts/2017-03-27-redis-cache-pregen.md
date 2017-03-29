---
title: "Redis and Cache Pre-Generation"
date: 2017-03-27
categories: redis
---

A common pattern is to use Redis as a cache store where the first application request forces code to execute and then caches the results.  Subsequent requests use the cached data until Redis purges it via [TTL](https://redis.io/commands/ttl).  

* TOC
{:toc}

### Basic caching

Here is how it can be implemented with [Ruby on Rails](http://guides.rubyonrails.org/caching_with_rails.html) but there are similar patterns in other frameworks.

{% highlight ruby %}
class Article
  belongs_to :user, touch: true
end
class User
  has_many :articles
  def articles_count
    Rails.cache.fetch([cache_key, __method__], expires_in: 1.hour) do
      articles.count
    end    
  end
end
{% endhighlight %}

[cache_key](http://apidock.com/rails/ActiveRecord/Integration/cache_key) is a method that generates unique Redis key like this `user/user_id-user_updated_at_timestamp`.  Specifying `touch: true` on the `Article` relationship will modify `User.updated_at` when articles are created / deleted which will force new `cache_key`.  Appending the method name to `cache_key` ensures Redis key uniqueness if we cache other methods on the User model.  Here is what data looks like stored in Redis:

{% highlight ruby %}
{"db":0,"key":"user/123-1490568353/articles_count","ttl":3559,
  "type":"string","value":"10","size":1}
{% endhighlight %}

When browsing to a page showing all users and the number of articles they authored the first request will be slow but the subsequent ones will be faster with cached data.  

{% highlight html %}
<% @users.each do |user| %>
  <tr>
    <td><%= user.name %></td>
    <td><%= user.articles_count %></td>
  </tr>
<% end %>
{% endhighlight %}

In reality this specific task can be better accomplished with a well written SQL JOIN but usually the biz logic is more complex.

### Pre-generating cache

What if we need / want to pre-generate cached data in Redis so that the first user does not have to wait?  We could run a [background job](http://guides.rubyonrails.org/active_job_basics.html).

{% highlight ruby %}
class PreGenerateCacheJob < ApplicationJob
  def perform
    User.all.each do |user|
      user.articles_count
    end
  end
end
{% endhighlight %}

The downside is that if users do not write articles very often then the job will keep re-generating the same data for `articles_count` as Redis will flush it every hour with the TTL specified.  How can we make this process more scalable?

### Busting the cache

In [previous post]({% post_url 2016-11-18-rails-cache-bust %}) I covered various cache busting techniques.  In caching `articles_count` we are trying to find a balance between how long we want to cache the current data vs how often it changes.  

If the user has not written any new articles there is no reason to re-generate `articles_count` so we could make TTL longer.  But if new articles are created / deleted frequently (or `User.updated_at` changes for other reasons) that will cause Redis to store more `cache_key` records with previous `updated_at` timestamps.

Setting TTL to never expire will force Redis to hold the data forever.  And if we exclude `updated_at` timestamp from `cache_key` then we can to re-use the same Redis key.  But how do we avoid showing the same `articles_count` value that was calculated the first time?  [Rails cache](http://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html) has an option `force: true`.  That will force a cache miss which will execute the code and create / update data in Redis.  

{% highlight ruby %}
class ApplicationRecord
  def my_cache_key method_name
    # custom cache key which excludes updated_at
    [self.class.name, self.id, method_name].join('/')
  end
end
class User < ApplicationRecord
  def articles_count (force_param: false)
    Rails.cache.fetch(my_cache_key(__method__), expires_in: nil, force: force_param) do
      articles.count
    end    
  end
end
{% endhighlight %}

### Selecting which data to cache

This cached data will be stale until we re-generate it.  We want to run the job frequently (say every 5 minutes) and in the job we specify `force: true`.  But this will keep re-creating the cache for all users.  We need a way to filter out which users have created / deleted articles.  For that we can use `updated_at` timestamp.  If the user has created / deleted an article the Article `touch: true` will change `User updated_at`.  There could be other reasons we want to re-generate the cache so we encapsulate the logic in User model scope.

{% highlight ruby %}
class User
  scope :regenerate_cache,  ->{ where(:updated_at.gte => Time.now - 5.minutes) }
end
class PreGenerateCacheJob < ApplicationJob
  def perform
    User.regenerate_cache.each do |user|
      user.articles_count(force_param: true)
    end
  end
end
{% endhighlight %}

If we want to optimize the code further than instead of using Article `touch: true` we can build a custom callback to only update User when articles are created and deleted (not edited).  

One downside with using `updated_at` is that if users edit their info (but not create / delete articles) or create other records ( with `belongs_to: user, touch: true`) that will force re-generation of `user.articles_count`.  So it's not a perfect solution but works for many use cases.  

### Iteration overrun

Our job runs every 5 minutes but it could take > 5 minutes to complete.  And we might not want to have 2 instances of this job running at the same time.  Here are different ways to address it:

Set special Redis key (like PID file) at the beginning of the job with TTL to remove the key.  

{% highlight ruby %}
class PreGenerateCacheJob < ApplicationJob
  def perform
    # check if key exists / job is running via another process
    return if REDIS.get(self.class.name)
    # set the key
    REDIS.set(self.class.name, Time.now.to_f, {ex: 5.minutes})
    # process users
  end
end
{% endhighlight %}

Alternatively we could use APIs provided by the background job library to check if another job with same class name is running at the beginning.  That implementation will vary on the underlying library.

### More complex example

The example above with users and articles is way too simple.  Let's imagine we are building the backend system for an online banking app.  Customers use their phones to check the latest transactions on their way to work.  As a result we have a HUGE spike in DB load in the early morning hours (which requires powerful hardware and expensive software license).

What if we could even out that load and push data into cache during the earlier hours when stress on the overall system is lower?  We don't need to push ALL transactions into cache as most people are likely to look at only the first page (say 10 most recent records).  And we don't need to do it for all customers, just the ones that check their accounts frequently (say twice a week).  

{% highlight ruby %}
class Transaction
  field :description
  field :amount, type: Money
  field :created_at, type: Time
  belongs_to :customer
end
class Customer
  has_many :transactions
  def recent_transactions
    Rails.cache.fetch([cache_key, __method__], expires_in: 3.hours) do
      transactions.limit(10).pluck(:description, :amount, :created_at)
    end
  end
end
class PreGenerateCacheJob < ApplicationJob
  def perform
    Customer.each do |customer|
      customer.recent_transactions
    end
  end
end
{% endhighlight %}

This will load the most recent transactions for all customers.  How do we track customers that login frequently enough to pre-generate cache only for them?  We could have a field in the DB to track most recent logins but we could also use Redis counters and TTL.  

{% highlight ruby %}
class Customer
  include: Redis::Objects
  counter :num_logins, expiration: 1.week
  field :frequent_logins, type: Boolean
end
# data is stored in Redis like this
{"db":0,"key":"customer:customer1_id:num_logins","ttl":604799,
  "type":"string","value":"2","size":1}
{% endhighlight %}

[redis-objects](https://github.com/nateware/redis-objects) creates a Redis key based on model name, record ID and method name.  Every time customer logs in we call `customer.num_logins.incr` which will be very fast.  But if the customer does not login w/in a week that key will expire using Redis TTL and next time the `num_logins` counter will start at 1.  Then we create a job to move the data to the primary DB.  The job might be slow but it will only run once a week.  

{% highlight ruby %}
class UpdateCustomerLoginsJob < ApplicationJob
  def perform
    # reset data
    Customer.update_all(frequent_logins: false)
    # update with data from Redis, can be optimized separately
    Customer.all.each do |customer|      
      customer.update(frequent_logins: true) if customer.num_logins.value >= 2
    end
  end
end
# scope to filter customers
class Customer
  scope :frequent_logins,  ->{ where(frequent_logins == true) }
end
{% endhighlight %}

In `PreGenerateCacheJob` instead of calling `Customer.all.each ...` we call `Customer.frequent_logins.each ...`

This approach is also not perfect but it enables to cache data for customers most likely to login.  Requests for other customers will require DB queries.  And in this case we do NOT want to hold on to cached data indefinitely as new transactions are going to come in so we expire the cache and include timestamp in `cache_key`.

Approaches described above introduce complexity.  The logic in determining which methods to cache and for which records will vary widely depending on the biz requirements / resources available.  And what if the job fails to run?  The system will show stale cached data.  So we want to monitor the job process and also ensure there is enough RAM in Redis.  But applied wisely these solutions allow us to trade slight delays in data freshness for significant scalability gains.  

### Links

* [https://www.sitepoint.com/rails-model-caching-redis/]([https://www.sitepoint.com/rails-model-caching-redis/)
* [https://redis.io/topics/lru-cache](https://redis.io/topics/lru-cache)
* [http://www.infoworld.com/article/3063161/application-development/why-redis-beats-memcached-for-caching.html](http://www.infoworld.com/article/3063161/application-development/why-redis-beats-memcached-for-caching.html)
