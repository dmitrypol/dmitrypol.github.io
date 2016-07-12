---
title: "Bulk_data_import2"
date: 2016-06-08
categories: redis
---

In previous [post]({% post_url 2016-03-18-sidekiq-batches %}) I wrote about using Redis and Sidekiq to do bulk data imports.  But as with all scalability challenges this solution only goes so far.

The problem becomes when you have very large import (hundreds of thousands of records).  At that point even queuing Sidekiq jobs can take a long time (over an hour).  And if you do server restart, that queuing process dies.

Here is the latest solution we implemented.  When file with list of users to be imported is uploaded into application we save it to S3.

We also fire QueueUserImportJob.perform_later and send "data import process began" message back to controller.

QueueUserImportJob downloads the file from S3 and starts parsing it.  It keeps a counter (stored in Redis) of which row it finished processing.  If you deploy code and restart the server (and Sidekiq process) Sidekiq will restart QueueUserImportJob. The job will download the file from S3 again, check the counter and start parsing the file beginning with the next row.

QueueUserImportJob does not actually import the records.  It simply calls UserImportJob.perform_later passing each row.  Then you can have multiple Sidekiq workers processing those jobs.

To ensure that QueueUserImportJob job starts right away after Sidekiq restart we set it to run in a different queue.

class QueueUserImportJob < ActiveJob::Base
  queue_as :high
end

class UserImportJob < ActiveJob::Base
  queue_as :low
end

config/sidekiq.yml
---
:queues:
  - [high, 4]
  - [default, 2]
  - [low, 1]
