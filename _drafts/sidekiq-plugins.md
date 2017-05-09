---
title: "Sidekiq Plugins"
date: 2017-05-08
categories: redis sidekiq
---

I have written several blog posts about using [Sidekiq](https://github.com/mperham/sidekiq/) for various tasks such as [cache pre-generation]({% post_url 2017-03-27-redis-cache-pregen %}), [processing inbound requests]({% post_url 2017-03-16-sendgrid-webhooks-background-jobs%}) and many others.  

Not only is Sidekiq a great gem in itself but other developers have built a number of useful plugins on top of it.  Here are a few that I really like:

https://github.com/ondrejbartas/sidekiq-cron


https://github.com/richfisher/sidekiq-enqueuer


https://github.com/mhfs/sidekiq-failures'


https://github.com/dmitrypol/sidekiq-statistic'


https://github.com/mhenrixon/sidekiq-unique-jobs


https://github.com/sidekiq-status'


Sidekiq Pro and Enterprise support some of the features provided by these gems (for example cron) and more.  Plus Pro and Enterprise versions come with support from Sidekiq author.  But for small projects where there might not be a budget to buy paid Sidekiq these gems can really help.  

More are listed on https://github.com/mperham/sidekiq/wiki/Related-Projects but not all of these appear to be current.  
