---
title: "MongoDB and time series data"
date: 2018-02-16
categories: mongo
---

Throughout my career I worked on several advertising systems where we collected LOTS of granular data on various events (impressions, clicks and other user interactions).  We would record IP addresses, user agents strings, time, etc.  The details would then be aggregated into reports and eventually purged from the system.  This article is a combination of various designs.  

* TOC
{:toc}

### Data collection

Events data would be received by API servers and placed into a queue.  This will allow system to handle spikes in traffic w/o large DB.  We will be using Ruby on Rails with [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html).  It allows us to easily modify the queue backend and choose either Redis, RabbitMQ or AWS SQS (see [previous post]({% post_url 2017-12-17-queues %}) for comparison).  

{% highlight ruby %}
# config/routes.rb
resources :events, only: [:create]
# app/controllers/
class EventsController < ApplicationController
  def create
    ProcessEventsJob.perform_later params
  end
end
{% endhighlight %}

The job will contain the logic to store the raw data in `events` DB `YYYY-MM-DD` collection.  Data aggregation will be done separately and is out of scope for this article.  

{% highlight ruby %}
# config/initializers/mongo.rb
MONGO_CLIENT = Mongo::Client.new([ '127.0.0.1:27017' ], database: 'events')
# app/jobs/
class ProcessEventsJob < ApplicationJob
  queue_as :events
  def perform(params)
    collection = MONGO_CLIENT[Date.today.to_s]
    collection.insert_one(params)    
  end
end
{% endhighlight %}

We will be using a separate queue `events` so that a spike of inbound messages does not clog the pipeline for other background jobs.  

### Data storage

JSON document structure is great for our purposes.  There will be a separate collection for each day.  Data will look like this.  

{% highlight ruby %}
{
    "_id" : ObjectId("5a873f7e842da1440593383e"),
    "ip" : "178.252.17.244",
    "user_agent" : "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.167 Safari/537.36",
    "timestamp" : 1518814065,
    "type" : "click",
    ...
}
{% endhighlight %}

### Data curation

To save space and $ our business requirement is to keep data for one week and then archive it.  However, we might need to restore data at some point in the future.  [ElasticSearch](https://www.elastic.co/) has a [Curator](https://www.elastic.co/guide/en/elasticsearch/client/curator/index.html) and we will model our process on that.  

One option is to build another background job in our core application for this task.  But frequently these kinds of data cleanups done via separate ETL processes.  So we will write a standalone Ruby CLI using [mixlib-cli](https://github.com/chef/mixlib-cli) library.  This script have 3 parts -  `mongodump`, upload via [AWS S3 client](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3.html) and drop collection via Mongo driver.  We will also have an option to pass specific date for which to run this process.  

{% highlight ruby %}
# archive_events.rb
require 'mixlib/cli'
require 'mongo'
require 'aws-sdk-s3'
class ArchiveEvents
  include Mixlib::CLI

  HOSTS = [ '127.0.0.1:27017' ]
  DB = 'events'
  DUMP_LOCATION = '/tmp/mongodump'
  S3_BUCKET = 'mongodump'
  S3_CLIENT = Aws::S3::Resource.new(region: 'us-east-1')
  BACKUP_FILE_FORMATS = ['bson.gz', 'metadata.json.gz']
  MONGO_CLIENT = Mongo::Client.new(HOSTS, database: DB)
  NUM_DAYS = 7

  option :date,
    short:        "-d DATE",
    long:         "--date DATE",
    required:     false,
    description:  "Date to archive events for (2018-02-15)"

  def run
    parse_options(ARGV)
    puts config
    @date = config[:date] || Date.today - NUM_DAYS
    mongodump
    aws_s3_upload
    drop_collecton
  end

private

  def mongodump
    system "mongodump --host #{HOSTS.first} --db #{DB} --collection #{@date}
      --gzip --out #{DUMP_LOCATION}"
  rescue Exception => e
    puts e
  end

  def aws_s3_upload
    BACKUP_FILE_FORMATS.each do |bff|
      file = "#{@date}.#{bff}"
      obj = S3_CLIENT.bucket(S3_BUCKET).object(file)
      obj.upload_file("#{DUMP_LOCATION}/events/#{file}")
    end
  rescue Exception => e
    puts e
  end

  def drop_collecton
    MONGO_CLIENT[(@date - 0).to_s].drop
  rescue Exception => e
    puts e
  end

end
ArchiveEvents.new.run
{% endhighlight %}


#### S3 to Glacier


{% highlight ruby %}

{% endhighlight %}


#### Alternative to TTL

Mongo also supports [TTL indexes](https://docs.mongodb.com/manual/core/index-ttl/) where DB itself deletes documents older than a certain date.  It is much more resource intensive to go through a collection deleting individual documents than to simple drop the entire collection since we know that ALL documents in that collection are too old.  

### Data restore (if necessary)

One problem with this approach is that we need to restore data we will need to run `mongorestore` on EACH daily collection.  To simplify that we can do run additional weekly process to archive all collections for that week.

{% highlight ruby %}

{% endhighlight %}


 Then we can delete daily collections.  We w

### Links

* https://github.com/elastic/curator
* https://docs.aws.amazon.com/AmazonS3/latest/dev/UploadObjSingleOpRuby.html
