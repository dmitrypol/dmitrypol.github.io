Building data processing pipeline using ELK stack and Ruby

* TOC
{:toc}

Application logs often contain valuable data.  How can we extract it in timely and cost effective way?  As a sample app we will discuss a multi-tenant system where we host multiple sites via subdomains.  URLs in log files contain the paths (/api, /search, etc) and params (?foo=bar&...).  

We will split data by customer and date into separate Elasticsearch indexes and build reports that show which URL paths are accessed.  This is a common pattern when dealing with time series data.   

To keep things simple we will use load balancer logs which contain the same information as web server logs but are centralized.  We will configure our AWS load balancer to publish logs to S3 bucket every 5 minutes.  From there logs will be picked up by Logstash and processed into Elasticsearch.  

Here is a sample line from an ELB log file:

```
2018-05-10T18:26:13.276Z ELB_NAME 73.157.179.139:60708 10.0.1.42:80 0.000021
0.000303 0.000014 200 200 0 68 "GET https://site1.mysystem.com/api?foo=bar...
HTTP/1.1" "Mozilla/5.0 (Linux; Android 7.0; SM-T580 Build/NRD90M; wv)
AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/65.0.3325.109 Safari/537.36 [Pinterest/Android]"
ECDHE-RSA-AES128-GCM-SHA256 TLSv1.2
```

### Logstash config

We will start with Logstash S3 input plugin:

```
# /etc/logstash/conf.d/s3_elastic.conf
input {
  s3 {
    aws_credentials_file => "./aws_credentials_file.yml"
    bucket               => "my-elb-logs"
    prefix               => "subfolder/path/here/"
    sincedb_path         => "./data/plugins/inputs/s3/sincedb_s3_elastic"    
  }
}
```

Logstash uses sincedb file to keep track of where it is in log file processing.  If we stop Logstash and start it hours later it will process the logs that accumulated during that time period.  

Then we configure Elasticsearch output plugin.  `stdout` can be used for debugging.  We will discuss the `[@metadata][index]` further in this article.  

```
# /etc/logstash/conf.d/s3_elastic.conf
output {
  stdout { codec => rubydebug { metadata => true } }
  elasticsearch {
    hosts     => [127.0.0.1]
    user      => "elastic"
    password  => "password-here"
    index     => "%{[@metadata][index]}"
  }
}
```

For filtering we will start with grok and then remove unnecessary fields:

```
# /etc/logstash/conf.d/s3_elastic.conf
filter {
  grok  {    
     match        => { "message" => "%{ELB_ACCESS_LOG}"}
     remove_field => [ "elb", "backendip", "backendport", ...]
  }
}
```

Logstash gives us reliable grok patterns to parse each log file line into Event object.  Now our data looks like this:

```
{
       "request" => "http://site1.mysystem.com/api?foo=bar",
          "path" => "/api",
    "@timestamp" => 2018-05-10T18:26:13.276Z,
      "response" => 200,
      "clientip" => "73.157.179.139",
        "params" => "?foo=bar",
        "message" => "...",
        ...
}
```

### Ruby code

