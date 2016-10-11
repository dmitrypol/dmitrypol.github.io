---
title: "Redis cache objects"
date: 2016-10-10
categories: redis
---

SQL joins are a very powerful feature allowing you to use DB functionality to bring back the records you need w/o making multiple queries.  Unfortunately some the new NoSQL DBs do not support it.  

We have been using [MongoDB](http://mongodb.com) for several years and overall really like it.  

Except that often we have to do N+1 queries looping through child records and fetching data attributes from the parent or grand-parent record.  Let's think through hypothetical CMS application.  

{% highlight ruby %}
class User
  has_many :articles
end
class Article
  belongs_to :user
  has_many :comments
end
class Comment
  belongs_to :article
  scope :recent, ->{ gte(created_at: Date.yesterday)  }
end
{% endhighlight %}

Now we need to generate a report of User names and Article titles who wrote Articles that have recent Comments.  If it were a one-step relationship we would have done `Comment.recent.includes(:article)` but due to MongoDB not supporting joins it ends up querying for EACH User name separately.  

What if could featch all the comments, then fetch their Articles and then fetch correspond User records.  It would be 3 queries instead of 1 (as we could do with a good SQL join) but it is better than N+1.  

{% highlight ruby %}
article_ids = Comment.recent.pluck(:article_id)
user_ids = Article.in(id: article_ids).pluck(:user_id)
articles = Article.in(id: article_ids).only(:title)
users = User.in(id: user_ids).only(:name)
# we do not need all User and Article attributes so we specify the fields
{% endhighlight %}

But where do we store the User and Article records as we loop through Comments while generating our report?  How about quickly throwing them into Redis as Hashes?

{% highlight ruby %}

{% endhighlight %}


https://github.com/ElMassimo/mongoid_includes
https://github.com/nateware/redis-objects
