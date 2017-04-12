---
title: "What is the right size for background jobs?"
date: 2017-04-11
categories: redis sidekiq
---

In previous [post]({% post_url 2017-03-27-redis-cache-pregen %}) I wrote about pre-generating cache via [background jobs](http://guides.rubyonrails.org/active_job_basics.html).  I described an example of an online banking app where we pre-generate cache of `recent_transactions`.  This helps even load on the system by pushing some of the data into cache before visitors come to the site.  

* TOC
{:toc}

### One job for all records

The simplest design is to loop through all records in one job.  

{% highlight ruby %}
class SomeModel
  def some_method
    Rails.cache.fetch([cache_key, __method__]) do
      # code here
    end    
  end
end
class PreGenerateCacheJob < ApplicationJob
  def perform
    SomeModel.some_filter.each do |record|
      record.some_method
    end
  end
end
{% endhighlight %}

The downside of this approach is that if we have millions of `MyModel` records it can take a very long time for this job to complete.  And what if we need to deploy code which restarts background job workers?  We won't know which records have been processed and which have not.  [Best practices](https://medium.com/handy-tech/sidekiq-best-practices-cbc2d070a7d4) for background jobs recommend keeping them small and [idempotent](http://stackoverflow.com/questions/1077412/what-is-an-idempotent-operation).  

### One job for each record

We can queue one job per record by separating our code into two jobs.  

{% highlight ruby %}
class EnqueuePreGenerateCacheJob < ApplicationJob
  def perform
    SomeModel.some_filter.each do |record|
      PreGenerateCacheJob.perform_later(record: record)
    end
  end
end
class PreGenerateCacheJob < ApplicationJob
  def perform(record:)
    record.some_method
  end
end
{% endhighlight %}

Each job will complete very quickly and they will run in parallel.  Since it is not recommended to serialize complete objects into queue we will use some kind of record identifier (like [globalid](https://github.com/rails/globalid)).  But this will cause lot of queries against the primary DB to look up records one at a time.  

### Loop through records in slices

And now we come to the Goldilocks solution - not too big and not too small.  We want to break up the process into smaller chunks but instead of processing one record at a time we will process several (let's say 10).  

{% highlight ruby %}
class EnqueuePreGenerateCacheJob < ApplicationJob
  def perform
    model_ids = SomeModel.some_filter.pluck(:id)
    model_ids.each_slice(10) do |ids_slice|
      PreGenerateCacheJob.perform_later(record_ids: ids_slice)
    end
  end
end
class PreGenerateCacheJob < ApplicationJob
  def perform(record_ids:)
    # query for 10 records at a time
    records = MyModel.where(id: record_ids)
    records.each do |record|
      record.some_method
    end
  end
end
{% endhighlight %}

One downside of this approach is that `pluck` will request IDs for ALL records from the primary DB.  Then it will store them in array and loop through them.  Different ORMs support `batch_size` for querying records so we can do equivalent of `select id from TableName limit 10 offset ...`.  

### Different queues and workers

The same approach can be applied to other situations (not just cache pre-generating).  When a record is created/updated we might have a callback (previous [post](2017-03-26-callbacks-background-jobs)) to update various reports.  The primary `UpdateReportsJob` will be called from `after_save` [callback](http://api.rubyonrails.org/classes/ActiveModel/Callbacks.html).  We want it to complete as quickly as possibly and queue separate `UpdateEachReportJob` passing appropriate report ID.  We can process these jobs through separate [queues](http://edgeguides.rubyonrails.org/active_job_basics.html#queues).  

{% highlight ruby %}
class UpdateReportsJob < ApplicationJob
  queue_as :high  # must be processed right away
  def perform
    UpdateEachReportJob.perform_later(report_id: some_id)
  end
end
class UpdateEachReportJob < ApplicationJob
  queue_as :low   # lots of small jobs that may take longer to complete
  def perform(report_id:)
    # code here
  end
end
{% endhighlight %}

We can even assign dedicated [Sidekiq](http://sidekiq.org/) workers to watch only specific queues.  Here is sample configuration for [capistrano-sidekiq](https://github.com/seuros/capistrano-sidekiq):

{% highlight ruby %}
# deploy.rb
set :sidekiq_processes, 4
set :sidekiq_options_per_process, [
  "--queue high",
  "--queue default --queue low",
  "--queue default --queue low",
  "--queue default --queue low",
]
{% endhighlight %}

This way each server will have a dedicated process watching only the `high` queue to ensure that those jobs complete as quickly as possible and not get backlogged.  The other three workers will process the `default` (used for other jobs) and `low` queues (used for reports).