We need to implement business logic to validate and transform our data.  Given the simple requirements of this use case we could have done it without Ruby but it gives us more flexibility and control.  We need to extract the URL host which will be used as part of the index name.  We also want to grab `foo` parameter from the URL.  We can start with inline Ruby code.  

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf
filter {
  ruby {
    code =>   "
              require 'uri'
              uri = URI(event.get('request'))
              event.set('host', uri.host)
              foo_value = CGI::parse(event.get('params'))['foo'].first
              event.set('foo', foo_value)              
              "
  }
{% endhighlight %}

Now our Event object contains a separate `host` and `foo` fields:

```
{
       "request" => "http://site1.mysystem.com/api?foo=bar",
          "path" => "/api",
          ...
          "host" => "site1.mysystem.com",
           "foo" => "bar",
}
```

Placing code in a config file is not a scalable approach and it will be difficult to test.  Fortunately latest version of the Ruby filter plugin supports referencing separate Ruby script from .conf file.  And we can test our code with automated tests.  We modify the .conf file by specifying path to Ruby script.  

```
# /etc/logstash/conf.d/s3_elastic.conf file
filter {
  ruby {
    path => "/etc/logstash/ruby/s3_elastic.rb"
    # script_params => {  }
  }
}
```

One difference is that now Ruby has to return an array of Event objects from the external script file.  

```
# /etc/logstash/ruby/s3_elastic.rb
require 'uri'
# the value of `params` is the value of the hash passed to `script_params`
# in the logstash configuration
def register(params)
end
# the filter method receives an event and must return a list of events.
# Dropping an event means not including it in the return array,
# while creating new ones only requires you to add a new instance of
# LogStash::Event to the returned array
def filter(event)
  uri = URI(event.get('request'))
  event.set('host', uri.host)
  foo_value = CGI::parse(event.get('params'))['foo'].first
  event.set('foo', foo_value)
  return [event]
end
test 'valid test' do
  parameters { {  } }
  in_event do { 'request' => 'http://site1.mysystem.com/api?foo=bar' } end
  expect('params') do |events|
    events.first.get('host') == 'site1.mysystem.com'
    events.first.get('foo') == 'bar'
  end
end
```

We can run automated tests by specifying -t param like this `logstash -f /etc/logstash/conf/s3_redis.conf -t`.

```
[logstash.filters.ruby.script] Test run complete
{:script_path=>"/etc/logstash/ruby/s3_redis.rb",
  :results=>{:passed=>1, :failed=>0, :errored=>0}}
Configuration OK
[logstash.runner] Using config.test_and_exit mode. Config Validation Result: OK.
Exiting Logstash
```

We need to determine which date to use in the index name as we cannot assume the current date.  For that we will use the `timestamp` field (`2018-05-10T18:26:13.276Z`).  We also can extract the business logic for determining index into a separate method.  In case there are any errors we default to today's date.  

```
# /etc/logstash/ruby/s3_elastic.rb
def filter(event)
  ...
  event.set("[@metadata][index]", get_index(event))
  return [event]
end
def get_index event
  host = event.get('host')
  date = event.get('timestamp').split('T').first
  "#{host}-#{date}"
rescue
  "#{host}-#{Time.now.strftime("%Y.%m.%d")}"
end
...
```

We are using `event.set` to create `[@metadata][index]` field.  It will not be saved with the document but can be used in our .conf file to specify index.  This approach allows us to keep the logic of combining host with date in the same Ruby method.  

### Aggregations

We can now use Kibana (or even curl) to run aggregations.  We can query across all indexes and tell us which URL paths were accessed and how often.  

```
POST /*/_search?size=0
{
  "aggs" : {
    "path_count" : {
      "terms" : {
        "field" : "path.keyword"
      }
    }
  }
}
```

Data will come back like this:

```
{
  "took": 709,
  "timed_out": false,
  "_shards": {
    ...
  },
  "hits": {
    ...
  },
  "aggregations": {
    "path_count": {
      ...
      "buckets": [
        {
          "key": "/api",
          "doc_count": 913281
        },
        {
          "key": "/search",
          "doc_count": 742813
        },
        ...
      ]
    }
  }
}
```

If we want to query data for specific customers or dates we need to specify it as index pattern in `POST /*2018.05.10/_search?size=0`.  Kibana also allows us to build visualizations and dashboards based on these aggregations.  

### Links
* https://www.elastic.co/blog/do-you-grok-grok
* https://www.elastic.co/guide/en/logstash/current/event-api.html
* https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html
* https://www.elastic.co/blog/moving-ruby-code-out-of-logstash-pipeline
* https://github.com/logstash-plugins/logstash-patterns-core/blob/master/patterns/aws
