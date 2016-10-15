---
title: "Storing ephemeral data in Redis"
date: 2016-09-14
categories: redis
redirect_from:
  - /2016/09/14/redis_tmp_data.html
---

Usually our applications have a DB (MySQL, Postgres, etc) that we use to permanently store information about our users and other records.  But there are also situations where we need to temporary store data used by a background process.  This data might be structured very differently and would not fit into our relational DB.

Recently we were doing large scale analysis in our system (built on Rails 4.2 framework) to determine which users might have duplicate records.  Long story why we have such records but I assure you there is a legitimate reason.  What we needed was a process that would flag likely duplicates so humans could make a decision on whether to merge them or not.  

As "unique" identifier for likely users we decided to use combination of "first_name last_name".  Obviously we knew that there would be many false positives but this was a starting point.  In reality our business logic was much more complex but I am omitting many confidential details.  

We decided to use Redis to store the ephemeral data as we were running the analysis.  For that we created a Redis connection with separate key namespace 'record_match'.  

{% highlight ruby %}
  # config/initializers/redis.rb
  redis_conn = Redis.new(host: Rails.application.config.redis_host, port: 6379, db: 0, driver: :hiredis)
  REDIS_RM = Redis::Namespace.new('record_match', redis: redis_conn )
{% endhighlight %}

We created a PORO service object.
{% highlight ruby %}
# app/services/record_match_service.rb
class RecordMatchService
  def perform
    REDIS_RM.del("*") # cleanup before just in case
    compare_records
    remove_uniques
    process_results
    REDIS_RM.del("*") # cleanup after
  end
private
  def compare_records
    ...
  end
  def remove_uniques
    ...
  end
  def process_results
    ...
  end
end
{% endhighlight %}

One issue to be aware of is `REDIS_RM.del("*")` will cause problems if there are 2 separate analysis processes running at the same time.  

First we loop through all user records creating "unique" first and last name combinations.  Then we use [Redis SET datatype](http://redis.io/commands/sadd) to store user IDs.  SET guarantees uniqueness of its members.
{% highlight ruby %}
def compare_records
  User.all.each do |user|
    key = [user.first_name, user.last_name].join(' ').downcase
    member = user.id
    REDIS_RM.sadd(key, member)
  end
end
{% endhighlight %}

Results will look like this when stored in Redis:
{% highlight ruby %}
KEY 'john smith', MEMBERS [id1, id2, id3]  # potential dupes
KEY 'mary jones', MEMBERS [id4] # unique user
{% endhighlight %}

Now we go through Redis keys and delete them if there is only 1 user ID in the SET (unique records).  This could be combined with `process_results` to make code a little faster (no need to loop through all Redis keys and check SET size).
{% highlight ruby %}
def remove_uniques
  REDIS_RM.keys.each do |key|
    REDIS_RM.del(key) if REDIS_RM.scard(key).to_i == 1
  end
end
{% endhighlight %}

Then we loop through remaining keys and members in the SETs to create `potential match` records in the main DB.  These `potential match` records will go through the manual review process and corresponding user records could then be merged (or not).  All MEMBERS in each SET need unique comparisons to each other.  SET with key `john smith` and members `[id1, id2, id3]` will become 3 separate records comparing `id1 to id2`, `id1 to id3` and `id2 to id3`.

{% highlight ruby %}
def process_results
  REDIS_RM.keys.each do |key|
    while REDIS_RM.scard(key).to_i > 1
      # => grab random member from the SET
      user1_id = REDIS_RM.spop(key)
      # => loop through remaining members in the SET
      REDIS_RM.smembers(key).each do |user2_id|
        PotentialMatch.create_match(user1_id: user1_id, user2_id: user2_id)
      end
    end
  end
end
{% endhighlight %}

We store the user ID comparisons in the main DB is because that dataset is much smaller in size so it does not take very long to persist to disk .  Plus we want to use relational DB validations and the data structure fits into our DB model.  

{% highlight ruby %}
class PotentialMatch  < ApplicationRecord
  belongs_to :user1, class_name: 'User', index: true, inverse_of: nil
  belongs_to :user2, class_name: 'User', index: true, inverse_of: nil
  def self.create_match (user1_id: user2_id:)
    # logic to check if this record already exists
    # create records in main DB for human review
  end
end
{% endhighlight %}

And we wrap `RecordMatchService` into `RecordMatchJob` with [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) and [Sidekiq](https://github.com/mperham/sidekiq).  Even with fast Redis data structures the process can still take many minutes to run.  
{% highlight ruby %}
class RecordMatchJob < ApplicationJob
  queue_as :low
  def perform
    RecordMatchService.new.perform
  end
end
{% endhighlight %}

Here are the various Ruby gems we used:
{% highlight ruby %}
  # Gemfile
  gem 'redis'
  gem 'hiredis'
  gem 'redis-namespace'
  gem 'readthis'
{% endhighlight %}

The examples above do not go deep into actual details but instead focus on the usage of Redis and its flexible and fast data structures.  
