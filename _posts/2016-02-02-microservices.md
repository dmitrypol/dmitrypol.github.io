---
title: "Microservices with Sidekiq"
date: 2016-02-02
categories:
---

Much has been written about pros and cons of monolithic app vs microservices.  Here is a great [post by Martin Fowler](http://martinfowler.com/articles/microservice-trade-offs.html).  I am not going to talk about the big issues but simply share ideas on how I have been thinking of breaking up a Rails app I am working on.

I believe it's important to differentiate how you will integrate these microservices (aka separate applications).  You can have synchronous integration (via HTTP) for tasks such as credit card processing.  You can have asynchronous (approach described below) for tasks like sending email.  You can also have asynchronous tasks that provide feedback to the original application when task is complete (report generation).  If it's not complete w/in certain amount of time an alert could be issued.

Most of these ideas are influenced by this [article](http://brandonhilkert.com/blog/sidekiq-as-a-microservice-message-queue/).  My post assumes you already extacted all necessary logic to your service objects and they are not dependent on your models.  One example of such process is sending out emails.  Each job contains all the necessary information (name, address, etc) that is needed to accomplish the task.

Assuming the the main application is called Foo I created a new Rails project FooJobs.  In FooJobs I deleted all folders except app, bin, config and log.  Inside app folder I deleted everything except jobs and services.  The only gems inside the FooJobs Gemfile are specific to Sidekiq, Redis, Rspec and whatever else I to accomplish the task (talk to external APIs).  But there are no connections to the main DB so no need for Mongoid or ActiveRecord.  So the app is very small and simple.

You may ask why even make it a Rails app?  I wanted to use [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) and perhaps I might need to have Rake tasks in the future.  But there is no web interface so no need for controllers, helpers, templates, etc.  All admin tasks will be done via the main Foo app and I can use [Sidekiq web UI](https://github.com/mperham/sidekiq/wiki/Monitoring) from there.

Inside Foo I created:
{% highlight ruby %}
# app/jobs/email_job.rb
class EmailJob < ActiveJob::Base
  queue_as :email
  def perform(*args)
  end
end
{% endhighlight %}

You may notice that there is no actual code in that file.  But inside FooJobs application I have:
{% highlight ruby %}
# app/jobs/email_job.rb
class EmailJob < ActiveJob::Base
  queue_as :email
  def perform(*args)
    # keep the job small and put the logic in service objects, easier to test
    EmailService.method1 args
  end
end
# app/services/email_service.rb
class EmailService
  def self.method1 args
    # do stuff here
  end
end
# config/sidekiq.yml
---
:queues:
  - email
{% endhighlight %}

Calling **rails r EmailJob.perform_later()** from Foo app will simply put in in Sidekiq queue :email.  Then Sidekiq daemon from FooJobs will pick it up (Sidekiq from Foo app is NOT watching queue :email)

So what if you need to send some information from FooJobs back to Foo (like when you finished sending out all the emails in the queue)?  You can create this in FooJobs:
{% highlight ruby %}
# app/jobs/feedback_job.rb
class FeedbackJob < ActiveJob::Base
  queue_as :feedback
  def perform(*args)
  end
end
{% endhighlight %}
Then in Foo you create app/jobs/feedback_job.rb and modify sidekiq.yml to watch queue :feedback.  Very loose integration.

This type of solution can also be applied when you have inbound messages.  You can have several simple web end points using [Sinatra](http://www.sinatrarb.com/).  All they do is put messages onto :inbound queue.  Main app Sidekiq watches :inbound queeue and processes messages (in this design the shared Redis instance could become a bottleneck).

This post is not meant to advocate for breaking up your app into separate services.  Testing microservices can be trickier.  Testing systems integrated with the queue based approach outlined above simply requires you to place items on queues.  If you have HTTP based real-time integration you could use gems like [VCR](https://github.com/vcr/vcr) and [webmock](https://github.com/bblimke/webmock) to stub responses.  Instead of stubbing responses to 3rd party APIs you are stubbing responses to your microservices.  Here is a good [article](https://semaphoreci.com/community/tutorials/stubbing-external-services-in-rails).

I am looking forward to actually implementing this approach in production when it becomes necessary.  For now, we are fine with monolith app.
