---
title: "Sidekiq batches"
date: 2016-03-18
categories: redis sidekiq
---

Recently I was finally able to implement background job importer (see previous post on Importing LOTS of data).  It proved to be very interesting and challenging.  I have been successfully running Sidekiq in production for several months but only individual jobs.  For this I needed to run job batches, temporarily store results of each job and email results when all jobs were done.

[Sidekiq Pro](http://sidekiq.org/products/pro) supports concept of batches but we did not need all the extra features.  Plus batching was only part of our challenge.  I also came cross [active_job_status](https://github.com/cdale77/active_job_status) gem but did not use it.  So here is the solution that I went with.

When user uploads a spreadsheet with records I parse it one row at a time and queue up each job.  But first I setup these batch parameters:

{% highlight ruby %}
def setup_batch_params num_rows, current_user
  @batch_id = "#{Time.now.to_i}_#{current_user.id}"
  REDIS.set("#{@batch_id}:size", batch_size) # total size
  REDIS.set("#{@batch_id}:counter", batch_size) # decremented by each job
  REDIS.set("#{@batch_id}:owner", current_user.email) # email results to
end
{% endhighlight %}

After processing each row of data I get results and run this code.  This could be called via [after_perform](http://edgeapi.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_perform) ActiveJob callback
{% highlight ruby %}
def after_process_row row, result
  # result could be success or error, store data in Redis lists
  REDIS.rpush("#{@batch_id}:#{result}", row.to_json)
  # decrement batch_counter
  REDIS.decr(@batch_counter)
  # check if batch_size is 0, last job completed
  after_process_batch if REDIS.get("#{@batch_id}:counter").to_i <= 0
end
{% endhighlight %}

I used [axlsx](https://github.com/randym/axlsx) gem to create output XLSX file with success_sheet and error_sheet.
{% highlight ruby %}
def after_process_batch
  REDIS.lrange("#{@batch_id}:success", 0, -1).each do |record|
    # process success queue
    success_sheet.add_row(JSON.parse(record))
  end
  REDIS.lrange("#{@batch_id}:error", 0, -1).each do |record|
    # process error queue
    error_sheet.add_row(JSON.parse(record))
  end
  # lookup email address and send results
  email_to = REDIS.get("#{@batch_id}:owner"))
  YourMailer.send_results(...)
  # set expiration for 5 batch keys, useful to keep them around just in case
  REDIS.expire("#{@batch_id}:size", 60*60*24*7)
  REDIS.expire("#{@batch_id}:counter", 60*60*24*7)
  ...
end
{% endhighlight %}

So far we tested it on several imports (biggest was over 50K rows) and Sidekiq just worked through each job and emailed results when done.  Much better than the old solution where a server reset due to deploy stopped the import process.

The slow part turned out to be queueing of the jobs, I might turn it into a background job itself.  I also plan to setup different priority queues as we have other jobs running all the time don't want this process to block them.