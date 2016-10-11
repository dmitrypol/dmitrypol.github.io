---
title: "Redis cache objects"
date: 2016-10-10
categories: redis
---

SQL joins are a very powerful feature allowing you to use DB functionality to bring back the records you need w/o making multiple queries.  Unfortunately some the new NoSQL DBs do not support it.  

We have been using [MongoDB](http://mongodb.com) for several years and overall really like it.  Except that often we have to do N+1 queries looping through child records and fetching data attributes from the parent or grand-parent record.  Let's think through hypothetical CMS application.  

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

Now we need to generate a report of User names who wrote Articles that have recent Comments.  We also need to incldue Article titles.  If it were a one-step relationship we would have done `Comment.recent.includes(:article)` but due to MongoDB not supporting joins it ends up querying for EACH User name separately.  

What if we could featch all Articles for recent comments and then fetch User records.  It still would not be just 1 query (as we could do with a good SQL join) but it is better than N+1.  

{% highlight ruby %}
#	app/services/report.rb
article_ids = Comment.recent.pluck(:article_id)
articles = Article.in(id: article_ids).only(:title, :user_id)
#	
user_ids = articles.pluck(:user_id)
users = User.in(id: user_ids).only(:name)
# we do not need all User and Article attributes
{% endhighlight %}

But where do we store the User and Article records as we loop through Comments while generating our report?  How about quickly throwing them into Redis as Hashes?

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
#	app/services/report.rb
articles.each do |record|
	key = [record.class.name, record.id.to_s].join(':')
	#	http://www.rubydoc.info/github/ezmobius/redis-rb/Redis#hmset-instance_method
  	REDIS.hmset(key, 'title', record.title, 'user_id', record.user_id)
end
#	
users.each do |record|
	key = [record.class.name, record.id.to_s].join(':')
	REDIS.hmset(key, 'name', record.name)
end
{% endhighlight %}

After running this process you will have data in Redis that looks somewhat like this:

{% highlight ruby %}
{"db":0,"key":"User:57fc62651d41c873ba6c880c","ttl":-1,"type":"hash",
"value":{"name":"user1"},...}
{"db":0,"key":"Article:57fc62651d41c873ba6c8814","ttl":-1,"type":"hash",
"value":{"title":"article1","user_id":"57fc62651d41c873ba6c880c"},...}
{% endhighlight %}

Now we can loop through `Comments` but instead of using regular relationships `c.article.body` and `c.article.user.name` (which would have caused DB queries) we are fetching data attributes from records pre-fetched and stored in Redis.  

{% highlight ruby %}
#	app/services/report.rb
Comment.recent.each do |c|
	# => find article in Redis
	key_a = ['Article', c.article_id].join(':')
	#	http://www.rubydoc.info/github/ezmobius/redis-rb/Redis#hgetall-instance_method
	art = REDIS.hgetall(key_a)
	# => find user in Redis
	key_u = ['User', art['user_id']].join(':')
	user = REDIS.hgetall(key_u)
	puts [c.body, art['title'], user['name']].join(',')
end
{% endhighlight %}

Now we need to remove these temporary records.  
{% highlight ruby %}
REDIS.del("*")
{% endhighlight %}

We also can combine this approach with `includes(:article)` and only use Redis for User records temp storage.  This approach can work when you are querying for records from two separate DBs and have to combine results.  Fetch each dataset separately and store them.  Then use Redis as extension of your memory / data structures.  

https://github.com/ElMassimo/mongoid_includes
https://github.com/nateware/redis-objects


{% highlight ruby %}
{% endhighlight %}


{% highlight ruby %}
{% endhighlight %}
