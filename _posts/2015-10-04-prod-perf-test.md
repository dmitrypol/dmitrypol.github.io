---
title:  "Using online perf test services to test your production site"
date: 2015-10-04
categories:
---

Recently I had to run an extensive (6 hour) online stress test to prove to an important customer that our system can handle the load.  Internally I have been using tools like [Siege](https://www.joedog.org/siege-home/) and [Wrk](https://github.com/wg/wrk) to stress test the site.  But obviously customer wanted something "official" from a third party service.  We ended up using [Loader.io/](http://loader.io/) from [SendGrid](https://sendgrid.com/).

To speed up our site for this perf test I implemented [caching](http://guides.rubyonrails.org/caching_with_rails.html) in our Rails app.  I also tweaked [Passenger configuration](https://www.phusionpassenger.com/library/config/nginx/reference/#passenger_max_pool_size) to support more processes per server.  There are other tweaks possible for Passenger so read their docs.  I used passenger-status to monitor server load during perf tests.  

What I liked about Loader.io is that I was able to do both GET and POST requests to simulate various interactions.  I had to enable service to target my domain by uploading a special file provided by Loader.io to my public folder.  I also had to upgrade to their premium plan but even that only allowed max 1 hour duration.  To solve that I simply manually ran six 1 hour tests back to back.  Loader.io also has a free plan for much more limited testing.  

But the most important part was the very nice and visual reports their service generates.  We had to manually save them as PDFs (unforunately they do not have such export option) and presented it to our customer.  

Other services we considered were [BlazeMeter](https://blazemeter.com/) (based on JMeter) and [http://www.webperformance.com/load-testing/](http://www.webperformance.com/load-testing/).  They were not as feature rich and significantly more expensive.  

Some other thoughts about using online perf testing services.  It's important to check where this service actually load and run JS?  In our case we have a fairly rich JS app which loads data via a separate AJAX call to JSON endpoint.  

Also, where is this service running from?  If you are app is based on AWS Oregon region and the perf service is also running from that region you are going to have network connection much faster than average user.  