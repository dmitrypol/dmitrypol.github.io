---
title: "Avoiding Single Points of Failure"
date: 2015-06-09
categories: redis
---

I hate Single Points of Failure (SPOF).  To me it's rolling the dice over the over hoping that it works and eventually something breaks.  You code may work fine but the server behind it fails.  With modern cloud computing we are largely isolated from hardware failures but there is still (however remote) possibility of OS crash.  Or you could have that particular server down for maintenance.  

In the current system I am working on I setup separate EC2 instances in AWS us-west-2 region in 3 separate [Availability Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html).  I am using [MongoDB](https://www.mongodb.org/) so 3 DB servers are spreads across 3 AZs as well.  I have [Elastic Load Ballancer](https://aws.amazon.com/elasticloadbalancing/) distributing traffic across EC2 instances and MongoDB will automatically fail over if needed (I tested and it worked great).  I implemented offsite data backup with [MongoDB Cloud Manger](https://www.mongodb.com/cloud) that allows point in time recovery.  The background tasks are ran via [DelayedJob](https://github.com/collectiveidea/delayed_job) with one worker per server which creates redundancy and allows to paralelize certain jobs.  

But I do have a small single point of failure in the system.  The crontab that kicks off Delayed Jobs runs on only 1 server via simple "rails runner job_name".  And it's bugging the heck out of me.  I know that chances of failure are small and I can kick off those jobs manually from a different server if needed.  But it's still a SPOF.  

What I really want is to store the cron in a shared database.  Then a process running on each server can check what should be executed.  I researched and came across a gem that does just that [DelayedCronJob](https://github.com/codez/delayed_cron_job).  It adds another column to your Delayed Jobs table where you store crontab expression.  It does not delete the job after running it but instead updates run_at time according to crontab expression.  I plan to try it in the near future.  

**Update:**

I implemented this gem and it worked great.  One nice thing is you can change cron frequency via the UI, just build valid expression via [crontab.guru](http://crontab.guru/).  As precaution you can put a crontab regex valdation in your DelayedJobs model on the cron field.  And you can see how many times this job has been ran.  One feature I wish for is ability to pause a particular job.  A workaround is to edit run_at field to some point in the distant future.    

But shortly after implemetning DelayedCronJob I decided to switch to [Sidekiq](https://github.com/mperham/sidekiq).  Using [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) made it fairly straightforward.  And I did not want to go back this SPOF.  Paid Sidekiq version has cron functionality built in but there is also a free [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron) gem.  To setup cron schedule I implemented this in my sidekiq initializer

{% highlight ruby %}
schedule_array =
[
  {'name' => 'MySpecialJobName',
    'class' => 'MySpecialJob',
    'cron'  => '1 * * * *',
    'queue' => 'MySpecialQueue', # I like running my jobs through dedicated queues in case I need to flush specific queue
    'active_job' => true },
...
]
Sidekiq::Cron::Job.load_from_array! schedule_array
...
{% endhighlight %}

Sidekiq-cron web UI allows to temporarily disable the job and also to run it on demand.  Unfortunately even with [sidekiq-statistic](https://github.com/davydovanton/sidekiq-statistic) it does not tell you how many times specific job has been ran.  Sidekiq API and middleware are fairly robust so maybe I can build something custom (or even a gem of my own).
