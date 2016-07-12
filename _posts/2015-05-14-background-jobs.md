---
title:  "Structuring background jobs"
date: 2015-05-14
categories: redis
---

All applications need to do certain background tasks such as sending daily emails, generating reports or downloading data.  Rails 4.2 provides a really good framework with [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) which also has a [backport](https://github.com/ankane/activejob_backport) to previous Rails versions.

Even without ActiveJob you can easily create app/workers and run them via cron or better yet [DelayedJob](https://github.com/collectiveidea/delayed_job) [Resque](https://github.com/resque/resque) or [Sidekiq](https://github.com/mperham/sidekiq).  You can treat these files as PORO and write automated tests.  But with time these workers get bigger as you are putting more and more business logic in them (like which emails should be sent to which users).  Soon you are dealing with 100+ lines classes with multiple methods.

Instead I am now working to refactor these jobs and put business logic into service objects (or sometimes models).  This way my jobs contain simple .perform method and appropriate logging messages.  I can test the business logic in the service objects separately.

It is also important to specify default parameters in worker code but allow them to be passed in via command line.  What if I need to regenerate some kind of reporting data for a specific customer?  I can run the job specifying customer_id.  Code should be smart enough to delete appropriate pre-existing records and replace them with newly generated data.

Another advantage of putting business logic in the service object is that I can hit the same code via UI if needed.  This way internal business user can choose to regenerate the port for that customer.

Whether that manual intervention is done by me (via command line) or by business user (via UI) depends on the specific issue.  You need to ask questions such as how often does it need to be done and what are possible negative side-effects?  But it's nice to have options instead of manually deleting data for all customers and re-running the whole process.