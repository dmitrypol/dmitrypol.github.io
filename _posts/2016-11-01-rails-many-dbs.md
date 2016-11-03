---
title: "Rails with many different DBs"
date: 2016-11-01
categories: rails redis mongo
redirect_from:
  - /rails/redis/mongo/mysql/2016/11/01/rails-many-dbs.html
---

It is easy to find articles online debating pros and cons of different databases.  Often they have titles like "Why you should never use X DB".  And yes, different databases have different strengths and weaknesses.  Choosing a DB that does not fit the long term needs can be a costly decision.

The question I'd like to ask is why should we choose?  Why can't we use different databases w/in the same application for different purposes?  Obviously it introduces additional complexity into our code and ops infrastructure but it can be a tremendous benefit too.  We can use [MySQL](https://www.mysql.com/) as the main relational database but leverage [Redis](http://redis.io/) for caching and [MongoDB](https://www.mongodb.com/) for advanced data aggregation.

Let's imagine we are building a blogging platform with [Ruby on Rails](http://rubyonrails.org/).  We will have UI where users can manage their profiles, create articles, etc.  We also need a separate publishing server that can display millions of pages per day.  And we need a service to run various background processes, generate reports, aggregate page views, etc.

Disclaimer - this post will cover topics (caching, microservices, background jobs) that I already discussed in preivous articles.  But instead of going into details I want to focus on combining various approaches.

* TOC
{:toc}

### MySQL

SQL gives us a very rich ecosystem of various other gems/libraries that work with it.  Ability to use Joins and Transactions is crucial for many applications.  It is supported by various cloud providers such as [Google](https://cloud.google.com/sql/) and [AWS](https://aws.amazon.com/rds/mysql/).  We have been using MongoDB with [Mongoid](https://docs.mongodb.com/ruby-driver/master/mongoid/#ruby-mongoid-tutorial) extensively and while it's ecosystem is broad, we sometimes encounter gems that only work with [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html).

In our UI we need to have basic things like authentication, authorization, admin CRUD, etc. We can choose  [RailsAdmin](https://github.com/sferik/rails_admin) or [Administrate](https://github.com/thoughtbot/administrate) for CRUD,  [pundit](https://github.com/elabs/pundit) or [cancancan](https://github.com/CanCanCommunity/cancancan) for authorization, [devise](https://github.com/plataformatec/devise) or [clearance](https://github.com/thoughtbot/clearance) for authentication.  [counter_culture](https://github.com/magnusvk/counter_culture) helps us create powerful cache counters right in our DB.  

{% highlight ruby %}
# app/models/user.rb
class User < ApplicationRecord
  # has name, email, articles_count
  has_many :articles
end
# app/models/article.rb
class Article < ApplicationRecord
  # has title, body
  belongs_to :user, counter_cache: true
end
{% endhighlight %}

### Redis

To scale our platform we can implement [caching](http://guides.rubyonrails.org/caching_with_rails.html).  

{% highlight ruby %}
# config/environments/production.rb
config.action_controller.perform_caching = true
config.cache_store = :readthis_store, { expires_in: 1.hour,
  namespace: 'cache', redis: { host: 'localhost', port: 6379, db: 0 } }
# app/views/articles/show.html.erb
<% cache @article do %>
  <p>
    <strong>Title:</strong>
    <%= @article.title %>
  </p>
  <p>
    <strong>Body:</strong>
    <%= @article.body %>
  </p>
<% end %>
{% endhighlight %}

That will cache entire page.  We can also implement method level caching (modify Article `belongs_to :user` to have `touch: true` to bust cache):

{% highlight ruby %}
# app/models/user.rb
def article_word_count
  Rails.cache.fetch([cache_key, __method__]) do
    articles.map{|a| a.body.split.size}.sum
  end
end
{% endhighlight %}

When publishing server loads a page it can throw a background job (via [Sidekiq](https://github.com/mperham/sidekiq) or [Resque](https://github.com/resque/resque)) into Redis to update page views counters.

{% highlight ruby %}
# app/controllers/article_controller.rb
def show
  ArticleShowJob.perform_later(article_id: params[:id], time: Time.now.to_i)
end
# app/jobs/article_show_job.rb
class ArticleShowJob < ApplicationJob
  queue_as :low
  def perform(*args)
    ...
  end
end
{% endhighlight %}

We can also use Redis to store data, for example to count unique visitors (combination of IP and UserAgent).  We do not even need a background job since Redis is very fast.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_CONN = Redis.new(host: 'localhost', port: 6379, db: 0)
# app/controllers/article_controller.rb
def show
  UniqueVisitor.new.perform(request.remote_ip, request.user_agent)
end
# app/services/unique_vistor.rb
class UniqueVisitor
  def perform(ip, user_agent)
    REDIS_CONN.incr Base64.encode64("#{ip}:#{user_agent}")
  end
end
# Redis counters
{"db":0,"key":"MTI3LjAuM ... ","ttl":-1,"type":"string","value":"5","size":1}
{"db":0,"key":"A43IQpjuF ... ","ttl":-1,"type":"string","value":"2","size":1}
...
{% endhighlight %}

We do not need to limit ourselves to just one Redis server.  We could use one for caching, another for background jobs and third for data storage.  We could even implement application level data sharding.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS1 = Redis.new(host: 'server1', port: 6379, db: 0)
REDIS2 = Redis.new(host: 'server2', port: 6379, db: 0)
...
# app/services/redis_shard.rb
class RedisShard
  def initialize
  end
  def perform
    shard_numer = X # some code here
    # => get the Redis connection to the right shard
    redis = "REDIS#{shard_nubmer}".constantize
    redis.set ...
  end
end
{% endhighlight %}

### MongoDB

Ability to have flexible schema and aggregate data in one document is a useful tool.  And with Mongo (unlike Redis) we can query by values.  Our `ArticleShowJob` can push data using Mongo Ruby [driver](http://api.mongodb.com/ruby/current/) into Mongo `page_views` collection (we are NOT using an ORM like Mongoid).

{% highlight ruby %}
# config/initializers/mongo.rb
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'blog_stats')
PAGE_VIEWS = client[:page_views]
# app/jobs/article_show_job.rb
def perform(article_id, time)
  date = time.strftime("%Y/%m/%d")
  PAGE_VIEWS.find_one_and_update({ article_id: article_id}, {'$inc' => { "#{date}": 1} }, :upsert => true )
end
# data in Mongo
{
    "_id" : ObjectId("553fbbc569702d393e030000"),
    "article_id" : 1,
    "2016/10/31" : 1,
    "2016/11/01" : 2,
    ...
}
{% endhighlight %}

We are using Mongo [upsert](http://api.mongodb.com/ruby/current/Mongo/Collection.html#find_one_and_update-instance_method) (update/insert) feature will create a document if it doesn't exist.  Then it will increment a specific field in the document for the date in question.  

To display data in our reporting dashboard we can do this:
{% highlight ruby %}
# app/controllers/articles_controller.rb
def stats
  # or use Mongo projection to exclude article_id and _id
  @page_stats = PAGE_VIEWS.find(article_id: @article.id.to_s)
    .first.except(:_id, :article_id)
end
# app/views/articles/stats.html.erb
<% @page_stats.each do |stat| %>
  <tr>
    <td><%= stat.split(':').first %></td>
    <td><%= stat.split(':').second %></td>
  </tr>
<% end %>
{% endhighlight %}

We can aggregate data on which domains are driving our traffic, which IPs users are coming from, etc.  We can create different collections in Mongo for grouping this data by different time periods (daily vs. monthly) and then use Mongo [TTL indexes](https://docs.mongodb.com/v3.2/core/index-ttl/) to purge old records.

Similar as with multiple Redis servers above we could talk to different Mongo servers, databases or collections.

{% highlight ruby %}
# config/initializers/mongo.rb
client1 = Mongo::Client.new([ 'server1:27017' ], :database => 'db1')
COL1 = client1[:collection1]
client2 = Mongo::Client.new([ 'server2:27017' ], :database => 'db2')
COL2 = client2[:collection2]
{% endhighlight %}

I hope the ideas above were a useful overview.  As I said at the beginning of this post, I did not go into the details but focused on general design.  This approach can be used to integrate Rails apps with other DBs ([Neo4j](https://neo4j.com/), [RethinkDB](https://www.rethinkdb.com/), etc).
