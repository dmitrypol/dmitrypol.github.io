---
title: "Rails cache busting"
date: 2016-11-18
categories: rails redis
---

[Rails caching](http://guides.rubyonrails.org/caching_with_rails.html) is a great tool for scaling websites.  We can use different cache stores ([Redis](http://redis.io/) and [Memcached](https://memcached.org/)) being common choices.  

Using [key based cache](https://signalvnoise.com/posts/3113-how-key-based-cache-expiration-works) frees us from writing observers to manually purge the cache.  When record is updated it's [cache_key](http://apidock.com/rails/ActiveRecord/Base/cache_key) changes, new content is cached and old one is eventually purged using TTL.  Here is my previous [post]({% post_url 2016-05-14-redis-rails-more %}) about various uses of caching.  

To enable it we modify production.rb.

{% highlight ruby %}
config.cache_store = :readthis_store,
{ expires_in: 1.hour,
namespace: app_cache,
redis: { host: 'host_name', port: 6379, db: 0 },
driver: :hiredis }
{% endhighlight %}

Here is a basic CMS with Articles and Comments.  

{% highlight ruby %}
# app/models/article.rb
class Article
  field :body
  has_many :comments
  def comments_count
    Rails.cache.fetch([cache_key, __method__]) do
      comments.count
    end
  end
  def another_method
    Rails.cache.fetch([cache_key, __method__]) do
      ...
    end
  end
end
# app/models/comment.rb
class Comment
  field :body
  belongs_to :article, touch: true
end
{% endhighlight %}

We cache `comments_count` and use `touch: true` to update Article timestamp when new comment is created/update.  The problem is it busts cached data for ALL Article methods and [view cache](https://signalvnoise.com/posts/3690-the-performance-impact-of-russian-doll-caching) as well.  We might not want that.

In such cases instead of `touch: true` we can implement [callbacks](http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html) on the child record to [delete](http://api.rubyonrails.org/classes/ActiveSupport/Cache/Store.html#method-i-delete) specific cached data for the parent record.

{% highlight ruby %}
# app/models/comment.rb
class Comment
  field :body
  belongs_to :article
  after_create  :article_comments_count
  after_destroy :article_comments_count
private
  def article_comments_count
    cache_key = [article.cache_key, 'comments_count']
    Rails.cache.delete(cache_key)
  end
end
{% endhighlight %}

This will not impact Article timestamp and leave the other cached data in place.  We do need to be more careful with this approach as it could lead to situations where only some cached data is deleted but some remains stale until default application TTL removes it.  But this can be a useful solution where there is unnecessary cache purging and recreation.  
