---
title: "Rails Cache Variable TTL"
date: 2017-03-03
categories: redis
---

Frequently we cache methods but when data changes we want to bust cache.  So we do not want to set TTL too long because it will waste RAM.  

But then data stopped changing so frequently and it makes sense to keep the cached content around longer.  

How can we change our TTL depending on circumstances?  


defautl application setting

{% highlight ruby %}
  config.cache_store = :readthis_store, { expires_in: 1.hour.to_i, namespace: 'my_app', redis: { host: config.redis_host, port: 6379, db: 0 }, driver: :hiredis }
{% endhighlight %}


{% highlight ruby %}
def my_method_name
  Rails.cache.fetch([cache_key, __method__], expires_in: 1.day) do
    # code here
  end
end
{% endhighlight %}




{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}
