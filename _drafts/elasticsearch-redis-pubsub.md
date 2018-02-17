---
title: "Elasticsearch and Redis Pub/Sub"
date: 2018-02-05
categories: elastic redis
---

In previous posts we talked about integration between [ElasticSearch and Redis]({% post_url 2018-01-04-elasticsearch-redis %}) and using [Redis Streams]({% post_url 2018-01-04-elasticsearch-redis %}) to store / move time series data.  Now we will explore [Redis Pub/Sub](https://redis.io/topics/pubsub).  

* TOC
{:toc}

### Redis channels

We will be leveraging the same example of Ruby on Rails website for national retail chain.  

{% highlight ruby %}

{% endhighlight %}



### Logstash


{% highlight ruby %}

{% endhighlight %}


### Links
* http://www.rubydoc.info/github/redis/redis-rb/Redis:publish
* http://www.rubydoc.info/github/redis/redis-rb/Redis:subscribe
* https://making.pusher.com/redis-pubsub-under-the-hood/
* https://gist.github.com/pietern/348262
* https://www.elastic.co/guide/en/logstash/current/plugins-inputs-redis.html
* https://www.elastic.co/guide/en/logstash/current/plugins-outputs-redis.html
* http://redis.io/topics/pubsub
* https://github.com/krisleech/wisper


{% highlight ruby %}
{"key":"1516129966278-0", "type":"hash","value":{"zipcode":"31643", "query": "python"} }

Idx:search_log,  type: ft_index0
ft:search_log/31643, type: ft_invidx
ft:search_log/python,  type: ft_invidx

{% endhighlight %}
