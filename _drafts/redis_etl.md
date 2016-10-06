---
title: "Redis and ETL"
date: 2016-10-05
categories: redis
---

Frequently your application captures highly volatile data in [Redis](http://redis.io/) but you also need to [ETL](https://en.wikipedia.org/wiki/Extract,_transform,_load) some of those data points to a different DB or data warehouse.  Due to Redis speed you can change the same value (increment a counter) tens of thousands of times per second but you can't (and don't really need to) make the same updates in your SQL DB (where data is persisted to disk).  

What you often need is to keep your SQL DB in [near real-time](https://en.wikipedia.org/wiki/Real-time_computing#Near_real-time) sync with Redis.  Your business users might not care if this data is 10-15 minutes delayed.  So how would you design such a system?  Examples below are using [Ruby on Rails](http://rubyonrails.org/) framework.

### From Redis

Let's imagine a blogging platform system where you are tracking [unique visitors](https://en.wikipedia.org/wiki/Unique_user#Unique_visitor) and you want to give different experience to new vs. returning visitors.  For example, [comScore](https://www.comscore.com) tracks unique monthly visitors using combination of IP and [user agent](https://en.wikipedia.org/wiki/User_agent).  In a preivous job I helped built very similar feature.  

You can take IP & UserAgent and hash the string using something like [MurmurHash](https://en.wikipedia.org/wiki/MurmurHash) using this [gem](https://github.com/ksss/digest-murmurhash).  

{% highlight ruby %}
# config/initializers/redis.rb
redis_conn = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
REDIS_VISIT_COUNT =  Redis::Namespace.new('vst', redis: redis_conn)
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :return_visitor_check
private
  def return_visitor_check
    key = Digest::MurmurHash1.hexdigest "#{request.remote_ip}:#{request.user_agent}"
    @returning_visitor = true if REDIS_VISIT_COUNT.get(key).present?
    REDIS_VISIT_COUNT.pipelined do
      REDIS_VISIT_COUNT.incr key
      REDIS_VISIT_COUNT.expireat(key, Time.now.end_of_month.to_i)
    end
  end
end
{% endhighlight %}

`return_visitor_check` will be extremely fast thanks to Redis speed.  And now you can use `if @returning_visitor == true` in your controllers or view templates.  Data will be automatically purged at the end of the month using [Redis TTL](http://redis.io/commands/ttl).  

So the feature works great.  But let's say our business users need to see how many total visitors site had that month and how many of them were returning.  And they want to see this data by date.  For that you want to aggregate those records separately in Redis using different namespace.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_VISIT_COUNT_DATE =  Redis::Namespace.new('vst_date', redis: redis_conn)
# app/controllers/application_controller.rb
def return_visitor_check
  ...
  REDIS_VISIT_COUNT_DATE.pipelined do
    # separately aggregate stats by date
    date = Time.now.strftime("%Y%m%d")
    key_date = "#{key}:#{date}"
    REDIS_VISIT_COUNT_DATE.incr key_date
    REDIS_VISIT_COUNT_DATE.expire(key_date, Time.now.end_of_month.to_i)
  end
end
{% endhighlight %}

Then you need to move it to our SQL DB.  [Sidekiq](https://github.com/mperham/sidekiq) is a great library for running background jobs and it also uses Redis.  You can wrap it in [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) and use [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron) to run the process every 15 minutes.  In SQL DB you will have `Visits` table with `date`, `total_count` and `unique_count` columns.

{% highlight ruby %}
# app/modles/visitors/rb
class Visit < ApplicationRecord
end
# app/jobs/vist_count_job.rb
class VisitCountJob < ApplicationJob
  queue_as :low
  # can run this job manually and specify a date  20161005
  def perform
    VisitCount.new.perform
  end
end
# app/services/visit_count.rb
class VisitCount
  def initialize(date = Time.now.strftime("%Y%m%d"))
    @date = date
  end
  def perform
    total_count = 0
    unique_count = 0
    # grab keys that match pattern for today's date
    REDIS_VISIT_COUNT_DATE.keys("*:#{@date}").each do |key|
      value = REDIS_VISIT_COUNT_DATE.get(key)
      total_count += value
      unique_count += 1
    end
    # persist data
    v = Visit.where(date: date).first_or_create
    v.update(total_count: total_count, unique_count: unique_count)
  end    
end
{% endhighlight %}

You need to create a couple Sidekiq config files.  Since this ETL process is not very time sensitive you can put it in `low` priority queue so jobs in `default` and `high` queues will be processed first.  

{% highlight ruby %}
# config/sidekiq.yml
---
:queues:
  - [high, 4]
  - [default, 2]
  - [low, 1]
# config/initializers/sidekiq.rb
schedule_array =
[
  {'name' => 'VisitCountJob',
    'class' => 'VisitCountJob',
    'cron'  => '*/15 * * * *',
    'queue' => 'low',
    'active_job' => true },
]
Sidekiq.configure_server do |config|
  config.redis = { host: 'localhost', post: 6379, db: 0, namespace: 'sidekiq' }
  Sidekiq::Cron::Job.load_from_array! schedule_array
end
Sidekiq.configure_client do |config|
  config.redis = { host: 'localhost', post: 6379, db: 0, namespace: 'sidekiq' }
end
{% endhighlight %}

But what if you don't want that 15 minute delay?  Why not wrap that `VisitCount` class in a [daemon](https://github.com/thuehlinger/daemons) running w/in your application?  A couple of useful articles [here](http://michalorman.com/2015/03/daemons-in-rails-environment/) and [here](http://codeincomplete.com/posts/ruby-daemons/).  

{% highlight ruby %}
# lib/redis_etl.rb
class RedisEtl
  def perform
    while true
      VisitCount.new.perform
      sleep(1)
    end
  end
end
{% endhighlight %}

### Into Redis

There are also times when you use Redis to store certain configuration values or cached data.  Redis will have no problem keeping up with updates made in relational DB (which have to be persisted to disk) so latency is unlikely to be an issue.  Often the simplest choice is to implement default framework [caching](http://guides.rubyonrails.org/caching_with_rails.html)

{% highlight ruby %}
class MyClass
  def my_method
    cache_key = # derive something from object class, ID & timestamp or build your own
    Rails.cache.fetch([cache_key, __method__, self.class.name]) do
      ...
    end  
  end
end
{% endhighlight %}

Another option is to use [model callbacks](http://api.rubyonrails.org/classes/ActiveModel/Callbacks.html).  

{% highlight ruby %}
# config/initializers/redis.rb
redis_conn = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
REDIS = Redis::Namespace.new('my_namespace', redis: redis_conn)
# app/models/article.rb
class Article < ApplicationRecord
  after_save :update_redis
private
  def update_redis
    # here you are directly accessing Redis API
    REDIS.something here
  end
{% endhighlight %}

And you could use a background job.  Let's say your application has a feature that enables internal admin to fetch data from remote FTP server and update records stored in Redis.  You can see how logic is separated in different classes and can be tested individually.

{% highlight ruby %}
# app/controllers/my_controller.rb
class MyController < ApplicationController
  def update_cache
    UpdateRedisJob.perform_later
    render status: 200
  end
end
# app/jobs/update_redis_job.rb
class UpdateRedisJob < ApplicationJob
  def perform
    # grab the file and process each row
    CSV.parse(File.read('...'), headers: true).each do |row|
      key = something
      value = Etl.new.perform(row)
      REDIS.del(key)
      REDIS.hmset(key, value)
    end
  end
end
# app/services/etl.rb
class Etl
  def initialize
  end
  def perform row
    row2 = # biz logic here to transform data into some kind of hash
    return row2
  end
end
{% endhighlight %}

### Daemonize

Methods for Extract, Tranform, Load called from Perform

### From Redis to Redis

### Ruby ETL tools



This article was inspired by [mosql](https://github.com/stripe/mosql) but I could not think of a way to extract these ideas into a gem.  There is also [Pentaho ETL tools](https://github.com/mattyb149/pdi-redis-plugin) for Redis but does not seem be maintained.  
