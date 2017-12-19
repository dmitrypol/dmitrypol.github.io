---
title: "Redis with ElasticSearch"
date: 2017-12-18
categories: redis elasticsearch
---

[Redis](https://redis.io/) and [ElasticSearch](https://www.elastic.co/) are powerful technologies with different strengths.  They are also very flexible and can be used for a variety of purposes.  We will explore different ways to integrate them.  

Redis has speed and powerful data structures.  It can almost function as an extension of application memory but shared across processes / servers.  The downside is that records can ONLY be looked up by key.  Our applications can easily store all kinds of interesting data in Redis.  But if this data needs to be extracted and aggregated in different ways that requires writing code.  There is no easy way to do adhoc analysis (like writing SQL queries).  

ELK is ElasticSearch, Logstash and Kibana.   ElasticSearch stores data in indexes and supports powerful searching capabilities.  Logstash is an ETL pipeline to move data to and from different data sources (including Redis).  Kibana helps us build rich dashboards and do adhoc searches.  These tools are used not just by developers but by data analysts and devops engineers who often have different skillset.

* TOC
{:toc}

### Search for products

We are building a website for a nationwide coffee shop chain.  The first requirement is enabling users to search for various products.  We will use Ruby on Rails with [searchkick](https://github.com/ankane/searchkick) library to simplify ElasticSearch integration.  

{% highlight ruby %}
# app/models/
class Product < ApplicationRecord
  searchkick callbacks: :async, index_name: 'products'
  # specify searchable fields
  def search_data
    {
      name:         name,
      description:  description,
      price:        price,
    }
  end  
end
{% endhighlight %}

We specified `callbacks: :async` option.  If we configure [Sidekiq](https://github.com/mperham/sidekiq) it will use Redis to queue a background job to update the documents in `products` index when record in primary DB is modified.  

{% highlight ruby %}
# app/controllers/
class API::ProductSearchController
  def show
    ProductSearch.new.perform params[:query]
  end
end
# app/services/
class ProductSearch
  def perform query
    cache_key = [self.class.name, __method__, query]
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      Product.search(query, fields: [name, description], ...).to_json
    end
  end
end
{% endhighlight %}

We are also caching JSON output of the `ProductSearch.new.perform` method call in Redis using query param to generate cache_key.  The downside is that any changes to products will take up to an hour to appear in cached search results.  We can build a callback so when a record is updated in primary DB it not only updates the index but also flushes cache.  To keep things simple we will delete all Redis keys matching `ProductSearch:perform:*` pattern but this needs to be improved for scaling.    

{% highlight ruby %}
class Product < ApplicationRecord
  aftr_save :flush_search_cache
private
  def flush_search_cache
    cache_keys = REDIS.keys 'ProductSearch:perform:*'
    cache_keys.each do |key|
      Rails.cache.delete key
      # or force regeneration with Rails.cache.fetch(key, force: true)
    end
  end
end
{% endhighlight %}

### Search by zipcode

Another important feature is enabling users to find local stores by zipcode.  Both Redis and ElasticSearch support geolocation searches.  We need to map zipcodes to lon/lat coordinates.  Here is a free [data source](https://gist.github.com/erichurst/7882666)

#### Redis geo

{% highlight ruby %}
CSV.foreach("data/zip_lon_lat.csv", headers: true) do |row|
  REDIS.geoadd 'zip_lon_lat', row['lon'].to_f, row['LAT'].to_f, row['ZIP'].to_s
end
# data in Redis
{"db":0,"key":"zip_lon_lat","ttl":-1,"type":"zset","value":[
  ["96799",1.147461274922875e+15],
  ["96737",1.184332805872164e+15],
  ...
  ["96950",4.103298315066677e+15]],"size":858113}
{% endhighlight %}

One option is to use Redis to find zipcodes w/in 5 mile radius and then query primary DB for stores in those zipcodes.  

{% highlight ruby %}
class StoreLocator
  def initialize zipcode
    @zipcode = zipcode
    @distance = 5
  end
  def perform
    zipcodes = REDIS.georadiusbymember('zip_lon_lat', @zipcode, @distance, 'mi')
    Store.where(zipcode: zipcodes)
  end
end
# georadiusbymember returns for 90210
["90073", "90024", "90095", "90067", "90212", "90077", "90210", "90211",
"90048", "90036", "90069", "90046", "91403", "91423", "91604", "91607", "91602",
"91608", "90025", "90034", "90064", "90035", "90049"]
{% endhighlight %}

#### ElasticSearch geo

Alternatively we can use ElasticSearch geo search.  We need to create an index and specify lon/lat for each zipcode.  Since we already have lon/lat stored in Redis we can use it for quick lookup (vs parsing CSV file).

{% highlight ruby %}
class ZipLonLat
  def perform zipcode
    REDIS.geopos('zip_lon_lat', zipcode).first
  end
end
class Store < ApplicationRecord
  searchkick callbacks: :async, index_name: 'stores'
  def search_data
    lon_lat = ZipLonLat.new.perform zipcode
    {
      zipcode:  zipcode,
      lon:      lon_lat.try(:first),
      lat:      lon_lat.try(:second),
    }
  end
end
{% endhighlight %}

We run `Store.reindex`, verify that data shows up in ElasticSearch and modify `StoreLocator`.

{% highlight ruby %}
class StoreLocator
  def perform
    lon_lat = ZipLonLat.new.perform @zipcode
    lat = lon_lat.try(:second)
    lon = lon_lat.try(:first)
    Store.search("*",
      where: { location: {near: {lat: lat, lon: lon}, within: "#{@distance}mi"} }
    )
  end
end
{% endhighlight %}

Now we can take advantage of rich ElasticSearch querying capabilities including [geo queries](https://www.elastic.co/guide/en/elasticsearch/reference/current/geo-queries.html), get the IDs of matching stores and display data from primary DB on our website.

### ETL

The next requirement is to record which zipcodes are searched most often and when searches are performed (by hour_of_day and day_of_week).  We will use [leaderboard](https://github.com/agoragames/leaderboard) library to track searches and [minuteman](https://github.com/elcuervo/minuteman) to count when those searches occur.  

{% highlight ruby %}
# config/initializers/redis.rb
Minuteman.configure do |config|
  config.patterns = {
    # custom config
    hour_of_day: -> (time) { 'hour_of_day:' + time.strftime("%H") },
    day_of_week: -> (time) { 'day_of_week:' + time.strftime("%a") },
  }
end
# app/service/
class StoreLocator
  def perform
    Leaderboard.new('ldbr:zipcode_searched').change_score_for(zipcode, 1)
    Minuteman.add("search_by_zip", Time.now)
    ...
  end
end
{% endhighlight %}

Data in Redis will be stored like this:

{% highlight ruby %}
{"db":0,"key":"ldbr:zipcode_searched","ttl":-1,"type":"zset",
  "value":[["98113",11.0],...,["98184",55.0]]...}
#
{"db":0,"key":"Minuteman::Counter::search_by_zip:day_of_week:Sun","ttl":-1,
  "type":"string","value":"24"...}
{"db":0,"key":"Minuteman::Counter::search_by_zip:hour_of_day:06","ttl":-1,
  "type":"string","value":"11"...}
{% endhighlight %}

But our internal business users do not want to look at raw data in JSON.  Our choice is writing custom dashboard or pulling data into ElasticSearch and leveraging Kibana.  Once it's in ElasticSearch we can also combine it with other data sources.  

{% highlight ruby %}
ES_CLIENT = Elasticsearch::Client.new
# app/jobs/
class RedisElasticEtlJob < ApplicationJob
  def perform
    zipcode_searched
    hour_of_day
    day_of_week
  end
private
  def zipcode_searched
    Leaderboard.new('ldbr:zipcode_searched').all_members.each do |zipcode|
      ES_CLIENT.index index: 'zipcode_searched', id: zipcode[:member],
        body: { count: zipcode[:score] }
    end
  end
  def hour_of_day
    time = Time.now
    count = Minuteman.count("search_by_zip").hour_of_day(time).count
    ES_CLIENT.index index: 'hour_of_day', id: time.hour,
      body: { count: count}
  end
  def day_of_week
    time = Time.now
    count = Minuteman.count("search_by_zip").day_of_week(time).count
    ES_CLIENT.index index: 'day_of_week', id: time.strftime('%a'),
      body: { count: count }
  end
end
{% endhighlight %}

We are specifying our aggregation metrics (zipcode, hour_of_day, day_of_week) as the ID of ElasticSearch document.  

### Kibana dashboard

{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}



https://dev.maxmind.com/geoip/geoip2/geolite2/
https://github.com/yhirose/maxminddb


Unfortunately https://github.com/redis/redis-rb does not have native support for `GEO*`.  Other gems such as https://github.com/etehtsea/oxblood do support these commands.  

https://cristian.regolo.cc/2015/07/07/introducing-the-geo-api-in-redis.html
