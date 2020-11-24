---
title: "Rails for background processes"
date: 2016-10-21
categories:
---

As we scale our systems we can break up monolithic applications into more microservices style design.  

Sometimes instead of building a true microservice architecture where each app is responsible for only one thing we could combine them into more general groups.  

Deploying microservices from shared code base where each one can be scaled / started separately.

For a blogging platform we might have UI that users use to manage articles.  There is a publishing system that is used to read articles (lots of caching).

Separately we might build an app to run various background processes where we download data from external sources, generate reports, aggregate stats in our DB, archive data, send out emails, etc.  They can be ran via cron, ActiveJob or as daemons (https://github.com/thuehlinger/daemons).  

How would we use Rails to build such an app to run various background processes.  Use Rails-API (http://edgeguides.rubyonrails.org/api_app.html) because we need to have controller endpoint for /health monitor.  But there is no UI, assets pipeline, etc.  


My 3 previous posts on microservices.

http://martinfowler.com/microservices/
http://www.martinfowler.com/articles/microservices.html
http://martinfowler.com/tags/microservices.html


### Useful links
* [https://resources.codeship.com/webinars/thank-you-building-apps-with-microservices](https://resources.codeship.com/webinars/thank-you-building-apps-with-microservices)
