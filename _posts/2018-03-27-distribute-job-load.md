---
title: "Distributing DB load when running background jobs"
date: 2018-03-27
categories: redis sidekiq
---

What if we had a multi-tenant system where we needed to generate various reports?  Typically we would do it at night as the load on the DB is usually less at that time.  

* TOC
{:toc}

### One job

A simple solution is to create a background process using ActiveJob with Sidekiq backend.  

{% highlight ruby %}
class GenerateReportsJob < ApplicationJob
  def perform
    Tenant.each do |tenant|
      # query DB and output data to XLSX files
    end
  end
end
{% endhighlight %}

We can schedule it using sidekiq-cron.  

{% highlight ruby %}
# config/environments/development.rb
config.active_job.queue_adapter = :sidekiq
# in config/initializers/sidekiq.rb
schedule = [
  {'name' => GenerateReports, 'class' => GenerateReportsJob,
  'cron'  => '1 1 * * *', 'queue' => default, 'active_job' => true }
]
Sidekiq.configure_server do |config|
 Sidekiq::Cron::Job.load_from_array! schedule
 ...
end
Sidekiq.configure_client do |config|
  ...
end
{% endhighlight %}

### Multiple jobs

The problem is this will create a long running job which could fail in the middle.  What we want to do is separate report scheduling from report generating.  We will be using GlobalID to identify tenants.  

{% highlight ruby %}
# config/initializers/sidekiq.rb
schedule = [
  {'name' => ScheduleReports, 'class' => ScheduleReportsJob,
  'cron'  => '1 1 * * *', 'queue' => default, 'active_job' => true }
]
# app/jobs/
class ScheduleReportsJob < ApplicationJob
  def perform
    Tenant.each do |tenant|
      GenerateReportJob.perform_later tenant
    end
  end
end
class GenerateReportJob < ApplicationJob
  def perform tenant
    # query DB and output to XLSX for specific tenant
  end
end
{% endhighlight %}

The problem is that now all jobs will be running at the same time putting extra load on our DB at once.  Instead we will modify our code to schedule the first job immediately, second job in 5 minutes, third in 10 minutes and so on.  Sidekiq will use Redis Sorted Sets to delay job execution.  

{% highlight ruby %}
# app/jobs/
class ScheduleReportsJob < ApplicationJob
  def perform
    Tenant.each_with_index do |tenant, index|
      GenerateReportJob.set(wait: (index * 5).minutes).perform_later tenant
    end
  end
end
{% endhighlight %}

This approach might not scale if we have hundreds of tenants because the delay will be too long.  So we would need to adjust the gap from 5 minutes to something less.  But this is a simple way of distributing load on the DB and potentially saving $ on hosting costs.  

### Links
* http://sidekiq.org
* https://redis.io/
* https://github.com/ondrejbartas/sidekiq-cron
* https://github.com/rails/globalid
