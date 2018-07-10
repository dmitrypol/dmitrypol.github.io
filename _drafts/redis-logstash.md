
* TOC
{:toc}

We will be processing time series data events.  Each event will look something like this:

```
{
        "request" => "https://website.com/api?session_id=123&...",
          "agent" => "\"Mozilla/5.0 (Linux; Android 5.1.1; KFGIWI Build/LVY48F) AppleWebKit/537.36 (KHTML, like Gecko) Silk/65.5.3 like Chrome/65.0.3325.144 Safari/537.36\" ECDHE-RSA-AES128-GCM-SHA256 TLSv1.2\n",
         "params" => "?session_id=123&...",
           "path" => "/api",
     "@timestamp" => 2018-05-24T22:05:26.210Z,
       "response" => 200,
       "clientip" => "99.85.100.173",
       ...
}
```

### Pipeline buffer

Sometimes there can be large spikes in inflow of data and we want to protect our system.  We will place Redis instance in front of Logstash and push data into it.  Then Logstash will use Redis input plugin to fetch data.  

```
# /etc/logstash/conf.d/my_elastic.conf file
input {
  redis {
    host      => "localhost"
    db        => "0"
    data_type => "list"
    key       => "elastic_list"
  }
}
```

Data in Redis will look like this:

```

```

### Fast data lookup

Logstash supports many filter plugins but there are still times when we need ability to write code to implement complex business logic.  For that we can leverage Ruby filter plugin and extract our code into separate script file.  

```
# /etc/logstash/conf.d/my_elastic.conf file
filter {
  ruby {
    path => "/etc/logstash/ruby/my_elastic.rb"
  }
}
# /etc/logstash/ruby/my_elastic.rb
def filter(event)
  # business logic here
end
```

As we are processing these logs we want to filter out data coming from a list of invalid IPs.  We can use Redis for quick lookups.  If IP is present, we will not process that event.  Data will be loaded into Redis by a separate application.  Since we are using Redis input plugin above we will specify different Redis DB for this lookup just to keep things separate.  

```
# /etc/logstash/ruby/my_elastic.rb
require 'redis'
REDIS_INVALID_IPS = Redis.new db: 1
def filter(event)
  return [] if check_ip_invalid(event.get('clientip'))
  ...
end
def check_ip_invalid ip
  return true if REDIS_INVALID_IPS.get(ip)
end
```

### Cache

Next requirement is to enrich data as part of ETL process.  For that we often need to query external data sources (databases and APIs) which can slow down the pipeline.  In this scenario we will do a lookup based on the UserAgent of the event.

```
# /etc/logstash/ruby/my_elastic.rb
def filter(event)
  ...
  event.set('new_field', slow_method(event))
end
def slow_method event
  lookup_param = event.get('agent')
  # query DB or API for the lookup_param
end
```

To speed things up we can cache data in Redis.  We will use lookup_param as `cache_key`.  If data is present in Redis we will return it.  If not we will perform the slow query, cache data in Redis and return it.  Redis TTL will purge data after 900 seconds.  To keep things separate from the Redis input plugin and previous check for invalid IPs we will again a different Redis DB in REDIS_CACHE client.  

```
# /etc/logstash/ruby/my_elastic.rb
require 'redis'
REDIS_CACHE = Redis.new db: 2
TTL = 900
...
def slow_method event
  cache_key = event.get('agent')
  cache_content = REDIS.get cache_key
  if cache_content
    return cache_content
  else
    cache_content = slow_code_here
    REDIS.setex cache_key, TTL, cache_content
    return cache_content
  end
end
```

### Redis output

Use Ruby code to read/write data from Redis.  No Logstash output.  
Fast way to aggregate high level summary stats in Redis.  Just using Logstash input and filter.  
