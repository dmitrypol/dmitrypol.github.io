---
title: "Figuring out which DB queries to cache"
date: 2015-08-23
categories: redis
---

I like using [RailsAdmin](https://github.com/sferik/rails_admin) for basic UI.  To calculate certain business stats I implemented various methods on my models (for example Customer model can have total_orders method).  Then in my rails_admin.rb initializer I can do this:

{% highlight ruby %}
...
config.model 'Customer' do
  list do
    ..
    field :total_orders
    ...
  end
end
...
{% endhighlight %}

So now I see the list of customers with column showing total orders for each one.  But this is not the best way to query database.  If I were writing a custom report I would use a join to send it all to DB in one request.  The approach above fires a separate query for each customer.  So it's getting slower with more and more customers.  Fortunately this data does not change too often (the example above is not what I actually have) so it's OK to cache it.  With [Rails low-level caching](http://guides.rubyonrails.org/caching_with_rails.html#low-level-caching) I can cache contents of each method call for a period of time in [Redis](http://redis.io) or [Memcached](http://memcached.org).  

But when I started implementing caching I had a LOT of methods like this being called from RailsAdmin so it was hard to tell which ones were causing the UI to slow down.  So I used [rack-mini-profiler](https://github.com/MiniProfiler/rack-mini-profiler).  It shows you lots of data points but I was particularly interested in DB queries.  I would load each page and see which method calls occurred how many times and caused how many queries (some were ran hundreds of times).  

I would then add **Rails.cache.fetch** inside the method and reload the page twice.  The first one it would execute the queries and store data in cache but 2nd reload would fetch data from cache.  Rack-mini-profiler would show me how fast the page loaded now and which queries were no longer executed.  Then I just repeated the process on other methdos and models.  

I can't say this is a perfect solution but it really helped me speed up out admin UI.  I use this UI myself quite a lot and I was getting tired of waiting for pages to load.  