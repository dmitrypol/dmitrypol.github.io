---
title: "RediSearch and time series data"
date: 2018-04-01
categories: redis
---

In previous [post]({% post_url 2018-01-16-elasticsearch-redis-streams %}) we explored integration between Redis and ElasticSearch for time series data.  Now we will take deeper dive into how to search for time series data w/in Redis with RediSearch module.  

We will be using the same POC app for nationwide retail chain built using Ruby on Rails framework.  We want to search various user interactions on the website such as which zipcode are people coming from and which products are they looking for.  

A common approach for time series data is to create periodic (usually daily) indexes.  Then we can run regular process where older indexes are removed (or moved to different data store) and we only keep the last X days of data in the primary Redis DB.  

* TOC
{:toc}

### Separate daily indexes

To encapsulate logic we will create a separate class to create / insert records into appropriate indexes.

{% highlight ruby %}
# config/initializers/redis.rb
REDI_SEARCH = Redis.new host: 'localhost', ...
# app/services/
class RediSearchClient
  def initialize time: nil, index_per_day: nil, index_pattern: nil
    @time = time || Time.now
    @index_per_day = index_per_day || true
    @index_pattern = index_pattern || 'search_log'
  end
  def create
    return if index_exists? == true
    REDI_SEARCH.call('FT.CREATE', get_index, 'SCHEMA', 'zipcode', 'TEXT',
      'product', 'TEXT')
  end
  def add id: , zipcode: , tag:
    create
    REDI_SEARCH.call('FT.ADD', get_index, id, '1.0', 'FIELDS',
      'zipcode', zipcode, 'product', product)
  end
private
  def index_exists?
    return true if REDI_SEARCH.call("FT.INFO", get_index)
    # need to handle the error if index doex not exist
  end
  def get_index
    return "#{@index_pattern}:#{@time.strftime("%Y-%m-%d")}" if @index_per_day
    return @index_pattern
  end
end
{% endhighlight %}

We are passing in time because data processing might be delayed and we do not want to insert data from yesterday into today's index.  We are also passing in optional parameters to determine the naming pattern for indexes and whether we will create daily indexes (by appending date stamp to index pattern).

To query across multiple indexes we will have to make separate requests to Redis using `FT.SEARCH` command and then merge the results in our code.  To return list of indexes we get Redis keys that match a pattern.  

{% highlight ruby %}
class RediSearchClient
  ...
  def search query: , limit:
    output = {}
    get_indexes.each do |index|
      result = REDI_SEARCH.call('FT.SEARCH', index, query, 'LIMIT', 0, limit).drop(1)
      output.merge! ( Hash[result.each_slice(2).to_a] ) unless result.empty?
    end
    return output
  end
private
  ...
  def get_indexes
    REDI_SEARCH.call("keys", "idx:#{@index_pattern}*").map do |index|
      index.split(':').drop(1).join(':')
    end
  end
end
{% endhighlight %}

Data in Redis will look like this.  For each date we will have one `ft_index0` and multiple `ft_invidx` keys.

{% highlight ruby %}
idx:search_log:YYYY-MM-DD      ft_index0
ft:search_log:YYYY-MM-DD/java  ft_invidx
ft:search_log:YYYY-MM-DD/redis ft_invidx
{% endhighlight %}

To purge old indexes we will call `FT.DROP` passing appropriate time (`Time.now - X.days`) to class initializer.  

{% highlight ruby %}
class RediSearchClient
  ...
  def drop
    REDI_SEARCH.call('FT.DROP', get_index)
  end  
end
{% endhighlight %}

Once we drop an index RediSearch will remove `ft_index0` and `ft_invidx` keys plus Redis Hashes used to store documents themselves.  

This code still needs a lot of work to support other methods in RediSearch and to further abstract the index SCHEMA and document fields.  But it is simply meant to show a pattern we can follow to manage these multiple related indexes in our application.  

### One index for all data

We might not want the challenge of managing multiple indexes and merging the results from multiple searches.  Instead we could use one index and build logic to delete old documents.  

We can still use the same class only now we specify `@index_per_day = false` which will exclude date stamp from index name when creating records.  

`FT.SEARCH` returns number of records matching our query as the first parameter.  We will use it to loop through all documents in the index, check their IDs (derived from timestamps) and use `FT.DEL` command to remove each document.   

{% highlight ruby %}
class RediSearchClient
  ...
  def purge
    ttl = ((Time.now - X.days).to_f.round(3)*1000).to_i
    deleted_count = 0
    num = 10
    total_docs = REDI_SEARCH.call('FT.SEARCH', get_index, '*', 'NOCONTENT').first
    (total_docs/num).times do |i|
      offset = (num * i) - deleted_count
      document_ids = REDI_SEARCH.call('FT.SEARCH', get_index, '*', 'NOCONTENT',
        'LIMIT', offset, num).drop(1)
      document_ids.each do |id|
        if id.to_i < ttl
          REDI_SEARCH.call('FT.DEL', get_index, id, 'DD')
          deleted_count += 1
        end
      end
    end
  end
end
{% endhighlight %}

Specifying `DD` will also remove the document (stored in Redis Hash).  It will leave behind the `ft:search_log/redis ft_invidx` keys.  

The big downside of this approach is the necessity of making multiple Redis calls to query and remove documents.  It is MUCH more complex when compared to Redis TTL approach of expiring keys.  

### Links
* http://redisearch.io/
* https://github.com/danni-m/redis-timeseries
* https://redis.io/commands/ttl





{% highlight ruby %}

{% endhighlight %}
