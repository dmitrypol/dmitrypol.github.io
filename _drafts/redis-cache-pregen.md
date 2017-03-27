---
title: "Redis cache pre-generation"
date: 2017-03-26
categories: redis
---

A common pattern is to use Redis as a cache store where the first application request forces code to execute (query DB) and then store data in cache.  Subsequent requests use the cached data until it expires.  

Here is how it can be implemented with [Ruby on Rails](http://guides.rubyonrails.org/caching_with_rails.html)

### Basic caching

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

[cache_key](http://apidock.com/rails/ActiveRecord/Integration/cache_key) is a method that generates unique Redis key like this `user/user_id-user_updated_at_timestamp`.  Specifying `touch: true` on the `Article` relationship will modify `User.updated_at` when articles are created/deleted.  And we are appending the method name to `cache_key` to ensure Redis key uniqueness (what if we cache other methods on User model).  Here is what data will look like when stored in Redis:

{% highlight ruby %}
{"db":0,"key":"user/123-1490568353/articles_count","ttl":3559,
  "type":"string","value":"10","size":1}
{% endhighlight %}

When we browse to the page showing the list of users and the number of articles they have authored the first request will be slow but the subsquent ones will use cached data.  

{% highlight html %}
<% @users.each do |user| %>
  <tr>
    <td><%= user.name %></td>
    <td><%= user.articles_count %></td>
  </tr>
<% end %>
{% endhighlight %}

In reality this specific task can be accomplished much better with a well written SQL JOIN but usually the biz logic is much more complex.  

### Pre-generating cache

But what if we need / want to pre-generate cached data in Redis so that the first user does not need to wait?  We could run a background job.

{% highlight ruby %}
class PreGenerateCacheJob < ApplicationJob
  def perform
    User.all.each do |user|
      user.articles_count
    end
  end
end
{% endhighlight %}

The downside of this approach is that if users do not write articles very often then the job will keep re-generating the same data for `articles_count` as Redis will flush it every hour with the TTL specified.  Let's make this process more scalable.

In caching `articles_count` we are trying to find a ballance between how long we want to cache the current data vs how often it changes.  If the user has not written any new articles there is no reason to re-generate `articles_count` so we could make TTL longer.  But if new articles are created / deleted frequently (or `User.updated_at` changes for other reasons) that will cause Redis to store `cache_key` with previous `updated_at` timestamps.

If we set TTL to never expire than Redis will hold the data forever.  And if we exclude `updated_at` timestamp from `cache_key` that will allow us to use the same Redis key.  But how do we avoid showing the same `articles_count` value that was calculated the first time?  [Rails cache](http://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html) has an option `force: true`.  That will force a cache miss which will execute the code and create/update data in Redis.  

{% highlight ruby %}
class ApplicationRecord
  def my_cache_key method_name
    [self.class.name, self.id, method_name].join('/')
  end
end
class User < ApplicationRecord
  def articles_count
    Rails.cache.fetch(my_cache_key(__method__), expires_in: nil, force: true) do
      articles.count
    end    
  end
end
{% endhighlight %}

The problem with this approach is that cached data will be stale until we re-generate it.  So we want to run the job frequently (say every 5 minutes).  But this will keep re-generating the cache for all users every time.  We need a way to filter out which users are likely to have updated `articles_count`.  For that we can use `updated_at` timestamp.  If the user has created / deleted an article the Article `touch: true` will change `User updated_at`.  There also could be other reasons we want to re-generate the cache so we can encapsulate the logic in scope on User model.

{% highlight ruby %}
class User
  scope :regenerate_cache,  ->{ where(:updated_at.gte => Time.now - 5.minutes) }
end
class PreGenerateCacheJob < ApplicationJob
  def perform
    User.regenerate_cache.each do |user|
      user.articles_count
    end
  end
end
{% endhighlight %}

If we want to optimize the system further than instead of using Article `touch: true` we can build a custom callback to only update User when articles are created and deleted (not edited).  The downside with using `updated_at` is that if we only edit user info that will also force re-generation of cache.  And if User also authored Comments than writing a new Comment will force re-generation of `articles_count`.


### Iteration overrun

Since the job is running every 5 minutes it's possible that it will take > 5 minutes to complete.  And we might not want to have 2 instances of this job running at the same time.  

Check if another job with same name running at the begining.  

Set special Redis key (like PID file) at the beginning and remove at the end of the job.  Also set TTL on it to ensure that the key expires if the fails to delete it.  


### Monitoring

Another downside of using the job to pre-generate cache is that if the job fails to run the system will show stale cached data that will never expire.  So we want to monitor the job process.  



### Links


Let's imagine we are building the backend system for an online banking app.  Users typically use their phones to check the latest transactions on their way to work.  As a result, you are likely to have a HUGE spike in DB load roughly between 7 and 9 am.  And if you are using a DB like SQL Server, DB2 or Oracle it will require an expensive license and powerful hardware.

What if you could even out that load and push data into cache during the earlier hours when stress on the overall system is much less?  You probably don't need to push ALL transactions into cache as most people are likely to look at only first page (say 10 most recent transactions).




### Selecting which data to cache

Pre-generating cache could actually waste a lot of computer cycles as what if users never login?

Which users do you pre-generate cache for?

Which transactions to cache?


### Busting the cache

You will need to bust this cache if a new transaction occurs AFTER you pre-generated the data.



force: true

using `updated_at` scope and refresh cache for all records that were updated

iteration overrun - prevent job from running while another instance is running


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


https://www.sitepoint.com/rails-model-caching-redis/

In previous post http://dmitrypol.github.io/rails/redis/2016/11/18/rails-cache-bust.html I covered various cache busting techniques.  
