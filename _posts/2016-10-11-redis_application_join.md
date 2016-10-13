---
title: "Redis as temp cache for application-side joins"
date: 2016-10-11
categories: redis mongo
---

[SQL joins](http://www.w3schools.com/sql/sql_join.asp) are a powerful feature that enables using DB functionality to bring back records from different tables needed w/o making multiple queries.  Unfortunately some of the new NoSQL DBs do not support them.

We have been using [MongoDB](http://mongodb.com) for several years and overall really like it.  Except that sometimes we have to do N+1 queries looping through child records and fetching data attributes from the parent or grandparent.  

Let's walk through implementing application side joins where we are combining data attributes from different queries.  Our example is a CMS application built with [Ruby on Rails](http://rubyonrails.org/) and [Mongoid](https://github.com/mongodb/mongoid).

{% highlight ruby %}
class User
  field :name, type: String
  has_many :articles
end
class Article
  field :title, type: String
  belongs_to :user
  has_many :comments
end
class Comment
  field :body, type: String
  belongs_to :article
  scope :recent, ->{ gte(created_at: Date.yesterday)  }
end
{% endhighlight %}

Now we need to generate a report of recent Comments and include Article titles and names of User who wrote the articles.  In SQL we could write:

{% highlight ruby %}
select
c.body, a.title, u.name
from Comment c
join Article a on c.article_id = a.id
join User u on a.user_id = u.id
where c.created_at > CURDATE() - INTERVAL 1 DAY
{% endhighlight %}

With SQL DBs we can [eager load associations](http://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations) which will use joins to get Users.  But with Mongo we can only do `Comment.recent.includes(:article)` to [eager load](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid%2FCriteria%3Aincludes) Articles and we end up querying for EACH `user.name` separately.  

{% highlight ruby %}
Comment.recent.includes(:article).each do |c|
  puts [c.body, c.article.title, c.article.user.name].join(',')
end
{% endhighlight %}

What if we could fetch all Articles for recent comments and then fetch all related User records?  It will be more than 1 query but it is better than N+1.  

{% highlight ruby %}
# app/services/report.rb
article_ids = Comment.recent.pluck(:article_id)
articles = Article.in(id: article_ids).only(:title, :user_id)
#
user_ids = articles.pluck(:user_id)
users = User.in(id: user_ids).only(:name)
{% endhighlight %}

We do not need all User and Article attributes so we specify fields using `.only`.  But where do we store the User and Article records as we loop through Comments while generating our report?  We could build our own data structures but why not throw them into Redis as Hashes?

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
# app/services/report.rb
articles.each do |record|
  key = [record.class.name, record.id.to_s].join(':')
  # http://www.rubydoc.info/github/ezmobius/redis-rb/Redis#hmset-instance_method
  REDIS.hmset(key, 'title', record.title, 'user_id', record.user_id)
end
users.each do |record|
  key = [record.class.name, record.id.to_s].join(':')
  REDIS.hmset(key, 'name', record.name)
end
{% endhighlight %}

Data cached in Redis will look like this:

{% highlight ruby %}
{"db":0,"key":"User:57fc62651d41c873ba6c880c","ttl":-1,"type":"hash",
"value":{"name":"user1"},...}
{"db":0,"key":"Article:57fc62651d41c873ba6c8814","ttl":-1,"type":"hash",
"value":{"title":"article1","user_id":"57fc62651d41c873ba6c880c"},...}
...
{% endhighlight %}

`57fc62651d41c873ba6c880c` is part of User key AND is stored as `user_id` in Article hash. Now we can loop through `Comments` but instead of using regular relationships `c.article.body` and `c.article.user.name` (which would have caused DB queries) we are grabbing data attributes from records cached in Redis.  If we use `Comments.includes(:article)` then we only need Redis for User records caching.  

{% highlight ruby %}
# app/services/report.rb
Comment.recent.each do |c|
  # find article in Redis
  key_a = ['Article', c.article_id].join(':')
  # http://www.rubydoc.info/github/ezmobius/redis-rb/Redis#hgetall-instance_method
  article = REDIS.hgetall(key_a)
  # find user in Redis
  key_u = ['User', article['user_id']].join(':')
  user = REDIS.hgetall(key_u)
  puts [c.body, article['title'], user['name']].join(',')
end
{% endhighlight %}

Last we remove the records cached in Redis.  

{% highlight ruby %}
r_article_ids = article_ids.map(&:to_s).map{ |id| id.prepend('Article:') }
# ['Article:57fc62651d41c873ba6c8814', 'Article:57fc62651d41c873ba6c7725']
REDIS.del(r_article_ids)
r_user_ids = user_ids.map(&:to_s).map{ |id| id.prepend('User:') }
REDIS.del(r_user_ids)
{% endhighlight %}

This design requires writing more code but it speeds up your report generator AND decreases DB load.  It can also work when querying records from multiple SQL DBs or from 3rd party APIs.  We fetch each dataset separately and use Redis as temp data store.
