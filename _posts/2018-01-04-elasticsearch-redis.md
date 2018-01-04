---
title: "ElasticSearch and Redis"
date: 2018-01-04
categories: elastic redis
---

[ElasticSearch](https://www.elastic.co/) and [Redis](https://redis.io/) are powerful technologies with different strengths.  They are very flexible and can be used for a variety of purposes.  We will explore different ways to integrate them.  

ELK is ElasticSearch, Logstash and Kibana.   ElasticSearch stores data in indexes and supports powerful searching capabilities.  Logstash is an ETL pipeline to move data to and from different data sources (including Redis).  Kibana helps us build rich dashboards and do adhoc searches.  These tools are used not just by developers but by data analysts and devops engineers who often have different skillset.

Redis has speed and powerful data structures.  It can almost function as an extension of application memory but shared across processes / servers.  The downside is that records can ONLY be looked up by key.  Our applications can easily store all kinds of interesting data in Redis.  But if this data needs to be extracted and aggregated in different ways that requires writing code.  There is no easy way to do adhoc analysis (like writing SQL queries).  

* TOC
{:toc}

### Search for products

We are building a website for a nationwide shop chain.  The first requirement is enabling users to search for various products (in our case coffee brands).  We will use Ruby on Rails with [searchkick](https://github.com/ankane/searchkick) library to simplify ElasticSearch integration.  We set `callbacks: :async` option.  If we configure [Sidekiq](https://github.com/mperham/sidekiq) it will use Redis to queue a background job to update the documents in `products` index when record in primary DB is modified.  

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

We are also caching JSON output of the `ProductSearch.new.perform` method call in Redis using query param to generate cache_key.  

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

The downside is that any changes to products will take up to an hour to appear in cached search results.  We can build a callback so when a record is updated in primary DB it not only updates the index but also flushes cache.  To keep things simple we will delete all Redis keys matching `ProductSearch:perform:*` pattern but this needs to be improved for scaling.  To be honest this caching technique might be more trouble than it's worth.  

{% highlight ruby %}
class Product < ApplicationRecord
  after_save :flush_search_cache
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

Another important feature is enabling users to find stores by zipcode.  Both Redis and ElasticSearch support geolocation searches.  We need to map zipcodes to lon/lat coordinates.  Here is a free [data source](https://gist.github.com/erichurst/7882666)

#### Redis geo

{% highlight ruby %}
CSV.foreach("data/zip_lon_lat.csv", headers: true) do |row|
  REDIS.geoadd 'zip_lon_lat', row['LON'].to_f, row['LAT'].to_f, row['ZIP'].to_s
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
class Store < ApplicationRecord
  searchkick callbacks: :async, index_name: 'stores'
  def search_data
    {
      zipcode:  zipcode,
      lon:      lon_lat.try(:first),
      lat:      lon_lat.try(:second),
    }
  end
  def lon_lat
    REDIS.geopos('zip_lon_lat', @zipcode).first
  end
end
{% endhighlight %}

We run `Store.reindex`, verify that data shows up in ElasticSearch and modify `StoreLocator`.

{% highlight ruby %}
class StoreLocator
  def perform
    lon_lat = REDIS.geopos('zip_lon_lat', @zipcode).try(:first)
    lat = lon_lat.try(:second)
    lon = lon_lat.try(:first)
    Store.search("*",
      where: { location: {near: {lat: lat, lon: lon}, within: "#{@distance}mi"} }
    )
  end
end
{% endhighlight %}

Each document looks like this in ElasticSearch:

{% highlight ruby %}
{
  "_index": "stores",
  ...
  "_source": {
    "zipcode": "98116",
    "location": {
      "lat": 47.57424607502233,
      "lon": -122.40022391080856
    }
  }
}
{% endhighlight %}

Now we can take advantage of rich ElasticSearch querying capabilities including [geo queries](https://www.elastic.co/guide/en/elasticsearch/reference/current/geo-queries.html), get the IDs of matching stores and display data from the primary DB.

### Search by product AND geo

Now our users want to know which stores in specific area sell particular products.  And they are not sure how to exactly spell the product name.  We also want to make our indexes more powerful first class objects, not just something related to model.

Fist we create a model mapping which products are available in which stores.  Then we will integrate with [chewy](https://github.com/toptal/chewy) library which is a little different than `searchkick` we used before.  

{% highlight ruby %}
# app/models/
class ProductStore < ApplicationRecord
  belongs_to :product
  belongs_to :store
  update_index('product_store#product_store') { self }
end
# app/chewy/
class ProductStoreIndex < Chewy::Index
  define_type ProductStore.includes(:product, :store) do
    field :product_name,  type: 'text', value: ->{ product.name }
    field :store_zipcode, type: 'text', value: ->{ store.zipcode }
    field :store_location, type: 'geo_point' do
      field :lon, value: ->{ store.lon_lat.try(:first) }
      field :lat, value: ->{ store.lon_lat.try(:second) }
    end    
  end
end
{% endhighlight %}

`update_index` method ensures that ElasticSearch documents get updated when we update DB records.  Chewy supports async updates to indexes via background jobs.  Data in ElasticSearch looks like this:

{% highlight ruby %}
{
  "_index": "product_store",
  ...
  "_source": {
    "product_name": "American Cowboy",
    "store_zipcode": "98174",
    "store_location": {
      "lat": "47.6045689442515112",
      "lon": "-122.33535736799240112"
    }
  }
}
{% endhighlight %}

We modify our search code

{% highlight ruby %}
class StoreLocator
  def initialize zipcode:, query:
    @zipcode = zipcode
    @query = query
    @distance = 5
    lon_lat = REDIS.geopos('zip_lon_lat', @zipcode).first
    @lat = lon_lat.try(:second)
    @lon = lon_lat.try(:first)    
  end
  def perform
    ProductStoreIndex
      .query(fuzzy: {product_name: @query})
      .filter(geo_distance: {
        distance: "#{@distance}mi",
        store_location: {lat: @lat, lon: @lon}
        })
      .order(_geo_distance: {store_location: {lat: @lat, lon: @lon} })
  end
end
{% endhighlight %}

Now we can do `StoreLocator.new(zipcode: 98174, query: 'kowboy').perform` to find stores near 98174 zipcode that sell `American Cowboy` coffee.  

### Autocomplete

This problem can also be solved with both ElasticSearch and Redis.  

#### Redis

To keep data in-sync between primary DB and Redis autocomplete keys we will implement a separate class and leverage it from model callbacks.  We will begin our keys with the first 2 letters of each term and store up to last latter.  We will also be using Sorted Set scores to give higher weight to more common terms.  

{% highlight ruby %}
# app/models/
class Product < ApplicationRecord
  after_save      { AutocompleteRedis.new.add    name }
  before_destroy  { AutocompleteRedis.new.remove name }
end
# app/services/
class Autocomplete
  def initialize
    @namespace = 'autocomplete'
  end
  def search prefix:, num: 10
    REDIS.zrevrange "#{@namespace}:#{prefix.try(:downcase)}", 0, num - 1
  end
  def add_all klass, method
    klass.titleize.constantize.all.each do |object|
      add object.send(method)
    end
  end
  def add term
    add_remove term, 'add'
  end
  def remove_all klass, method
    klass.titleize.constantize.all.each do |object|
      remove object.send(method)
    end
  end
  def remove term
    add_remove term, 'remove'
  end
private
  def add_remove term, type
    term.downcase!
    first_letter = term[0]
    1.upto(term.length - 2) do |i|
      prefix = first_letter + term[1, i]
      if type == 'add'
        REDIS.incrby("#{@namespace}:#{prefix}", 1, term)
      elsif type == 'remove'
        REDIS.zrem("#{@namespace}:#{prefix}", term)
      end
    end
  end
end
{% endhighlight %}

We can add / remove all keys by running `AutocompleteRedis.new.add_all('product', 'name')` (or `remove_all`).  Data in Redis will be stored in multiple sorted sets.  

{% highlight ruby %}
{"db":0,"key":"autocomplete:am","ttl":-1,"type":"zset","value":
  [["american cowboy",1.0],["american select",1.0]],...}
{"db":0,"key":"autocomplete:ame","ttl":-1,"type":"zset","value":
  [["american cowboy",1.0],["american select",1.0]],"...}
...
{"db":0,"key":"autocomplete:bl","ttl":-1,"type":"zset","value":
  [["blacktop light",1.0],["bluebery treat",1.0]],"...}
{"db":0,"key":"autocomplete:blu ","ttl":-1,"type":"zset","value":
  [["bluebery treat",1.0]],"...}
{% endhighlight %}

We can call `AutocompleteRedis.new.search prefix: 'am'` and get back JSON `["american select", "american cowboy"]`.  

#### ElasticSearch

We will build a special index in ElasticSearch using Chewy library.  Read [here](https://www.elastic.co/guide/en/elasticsearch/guide/current/_index_time_search_as_you_type.html) about `filter` and `analyzer` configuration.  

{% highlight ruby %}
# app/models/
class Product < ApplicationRecord
  update_index('autocomplete#product') { self }
end
# app/chewy/
class AutocompleteIndex < Chewy::Index
  settings analysis: {
    filter: {
      autocomplete_filter: {
          type:     "edge_ngram",
          min_gram: 1,
          max_gram: 20
      }
    },
    analyzer: {
        autocomplete: {
            type:      "custom",
            tokenizer: "standard",
            filter: [
                "lowercase",
                "autocomplete_filter"
            ]
        }
    }
  }
  define_type Product do
    field :name, type: 'text', analyzer: 'autocomplete'
  end
end
{% endhighlight %}

Now `AutocompleteIndex.query(match: {name: 'am'})` returns `American Cowboy`, `American Select` AND `Red America` products.  ElasticSearch is able to use the second word in the product name to match against.  

### ETL

Until now we were moving data between primary DB and Redis or ElasticSearch.  Now we will ETL data between Redis and ElasticSearch.  

#### Redis to ElasticSearch

The next requirement is to record which zipcodes are searched most often and when searches are performed (by hour_of_day and day_of_week).  To capture data in Redis we will use [leaderboard](https://github.com/agoragames/leaderboard) library to track searches and [minuteman](https://github.com/elcuervo/minuteman) to count when those searches occur.  

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

This will be very fast and data in Redis will be stored like this:

{% highlight ruby %}
{"db":0,"key":"ldbr:zipcode_searched","ttl":-1,"type":"zset",
  "value":[["98113",11.0],...,["98184",55.0]]...}
#
{"db":0,"key":"Minuteman::Counter::search_by_zip:day_of_week:Sun","ttl":-1,
  "type":"string","value":"24"...}
{"db":0,"key":"Minuteman::Counter::search_by_zip:hour_of_day:06","ttl":-1,
  "type":"string","value":"11"...}
{% endhighlight %}

But our internal business users do not want to look at raw data.  Our choice is writing custom dashboard or pulling data into ElasticSearch and leveraging Kibana.  Once it's in ElasticSearch we can also combine it with other data sources.  We will use [elasticsearch-ruby](https://github.com/elastic/elasticsearch-ruby) library directly since this data does not related to our application models.  

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

#### ElasticSearch to Redis

In our ElasticSearch cluster we have captured data from logs that contain IP and UserAgent.  Combination of IP and UserAgent can be used to fairly uniquely identify users.  Our next business requirement is to implement functionality where our website displays slightly different UI to users that we believe have visited our site before.  

Now we will leverage Logstash with various plugins as our ETL pipeline.  We will be using [elasticsearch input plugin](https://www.elastic.co/guide/en/logstash/current/plugins-inputs-elasticsearch.html), [redis output plugin](https://www.elastic.co/guide/en/logstash/current/plugins-outputs-redis.html) and [ruby filter plugin](https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html) to transform the data into format expected by ActiveJob background job framework and pushing it straight into a Redis List data structure.  

{% highlight ruby %}
input {
  elasticsearch {
    hosts => "localhost"
    index => "logs"
  }
}
filter {
  ruby {
    code => "
      event.set('jid', SecureRandom.hex(12))
      event.set('created_at', Time.now.to_f)
      event.set('enqueued_at', Time.now.to_f)
      event.set('class', 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper')
      event.set('wrapped', 'UniqVisJob')
      event.set('queue', 'low')
      args = [{
        'job_class' => 'UniqVisJob',
        'job_id' => SecureRandom.uuid,
        'provider_job_id' => 'null',
        'queue_name' => 'low',
        'priority' => 'null',
        'arguments' => [ event.get('client_ip'), event.get('user_agent') ],
        'executions' => 0,
        'locale' => 'en'
      }]
      event.set('args', args)
      "
    add_field => {
      "retry" => true
    }
    remove_field => [ "@version", "@timestamp", 'client_ip', 'user_agent' ]
  }
}
output {
  redis {
    data_type => "list"
    key => "queue:low"
    db => 0
  }
}
{% endhighlight %}

Now we create a very simple job ran via Sidekiq that will hash IP & UA and also set Redis keys to expire in a week.  

{% highlight ruby %}
class UniqVisJob < ApplicationJob
  queue_as :low
  def perform ip, ua
    key = "uniq_vis:" + Digest::MurmurHash1.hexdigest("#{ip}:#{ua}")
    REDIS.setex key, 3600*24*7, 1
  end
end
{% endhighlight %}

Data in Redis will look like this

{% highlight ruby %}
{"db":0,"key":"uniq_vis:cbfb868b","ttl":..,"type":"string","value":"1","size":1}
{"db":0,"key":"uniq_vis:b68ef58c","ttl":..,"type":"string","value":"1","size":1}
{% endhighlight %}

Read here on manually creating [messages for Sidekiq](https://github.com/mperham/sidekiq/wiki/FAQ#how-do-i-push-a-job-to-sidekiq-without-ruby) and using [Ruby in Logstash](https://fabianlee.org/2017/04/24/elk-using-ruby-in-logstash-filters/)

In future posts I will cover other technologies such as [RediSearch module](http://redisearch.io/) and [ElasticSearch Kibana dashboard](https://www.elastic.co/products/kibana).  

### Links

* https://dev.maxmind.com/geoip/geoip2/geolite2/
* https://github.com/yhirose/maxminddb
* https://code.tutsplus.com/tutorials/geospatial-search-in-rails-using-elasticsearch--cms-22921
* https://github.com/etehtsea/oxblood - supports GEO* commands
* https://cristian.regolo.cc/2015/07/07/introducing-the-geo-api-in-redis.html
* https://www.elastic.co/blog/found-fuzzy-search
* https://github.com/sethherr/soulheart - library for autocomplete
* https://stackoverflow.com/questions/29572654/how-to-view-redis-data-inside-rails-application-using-soulmate

{% highlight ruby %}

{% endhighlight %}
