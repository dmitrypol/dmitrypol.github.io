---
title: "Redis as part of ETL pipelines"
date: 2018-08-20
categories: redis
---

Data processing (ETL) pipelines are not very exciting but they are essential to many business functions.  There are a number of existing tools or frameworks that help move data around but sometimes we need a purpose built solution.  In this article we will explore how to use Redis for a variety of tasks to scale the pipelines and simplify our development process.  

Our code examples will be simple Python but many languages / frameworks support higher level libraries that improve the integration.  

* TOC
{:toc}

### Tracking progress

ETL pipelines often require reading log (or other text) files, validating, transforming and loading data.  These input files can be very large and take a long time to go through.  If the process fails midway we do not want to go back to the beginning of the file as that can result in duplicate data.  

How can we use Redis to keep track of our progress in processing specific files?  

{% highlight python %}
import redis
{% endhighlight %}



### Redis as a queue

One way to scale our system is to turn each line into a separate job, used Redis Lists as a queue and then have separate code consume it.  


{% highlight python %}
import redis
{% endhighlight %}


### Redis a a temporary data store

Often as we are processing data we need to enrich it by looking up additional information in a database or querying 3rd party API.  That can become expensive and slow.  

We need to build a `cache_key` that we will use to store the lookup value.  

{% highlight python %}
import redis
{% endhighlight %}


We might have a list of invalid IP addresses that we do not want to process.  This list might change from time to time so we do not want to hard code it in config files.  


### Links
* https://redis-py.readthedocs.io/en/latest/index.html
