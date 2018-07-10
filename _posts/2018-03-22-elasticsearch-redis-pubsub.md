---
title: "ElasticSearch and Redis Pub/Sub"
date: 2018-03-22
categories: elastic redis
---

In previous posts we discussed integration between [ElasticSearch and Redis]({% post_url 2018-01-04-elasticsearch-redis %}) and using [Redis Streams]({% post_url 2018-01-16-elasticsearch-redis-streams %}) to work with time series data.  Now we will explore [Redis PubSub](https://redis.io/topics/pubsub) using the same example of Ruby on Rails website for national retail chain.  

Why would we use Redis PubSub vs sending data directly to ElasticSearch?  One advantage is that multiple clients could be listening to our channel.  We also might not want to create a direct integration between our application and ElasticSearch.  

* TOC
{:toc}

### Redis channels

To try Redis Pub/sub run `redis-cli` in multiple bash tabs.

{% highlight ruby %}
# tab 1
127.0.0.1:6379> subscribe channel1
Reading messages... (press Ctrl-C to quit)
1) "subscribe"
2) "channel1"
3) (integer) 1
# tab 2
publish channel1 'my message'
(integer) 1
# output in tab 1
1) "message"
2) "channel1"
3) "my message"
{% endhighlight %}

When users perform various searches via the dashboard we will send messages to Redis channel from the application.  

{% highlight ruby %}
params = {query: 'tea', zipcode: 98111, controller: 'dashboard',
  acton: 'search', time: Time.now.to_i}
class RedisPubSub
  def perform params
    REDIS.publish('search_log', params.to_json)
  end
end
# in redis-cli
1) "message"
2) "search_log"
3) "{\"query\":\"tea\",\"zipcode\":98111,\"controller\":\"dashboard\",
  \"acton\":\"search\",\"time\":1521763858}"
{% endhighlight %}

### Logstash

To move data into ElasticSearch we will use Logstash [Redis input plugin](https://www.elastic.co/guide/en/logstash/current/plugins-inputs-redis.html), [Ruby filter plugin](https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html) and [ElasticSearch output plugin](https://www.elastic.co/guide/en/logstash/current/plugins-outputs-elasticsearch.html)

Here is a basic Logstash config file:

{% highlight ruby %}
input {
  redis {
    data_type => "channel"
    key       => "search_log"
  }
}
output {
  elasticsearch {
    user      => "elastic"
    password  => "password_here"
    index     => "search_log_%{+YYYY.MM.dd}"
  }
}
{% endhighlight %}

We start logstash and point it to folder with our config file `bin/logstash -f /path/to/logstash/config/folder/ --config.reload.automatic`.  We will see `[logstash.inputs.redis    ] Subscribed {:channel=>"search_log", :count=>1}` in Logstash's own log.  If we send a message from our Rails app and query ElasticSearch index `search_log_2018.03.23` we will get a document:

{% highlight ruby %}
{
  "_index": "search_log_2018.03.23",
  "_type": "doc",
  "_id": "s_sxUGIB28y6h4bFuNdK",
  "_version": 1,
  "_score": null,
  "_source": {
    "@timestamp": "2018-03-23T00:10:58.378Z",
    "query": "tea",
    "@version": "1",
    "zipcode": 98111,
    "time": 1521763858
  },
  "fields": {
    "@timestamp": [
      "2018-03-23T00:10:58.378Z"
    ]
  },
  "sort": [
    1521763858378
  ]
}
{% endhighlight %}

One problem is that we do not want "controller" and "acton" parameters in ElasticSearch.  We could remove them within Rails application or we could use a Logstash Ruby filter.  It allows us to write Ruby code to do various transformations.  We can add data as with `random_number` example below.  

{% highlight ruby %}
filter {
  ruby {
    code => "event.set('random_number', rand(1..1000))"
    remove_field => [ "controller", "acton", "time" ]
  }
}
{% endhighlight %}

### Alternatives to PubSub

One issue with using PubSub is that if Logstash is temporarily not running then it will never receive the messages sent to the channel.  To solve that we can use Redis List instead of PubSub.  Data will remain in Redis and Logstash will process when it comes back online.   

{% highlight ruby %}
# in our application
REDIS.rpush('search_log', params.to_json)
# in logstash config file
input {
  redis {
    data_type => "list"
    key       => "search_log"
  }
}
{% endhighlight %}

This is where passing the time as one of parameters can be useful.  If the data processing is significantly delayed this could result in records from yesterday are inserted into today's index.  We can use time parameter to determine which index to insert into.  

### Links
* http://redis.io/topics/pubsub
* http://www.rubydoc.info/github/redis/redis-rb/Redis:publish
* https://www.elastic.co/blog/moving-ruby-code-out-of-logstash-pipeline
* https://www.elastic.co/guide/en/logstash/current/config-examples.html
* https://www.elastic.co/guide/en/logstash/current/plugins-outputs-stdout.html
* https://making.pusher.com/redis-pubsub-under-the-hood/
* https://gist.github.com/pietern/348262
* https://github.com/krisleech/wisper
