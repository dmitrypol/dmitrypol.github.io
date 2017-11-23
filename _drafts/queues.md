---
title: "Queues - DB vs Redis vs RabbitMQ vs SQS"
date: 2017-10-31
categories: redis rabbitmq sqs
---

Queues can be useful tool to scale applications or integrate complex systems.  Here is a basic use case.  User registers on a website and we need to send a welcome email.  We record data in the User table and separately call email service provider (Sendgrid, Mailchimp, AWS SES).  Sending email via background process will be faster UX plus we can retry in case of failure.  

* TOC
{:toc}

### Primary DB

Ruby on Rails has a robust [delayed_job](https://github.com/collectiveidea/delayed_job) library (other languages / frameworks have alternative tools).  `delayed_job` will create a table in MySQL / Postgres (there is also `delayed_job_mongoid` for MongoDB).  

Using primary DB as queue means there is no need to introduce other technologies.  It is usually faster to record data in local DB than talking to external API (sending email).  `delayed_job` also has integrations with deployment (capistrano, Chef) and monitoring ([New Relic](https://docs.newrelic.com/docs/agents/ruby-agent/background-jobs/delayedjob-instrumentation)) tools.  It is a good choice to get started with.  

Ruby on Rails provides [Active Job](http://guides.rubyonrails.org/active_job_basics.html) framework which allows to configure queue backend globally at application level but also to customize it per environment (dev vs test vs prod) or even per job.  

{% highlight ruby %}
config.active_job.queue_adapter = :delayed_job
#
class MyJob < ApplicationJob
  queue_as :my_queue
  def perform(*args)
  end
end
{% endhighlight %}

When job fails it will go back to DB and executed in the near future.  `delayed_job` supports scheduling the job to execute in the future and we can configure recurring job with [delayed_cron_job](https://github.com/codez/delayed_cron_job)

{% highlight ruby %}
MyJob.set(wait: 1.week).perform_later
#
MyJob.set(cron: '*/5 * * * *').perform_later
{% endhighlight %}

We can create separate queues w/in `delayed_job` and start different `delayed_job` processes on different servers.  We can give job higher priority w/in a queue.  Data is stored in regular DB (just columns in a table) so we can view contents of `delayed_jobs` table or use `Delayed::Job` class to build simple GUI.   

The biggest downside is scalability.  As our application grows the primary DB will become very busy.  Plus it will need to persist this data to disk.  Not a problem when running thousands of daily jobs but can be a challenge when running millions.   

### Redis

[Redis](https://redis.io/) can be used for variety of tasks (caching, pub/sub) but it also makes a great queue with its Lists data structure.  Since adding items to list is O(1) operation queueing jobs is very fast.  [Sidekiq](https://github.com/mperham/sidekiq) is a mature library with free and commercial versions.  

It uses Lists for storing individual jobs and other Redis data structures to store various metrics (queues are stored in a Set).  Sidekiq also has a number of plugins which create their own Redis records.  

{% highlight ruby %}
# queue:my_queue list.  Each item is a JSON encoded string
{
  "class": "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
  "wrapped": "MyJob",
  "queue": "my_queue",
  "args": [
    {
      "job_class": "MyJob",
      "job_id": "b841f3a1-8292-4894-83dd-3fb3abbb0b05",
      "provider_job_id": null,
      "queue_name": "my_queue",
      "priority": null,
      "arguments": [],
      "executions": 0,
      "locale": "en"
    }
  ],
  "retry": true,
  "jid": "26f81b9f4f04b6195581fa50",
  "created_at": 1509478374.233956,
  "enqueued_at": 1509478374.234389
}
{% endhighlight %}

When job fails it will be scheduled for retry and stored in Sorted Set.  Score `1509474704.5617971` is the time to execute it and Sidekiq implements exponential backoff in case of multiple failures.  Different Sorted Set is used to store jobs simply scheduled for later execution (far in the future if necessary).  

{% highlight ruby %}
# failed zset
{
  "class": "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
  "wrapped": "MyJob",
  "queue": "my_queue",
  "args": [
    {
      "job_class": "MyJob",
      "job_id": "cc6909a3-b033-4e97-afd8-5bebd1f66460",
      "provider_job_id": null,
      "queue_name": "my_queue",
      "priority": null,
      "arguments": [],
      "executions": 0,
      "locale": "en"
    }
  ],
  "retry": true,
  "jid": "8ad1f65c8b1a1a7540be5914",
  "created_at": 1509474704.542902,
  "enqueued_at": 1509474704.542999,
  "error_message": "some kind of error",
  "error_class": "RuntimeError",
  "failed_at": 1509474704.561714,
  "retry_count": 0,
  "processor": "...local:68224"
}
{% endhighlight %}

Hashes are used for various statistics ([sidekiq-statistic gem](https://github.com/davydovanton/sidekiq-statistic)).  

{% highlight ruby %}
# sidekiq:statistic hash
{
  "2017-10-31:MyJob:passed": 35,
  "2017-10-31:MyJob:last_job_status": "passed",
  "2017-10-31:MyJob:last_time": "2017-10-31 18:35:12 UTC",
  "2017-10-31:MyJob:queue": "dmitry1",
  "2017-10-31:MyJob:average_time": 0.005952380952380952,
  "2017-10-31:MyJob:min_time": 0,
  "2017-10-31:MyJob:max_time": 0.028,
  "2017-10-31:MyJob:total_time": 0.125,
  "2017-10-31:MyJob:failed": 1,
  ...
}
{% endhighlight %}

And to store recurring jobs with [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron).  

{% highlight ruby %}
# cron_job:schedule_name hash
{
  "name": "schedule_name",
  "klass": "MyJob",
  "cron": "1 * * * *",
  "description": "",
  "args": [],
  "message": {
    "queue": "my_queue",
    "class": "MyJob",
    "args": []
  },
  "status": "enabled",
  "active_job": false,
  "queue_name_prefix": "",
  "queue_name_delimiter": "",
  "last_enqueue_time": "2017-10-31 18:35:12 UTC"
}
{% endhighlight %}

[sidekiq-unique-jobs](https://github.com/mhenrixon/sidekiq-unique-jobs) creates separate Redis Strings to track jobs with their parameters and ensure uniqueness.  

{% highlight ruby %}
# uniquejobs:a35ea078baa09ea090c613233c786072 string
23d6bbd93891f04c3fef9f7e
# uniquejobs:ea6ae821c80f8d14f37932d52803b81a string
668b179fe44718ee7c2b1f6f
{% endhighlight %}

Sidekiq/Redis also supports multiple queues (which can be given different weights).  To prioritize jobs w/in a queue we can use Sorted Set to store jobs.  http://charlesnagy.info/it/python/priority-queue-in-redis-aka-zpop

Sidekiq has a great GUI to view the jobs.  We can also access Redis data structures directly and build our own UI.  

Hosting Redis does introduce more complexity to our infrastructure.  Fortunately there are many reliable and affordable hosting services (AWS ElastiCache, RedisCloud).  We can implement Redis with [Multi-AZ failover](http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/AutoFailover.html) (important if we are using Redis to store other data)

Another thing to be cautious of is running out of Redis RAM.  Often Redis is used for variety of purposes and we do not want to [evict important jobs](https://redis.io/topics/lru-cache) because too much RAM is used for caching.  Queueing 1 million jobs used up about 1 GB of RAM (this will vary on how many params are queued with the job).

### AWS SQS

[AWS SQS](https://aws.amazon.com/sqs/faqs/) takes care of .  [AWS SDK](http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SQS.html) offers low level access but [shoryuken](https://github.com/phstc/shoryuken) is a higher level integration (shoryuken author acknowledges sidekiq).  

We need to make sure the queues are created in SQS otherwise we get `shoryuken-3.1.12/lib/shoryuken/queue.rb:72:in `rescue in set_name_and_url': The specified queue default does not exist. (Aws::SQS::Errors::NonExistentQueue)`.  

Retrying failed jobs will happen automatically unless the messages is explicitly deleted.  Read about [visibility timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html).  We can only delay jobs for 15 minutes `shoryuken-3.1.12/lib/shoryuken/extensions/active_job_adapter.rb:44:in `enqueue_at': The maximum allowed delay is 15 minutes (RuntimeError)`

Recurring jobs are not supported but there are workarounds with [AWS lambda](https://docs.aws.amazon.com/lambda/latest/dg/with-scheduled-events.html) and [CloudWatch](https://aws.amazon.com/pt/about-aws/whats-new/2016/03/cloudwatch-events-now-supports-amazon-sqs-queue-targets/)

AWS SQS UI is decent and we can use AWS SDK to access data and build our own.  SQS has other interesting features such as long polling, batch operations and dead letter queues.  

FIFO queues - "The order in which messages are sent and received is strictly preserved and a message is delivered once and remains available until a consumer processes and deletes it; duplicates are not introduced into the queue.".  However, FIFO queues only allow 300 TPS (much less that regular SQS).  Shoryuken works with standard and FIFO queues.  

http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues.html

http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html

Hosting - easy to setup and cheap (pay for what you use) but obviously only available on AWS.   
Other limits to be aware of http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/limits-messages.html

One interesting possibility is to use two queue backends w/in the same application.  Perhaps we really like Sidekiq and it works for most of our needs.  But some of our jobs need to run millions of times a day and we do not want to pay for a large Redis instance.  We simply install and configure both sidekiq and shoryuken.

{% highlight ruby %}
config.active_job.queue_adapter = :sidekiq
#
class MyJob < ApplicationJob
  self.queue_adapter = :shoryuken
end
{% endhighlight %}



### RabbitMQ

[RabbitMQ](http://www.rabbitmq.com/) offers other interesting features.  [bunny](https://github.com/ruby-amqp/bunny) allows to create producers and consumers directly but [sneakers](https://github.com/jondot/sneakers) is a higher level integration (gem author acknowledges sidekiq as inspiration).  

{% highlight ruby %}

{% endhighlight %}


acknowledge
vhost
cluster
permissions


Delaying jobs is not supported with Rails and RabbitMQ. https://medium.com/@dongwookkoo/delayed-feature-for-rails-activejob-and-sneakers-318ffbc668fb

{% highlight ruby %}
rails r "OneJob.set(wait: 1.minute).perform_later"
Running via Spring preloader in process 67928
.../activejob-5.1.4/lib/active_job/queue_adapters/sneakers_adapter.rb:31:in `enqueue_at': This queueing backend does not support scheduling jobs. To see what features are supported go to http://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html (NotImplementedError)
{% endhighlight %}

But there is a plugin we can install https://www.rabbitmq.com/blog/2015/04/16/scheduling-messages-with-rabbitmq/
https://stackoverflow.com/questions/4444208/delayed-message-in-rabbitmq


Recurring job


GUI http://localhost:15672/


Hosting for RabbitMQ offers fewer choices than Redis and is more expensive.  [CouldAMPQ](cloudamqp.com) runs on several cloud providers and has free tier (plus Herolu integration).  [IBM Compose](https://www.compose.com/databases/rabbitmq) is another option.  


### Conclusion

So which queue technology should we use?  There is no easy answer and it really depends on our needs.  Personally I really like the abstraction provided by Active Job (even though it does not support all features provided by some queue backends).  It makes it easier to structure jobs in a standard way and when needed switch between queues.  If I were building a simple system I would start with DelaydJob.  Then I would upgrade to Sidekiq (especially if I were already using Redis).  Then investigate SQS for very large scale and RabbitMQ for complex workflows.  


### Links

http://queues.io/
https://www.amqp.org/
https://www.cloudamqp.com/blog/2015-05-18-part1-rabbitmq-for-beginners-what-is-rabbitmq.html
http://alihuber.github.io/fun-with-rabbitmq-5/
http://www.rabbitmq.com/tutorials/tutorial-one-ruby.html

{% highlight ruby %}

{% endhighlight %}
