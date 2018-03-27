[Ruby on Rails](http://rubyonrails.org/) is a useful framework for quickly building line of business applications.  But as our applications grow we face scaling challenges.  There are a variety of tools we can use but adding different technologies to our applications increases complexity.  In this article we will explore how [Redis](https://redis.io/) can be used as a multi-purpose tool to solve different problems.  

First need to install Redis which can be done with either `brew`, `apt-get` or `docker`.  And of course we need to have Ruby on Rails.  As a POC we will build an online event management application.  Here are the basic models.  

```
<code>
class User < ApplicationRecord
  has_many :tickets
end
class Event < ApplicationRecord
  has_many :tickets
end
class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :event
end
</code>
```

### Redis as a cache

The first requirement is to show how much money a specific event received and how many tickets it sold.  We will create these methods.  

```
<code>
class Event < ApplicationRecord
  def tickets_count
    tickets.count
  end
  def tickets_sum
    tickets.sum(:amount)
  end
end
</code>
```

This code will fire SQL queries against our DB to fetch the data.  The problem is with scale this may become slow.  To speed things up we can cache results of these methods.  First we enable caching with Redis for our application.  Add `gem 'redis-rails'` to Gemfile and run `bundle install`.  In `config/environments/development.rb` configure

```
<code>
config.cache_store = :redis_store, {
  expires_in: 1.hour,
  namespace: 'cache',
  redis: { host: 'localhost', port: 6379, db: 0 },
  }
</code>
```

Specifying `cache` namespace is optional but it helps.  This also sets the default application level expiration of 1 hour which will use Redis TTL to purge stale data.  Now we can wrap our methods in `cache` blocks.  

```
<code>
class Event < ApplicationRecord
  def tickets_count
    Rails.cache.fetch([cache_key, __method__], expires_in: 30.minutes) do
      tickets.count
    end
  end
  def tickets_sum
    Rails.cache.fetch([cache_key, __method__]) do
      tickets.sum(:amount)
    end
  end
end
</code>
```

`Rails.cache.fetch` will check if specific key exists in Redis.  If the key exists, it will return value associated with the key to the application and NOT execute the code.  If the key does not exists, Rails will run the code within the block and store data in Redis.  `cache_key` is a method provided by Rails that will combine model name, primary and last updated timestamp to create a unique Reds key.  We are adding `__method__` which will use name of specific method to further uniquify the keys.  And we can optionally specify different expiration on some methods.  Data in Redis will look like this.  

```
<code>
{"db":0,"key":"cache:events/1-20180322035927682000000/tickets_count:","ttl":1415, "type":"string","value":"9",...}
{"db":0,"key":"cache:events/1-20180322035927682000000/tickets_sum:","ttl":3415, "type":"string","value":"127",...}
{"db":0,"key":"cache:events/2-20180322045827173000000/tickets_count:","ttl":1423, "type":"string","value":"16",...}
{"db":0,"key":"cache:events/2-20180322045827173000000/tickets_sum:","ttl":3423, "type":"string","value":"211",...}
...
</code>
```

In this situation event with ID 1 sold 9 tickets totaling $127 and event 2 sold 16 tickets totaling $211.  

#### Cache busting

But what if another ticket is sold right after we cache this data?  Currently the website will show cached content until Redis purges these keys with TTL.  It might be OK in some situations to show stale content but in this case we want to show the current data.  This is where the last updated timestamp is used.  We will specify a `touch: true` callback from child model (ticket) to parent (event).  Rails will touch `updated_at` timestamp which will force creation of new `cache_key` for `event` model.  

```
<code>
class Ticket < ApplicationRecord
  belongs_to :event, touch: true
end
// data in Redis
{"db":0,"key":"cache:events/1-20180322035927682000000/tickets_count:","ttl":1799,
  "type":"string","value":"9",...}
{"db":0,"key":"cache:events/1-20180322035928682000000/tickets_count:","ttl":1800,
  "type":"string","value":"10",...}
...
</code>
```

The pattern is that once we create a combination of cache key and content we do not change it.  We create new content with new key and previously cached data remains in Redis until TTL purges it.  This does waste some Redis RAM but it simplifies our code.  We do not need to write special callbacks to purge and regenerate cache.  

We need to be careful in selecting our TTL because if our data changes frequently and TTL is long then we are storing too much unused cache.  If the data changes infrequently but TTL is too short we are regenerating cache even when it did not change.  Here is a short [article](http://dmitrypol.github.io/redis/2017/05/25/rails-cache-variable-ttl.html) I wrote with a few suggestions.  

Note of caution - caching should not be a bandaid solution.  We should look for ways to write efficient code and optimize DB indexes.  But sometimes caching is still necessary and can be a quick solution to buy time for a more complex refactor.  

### Redis as a queue

The next requirement is to generate reports for one or multiple events showing detailed stats on how much money they received and listing the individual tickets with the user info.

```
<code>
class ReportGenerator
  def initialize event_ids
  end
  def perform
    // query DB and output data to XLSX
  end
end
</code>
```

Generating these reports may be slow as data needs to be gathered from multiple tables.  Instead of making users wait for the response and downloading the spreadsheet we can turn it in a background job and send email with either attachment or link to the file.  

Ruby on Rails has ActiveJob framework which can use variety of queues.  In this example we will leverage Sidekiq library which stores data in Redis.  Add `gem 'sidekiq'` to Gemfile and run `bundle install`.  We will also use `sidekiq-cron` gem to schedule recurring jobs.  

```
<code>
// in config/environments/development.rb
config.active_job.queue_adapter = :sidekiq
// in config/initializers/sidekiq.rb
schedule = [
  {'name' => MyName, 'class' => MyJob, 'cron'  => '1 * * * *',  
  'queue' => default, 'active_job' => true }
]
Sidekiq.configure_server do |config|
 config.redis = { host:'localhost', port: 6379, db: 1 }
 Sidekiq::Cron::Job.load_from_array! schedule
end
Sidekiq.configure_client do |config|
 config.redis = { host:'localhost', port: 6379, db: 1 }
end
</code>
```

Note that we are using a different Redis DB for Sidekiq.  It is not a requirement but it is can be useful to store cache in separate Redis DB (or even on a different server) in case we need to flush it.  

And we can create another config file for Sidekiq  to specify which queues it should watch.  We do not want to have too many queues but having only one queue can lead to situations where it gets clogged with low priority jobs and then a high priority job is delayed.  In `config/sidekiq.yml`

```
<code>
---
:queues:
  - [high, 3]
  - [default, 2]
  - [low, 1]
</code>
```

Now we create the job.  We will specify low priority queue.

```
<code>
class ReportGeneratorJob < ApplicationJob
  queue_as :low
  self.queue_adapter = :sidekiq  
  def perform event_ids
    // either call ReportGenerator here or move the code into the job
  end
end
</code>
```

We can optionally set different queue adapter.  ActiveJob allows us to use different queue backends for different jobs within the same application.  We can have jobs that need to run millions of times per day.  Redis could handle it but we might want to use a different service like AWS SQS.  Here is an [article](http://dmitrypol.github.io/redis/rabbitmq/sqs/2017/12/17/queues.html) I wrote comparing different queues.

Sidekiq takes advantage of many Redis data types.  It uses Lists to store jobs which makes queuing really fast.  It uses Sorted Sets to delay job execute (either specifically requested by application or when doing exponential backoff on retry).  Redis Hashes store statistics on how many jobs were executed and how long they took.  

Recurring jobs are also stored in Hashes.  We could have used plain Linux cron to kick off the jobs but that would introduce a single point of failure into our system.  With Sidekiq-cron the schedule is stored in Redis and any of the servers where Sidekiq workers run can execute the job (the library ensures that only one worker will grab a specific job at scheduled time).  Sidekiq also has a great UI where we can view various stats and either pause scheduled jobs or execute them on demand.  

### Redis as a database

The last business requirement is to track how many visits there are to each event page so we can determine their popularity.  For that we will use Sorted Sets.  We can either create the `REDIS_CLIENT` directly to call native Redis commands or use Leaderboard gem which provides additional features.

```
<code>
// config/initializers/redis.rb
REDIS_CLIENT = Redis.new(host: 'localhost', port: 6379, db: 1)
// config/initializers/leaderboard.rb
redis_options = {:host => 'localhost', :port => 6379, :db => 1}
EVENT_VISITS = Leaderboard.new('event_visits', Leaderboard::DEFAULT_OPTIONS, redis_options)
</code>
```

Now we can call it from controller show action.  

```
<code>
class EventsController < ApplicationController
  def show
    ...
    REDIS_CLIENT.zincrby('events_visits', 1, @event.id)
    // or
    EVENT_VISITS.change_score_for(@event.id, 1)
  end
end
// data in Redis
{"db":1,"key":"events_visits","ttl":-1,"type":"zset","value":[["1",1.0],...,["2",4.0],["7",22.0]],...}
</code>
```

Adding items to a Sorted Set does slow down eventually when we have millions of Sorted Set members but for most use cases Redis is plenty fast.  We can now use this Sorted Set to determine `rank` and `score` of each event.  Or we can display the top 10 events with `REDIS_CLIENT.zrange('events_visits', 0, 9)`.  

Since we are using Redis to store very different types of data (cache, jobs, etc) we need to be careful not to run out of RAM.  Redis will evict keys on it's own but it cannot tell a difference between a key holding stale cache vs something important to our application.  

Hopefully this article was a useful into into how Redis can be used for variety of purposes in a Ruby on Rails application.  

### Links
* Method level caching http://guides.rubyonrails.org/caching_with_rails.html#low-level-caching
* Redis TTL https://redis.io/commands/ttl
* ActiveJob http://guides.rubyonrails.org/active_job_basics.html
* Sidekiq https://sidekiq.org
* Sidekiq-cron https://github.com/ondrejbartas/sidekiq-cron
* Leaderboard gem https://github.com/agoragames/leaderboard
* https://redis.io/topics/lru-cache
* Redis LUR http://antirez.com/news/109
