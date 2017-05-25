---
title: "Sidekiq with multiple queues"
date: 2017-05-24
categories: redis sidekiq
---

[Sidekiq](http://sidekiq.org/) is a great library for background job processing.  It uses [Redis](https://redis.io/) as a backend which makes queuing jobs extremely fast.  In this article I will discuss various options for scaling and managing job processing with greater control.

We will build a POC application where we have `SendEmailJob`, `UpdateStatsJob` and `GenerateReportJob`.  

What if we discover a bug in `SendEmailJob` and need to stop these jobs from running in production?  We can easily stop entire Sidekiq process via GUI or CLI but that will stop ALL jobs from running.  We still want `GenerateReportJob` and `UpdateStatsJob` to continue running.

First thing is we will create separate queues for our jobs to run through.  Another benefit of multiple queues is jobs have different priorities and time urgencies.  We do not want to have 10K low priority jobs queued BEFORE 10 high priority jobs.  Here is a good [overview](https://github.com/mperham/sidekiq/wiki/Advanced-Options#queues).

{% highlight ruby %}
class SendEmailJob < ApplicationJob
  queue_as :send_email
  def perform()
  end
end
class UpdateStatsJob < ApplicationJob
  queue_as :update_stats
  def perform()
  end
end
class GenerateReportJob < ApplicationJob
  queue_as :generate_report
  def perform()
  end
end
{% endhighlight %}

Now we will configure our Sidekiq to run different processes to watch various queues.  Here is sample configuration for [capistrano-sidekiq](https://github.com/seuros/capistrano-sidekiq)

{% highlight ruby %}
# deploy.rb
set :sidekiq_processes, 4
set :sidekiq_options_per_process, [
  "--queue default",
  "--queue send_email",
  "--queue update_stats",
  "--queue generate_report",
]
{% endhighlight %}

If we want to use [Procfiles](https://devcenter.heroku.com/articles/procfile) with [foreman](https://ddollar.github.io/foreman/) we can do this:

{% highlight ruby %}
worker1: bundle exec sidekiq -q default
worker2: bundle exec sidekiq -q send_email
worker3: bundle exec sidekiq -q update_stats
worker4: bundle exec sidekiq -q generate_report
{% endhighlight %}

We can now stop specific Sidekiq processes if we want jobs in those queues to not execute (they will continue queuing in Redis).  Other jobs in different queues will run normally.  When we deploy our fix we will restart Sidekiq process that watches `send_email` queue and it will then execute those jobs.  

This approach can also be extended to separate Sidekiq processes per server.  To really scale our applications we may need to create multiple servers so that `default`, `send_email`, `update_stats` and `generate_report` jobs run completely separately.  

Here is configuration for capistrano-sidekiq:

{% highlight ruby %}
# config/deploy.rb
set :sidekiq_role, [:active_job]
# config/deploy/job_default.rb
role :active_job, %w{ubuntu@job_default.mywebsite.com}
set :sidekiq_processes, 1
set :sidekiq_options_per_process, [ "--queue default" ]
# config/deploy/job_send_email.rb
role :active_job, %w{ubuntu@job_send_email.mywebsite.com}
set :sidekiq_processes, 1
set :sidekiq_options_per_process, [ "--queue send_email" ]
...
{% endhighlight %}

Now we can deploy to the same codebase to different servers and activate only some of the functionality.  The other code files will just sit there unused.  

{% highlight ruby %}
cap job_default deploy
cap job_send_email deploy
...
{% endhighlight %}

This approach works well for a few applications derived from a shared codebase.  Beyond that we might need to break things up into separate microservices but that's a different blog post.  
