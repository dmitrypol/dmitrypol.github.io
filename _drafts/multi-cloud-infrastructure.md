---
title: "Multi Cloud Infrastructure"
date: 2018-01-16
categories: aws gcp
---

Even when we build scalable systems taking advantage of redundant infrastructure provided by cloud hosting vendor occasionally it is the vendor that experiences the outage.  It would be great to have an ability to easily fail over to a different cloud provider when one is having major problems.  

Unfortunately that is not easy to do for our our entire production system but it may be possible for some of the components.  We are building a Ruby on Rails blogging platform where `Users` create `Articles`.  To scale our system we use [middleman](https://github.com/middleman/middleman) static content generator and publish files to AWS S3.  

This creates separation between internal and external (revenue generating) components.  

### Content site

{% highlight ruby %}

{% endhighlight %}



We can add a step to our generator to also push files to [Google Cloud Storage](https://cloud.google.com/storage/).  

Now if there is a major issue with S3 (as did happen last year) we can modify our DNS to point to Google Cloud buckets and very quickly failover.  

{% highlight ruby %}

{% endhighlight %}

What if the outage lasts longer and we truly decide to move to Google Cloud from AWS?  For that we would need to have access to a completely external data backup.  We would build new systems using Google infrastructure, restore our backup and

This is not a simple undertaking.  

### Ad server

Confession - I have never built such a system

In reality most systems are too complex and cannot be switched by simply copying files.  What if we have globally distributed ad network?  We have our primary DB in one data center and then we have ad servers in various locations around the world.  When data is updated in primary DB (ads created, accounts run out of daily budget) those updates are pushed to caches on individual ad servers.  

Now we need to push data from AWS to GCP.  

{% highlight ruby %}

{% endhighlight %}

Using https://kubernetes.io/ which is supported by several cloud vendors helps us keep infrastructure configuration the same.  

### Same cloud, different region

A more realistic scenario is what particular region is impacted and we need to fail over from us-east-1 to us-west-2

{% highlight ruby %}

{% endhighlight %}
