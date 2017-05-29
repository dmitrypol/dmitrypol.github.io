---
title: "Bulk data import - part two"
date: 2017-05-26
categories: redis sidekiq
---

In previous [post]({% post_url 2016-03-18-sidekiq-batches %}) I wrote about using [Redis](https://redis.io/) and [Sidekiq](http://sidekiq.org/) to do bulk data imports.  But as with all scalability challenges this solution works up to a certain level.  What if we have very large imports with millions of records?  

At that point even queuing Sidekiq jobs (one per record) can take a long time.  What if we re-deploy code and restart our application server?  The jobs that were queued up will get processed but it will be hard to tell how many and which records were not placed in the queue.  

Here is one way to improve this process.  When a file with records to be imported is uploaded, we first save it to [AWS S3](https://aws.amazon.com/s3/).  We then fire `QueueRecordImportJob.perform_later` and send "import has began" message back to the user.

{% highlight ruby %}
# config/initializers/aws.rb
S3_CLIENT = Aws::S3::Client.new( credentials: ..., region: ...)
S3_BUCKET = ...
# app/controllers/
class RecordImportController < ApplicationController
  def create
    file_object_key = save_to_s3(file: params[:file])
    QueueRecordImportJob.perform_later(file_object_key: file_object_key)
    redirect_to :back, notice: 'data import process has began'
  end
private
  def save_to_s3 file:
    object_key = [Time.now, file.original_filename.parameterize].join('-')
    s3 = Aws::S3::Resource.new(client: S3_CLIENT)
    object = s3.bucket(S3_BUCKET).object(object_key)
    object.upload_file(file.path)
    return object_key
  end    
end
{% endhighlight %}

`QueueRecordImportJob` downloads the file from S3 and starts iterating through it.  It keeps a counter (also stored in Redis) of which row it finished.  If the Sidekiq process restarts, `QueueRecordImportJob` will begin anew.  It will download the file from S3 again, check the counter and start processing the file from the next row.  

This creates a very long running `QueueRecordImportJob` which usually is not a good practice.  If this job fails to complete and the process restarts Sidekiq will try to push it back into the queue (details [here](https://github.com/mperham/sidekiq/wiki/Reliability)).  

{% highlight ruby %}
class QueueRecordImportJob < ApplicationJob
  queue_as :high
  def perform(file_object_key:)
    # download the file
    file = S3_CLIENT.get_object(bucket: S3_BUCKET, key: file_object_key)
    # check counter using file_object_key as Redis key
    row_counter = REDIS.incr(file_object_key)
    CSV.foreach(file, headers: true).with_index do |row, row_num|
      next if row_num < row_counter
      RecordImportJob.perform_later(row: row)
      if row_counter == file.readlines.size
        REDIS.del file_object_key
        S3_CLIENT.delete_object(bucket: S3_BUCKET, key: file_object_key)
      end
    end    
  end
end
{% endhighlight %}

But `QueueRecordImportJob` does not actually import the records.  It simply calls `RecordImportJob.perform_later` passing each row.  This speeds the `QueueRecordImportJob` and now we can have multiple Sidekiq workers processing individual records via `RecordImportJob`.

To ensure that `QueueRecordImportJob` job starts right away after Sidekiq restart we set it to run in a different queue with higher priority.

{% highlight ruby %}
class RecordImportJob < ApplicationJob
  queue_as :low
  def perform(row:)
    # do validations and import / update records in the primary DB
  end
end
# config/sidekiq.yml
:queues:
  - [high, 3]
  - [default, 2]
  - [low, 1]
{% endhighlight %}

### Links
* [ActiveJob](http://guides.rubyonrails.org/active_job_basics.html)
* [https://ruby.awsblog.com/post/Tx1K43Z7KXHM5D5/Uploading-Files-to-Amazon-S3](https://ruby.awsblog.com/post/Tx1K43Z7KXHM5D5/Uploading-Files-to-Amazon-S3)
* [https://www.sitepoint.com/guide-ruby-csv-library-part-2/](https://www.sitepoint.com/guide-ruby-csv-library-part-2/)
