---
title: "Rails and daemons"
date: 2016-10-17
categories: rails
---

[Ruby on Rails](http://rubyonrails.org/) give us a good template for builiding MVC applications.  If we need to run recurring tasks we can use [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) and cron it every X minutes.  But sometmes we need to move beyond cron and run actual daemons.  

https://github.com/thuehlinger/daemons

Let's envision a system where Users update their records.  Once


Running daemons on multiple servers but ensuring that only one does the work.  How does Sidekiq runs jobs


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}
