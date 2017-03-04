---
title: "SendGrid Webhooks and background job"
date: 2017-03-03
categories: redis
---

We use SendGrid for sending out emails and [SendGrid Webhooks](https://sendgrid.com/docs/API_Reference/Webhooks/index.html) for getting notifications when the emails are opened / clicked.  

We then find the `email_id` to find application record in our DB and increment opened and clicked counters

Basic models:
{% highlight ruby %}

{% endhighlight %}


Basic controller:
{% highlight ruby %}

{% endhighlight %}


To keep our controllers light we moved the logic to a service object that would actually do DB updates.  

{% highlight ruby %}

{% endhighlight %}

But then we noticed is when our customers would do a large email sending our system would get hammered with these HTTP requests

Solution was to create a background job.  All controller has to do is throw the job in the queue (we use Sidekiq and Redis)

{% highlight ruby %}

{% endhighlight %}
