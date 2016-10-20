---
title: "redis_app_join ruby gem"
date: 2016-10-19
categories: redis
---

Last week I wrote a post [Redis as temp cache for application-side joins]({% post_url 2016-10-11-redis-application-join %}).  I kept thinking of ways to make the process easier so I decided to create a [redis_app_join](https://rubygems.org/gems/redis_app_join) gem.  

[GitHub page](https://github.com/dmitrypol/redis_app_join) has examples on how to use it.  In this post I want to explain my reasoning behind the gem and where I see it going.  

First, let's acknowledge that if we can write a good SQL JOIN we should probably use it to grab the data in one request.  Unfortunately that's not always possible (my current challenge is using a NoSQL DB).  Below I want to describe additional situations where this approach could be useful.  

### Querying separate DBs

When we build simple [Ruby on Rails](http://rubyonrails.org/) or [Python Django](https://www.djangoproject.com/) apps there is usually only one DB behind it.  But large IT organizations have mulitiple software systems written in different languages and using different databases.  Frequently same DBs are used by multiple applications and one application can talk to multiple DBs.  I worked in environments where we used MS SQL Server, Oracle, Postgres and MySQL.  The business stakeholders did not care where the data was stored, they just needed to see their reports.  

To aggregate data we built complex [ETL](https://en.wikipedia.org/wiki/Extract,_transform,_load) tools but they can be slow.  In one org data had to flow through 3 separate DBs (impacting other applications that used these DBs) before being aggregated in Oracle data warehouse.  The process took most of the day and impacted ability to make business decisions.

Let's imagine that we have a group of accounts.  In DB1 it's `account.id` but in DB2 the corresponding records can be found in `Client` table and need to use `external_id` for lookup.  DB2 also contains other important data attributes.  BTW, here is a good article on how to [connect to multiple DBs from Rails app](http://stackoverflow.com/questions/1825844/multiple-databases-in-rails).  Our biz users need to aggregate account data in one report.

{% highlight ruby %}
class EtlRunner
  include RedisAppJoin
  def perform
    query1
    query2
  end
private
  def query1
    # query 1st DB
    accounts = Account.where(...).only(:name, :external_id)
    @accounts_external_ids = accounts.pluck(:id)
    cache_records(records: accounts)
  end
  def query2
    # query 2nd DB
    clients = Client.in(external_id: @accounts_external_ids).only(:description)
    cache_records(records: clients)
  end
end
{% endhighlight %}

Data will be cached like this in Redis:

{% highlight ruby %}
# record from 1st DB
{"db":0,"key":"appjoin:Account:id1","ttl":-1,"type":"hash",
  "value":{"name":"accounts1","external_id":"eid1",...}}
# record from 2nd DB, eid1 is part of the key
{"db":0,"key":"appjoin:Client:eid1","ttl":-1,"type":"hash",
  "value":{"description":"client description1",...}}
{% endhighlight %}

We can now loop through the records and combine the data like this `client = fetch_records(record_class: 'Client', record_ids: [account.external_id]).first`.  But we NOT making separate DB queries for each account which signifiantly speeds up the process and decreases DB load.  

### Querying external APIs

Now let's imagine that we need to query an external API to get more data for our accounts.  At a previous job I worked in internet advertising.  We created accounts in our systems and then pushed them to Google AdWords.  We stored IDs assigned by Google in our DB and every morning queried Google reporting APIs.  Similar process was done for Bing and other ad networks.

{% highlight ruby %}
class ApiDownloader
  include RedisAppJoin
  def perform
    Account.where(...).only(:google_id).find_in_batches(batch_size: 100) do |batch|
      google_account_ids = accounts.pluck(:google_id)
      google_accounts = GoogleData.new.perform(google_account_ids)
      cache_records(records: google_accounts, record_class: 'GoogleAccount')
    end
  end
end
class GoogleData
  def perform(account_ids)
    # download the data
  end
end
{% endhighlight %}

Since it's not an [ActiveModel](http://api.rubyonrails.org/classes/ActiveModel/Model.html) we need to specify `record_class` to ensure unique keys will be created in Redis.

{% highlight ruby %}
# Google response JSON
{"id": "google_id1", "date": "10/16/2016", "clicks": "5","spent": "3.24"},
{"id": "google_id2", "date": "10/16/2016", "clicks": "3","spent": "2.11"},
# data in Redis
{"db":0,"key":"appjoin:GoogleAccount:google_id1","ttl":-1,"type":"hash",
  "value":{"date":"10/16/2016","clicks":"5","spent":"3.24"}}
{"db":0,"key":"appjoin:GoogleAccount:google_id2","ttl":-1,"type":"hash",
  "value":{"date":"10/16/2016","clicks":"3","spent":"2.11"}}
{% endhighlight %}

With this approach we can make bulk API requests downloading data in batches (cheaper and faster).  We could have persisted the data to a SQL DB but since we are already using Redis why not store it there temporarily?  Now we can get data on clicks and spent using `goog_acnt_data = fetch_records(record_class: 'GoogleAccount', record_ids: [account.google_id]).first`.  

### Deleting cached data

We can use `delete_records(records: accounts + clients)`.  To delete google_accounts cache we need to `delete_records(records: google_accounts, record_class: 'GoogleAccount')`.  

redis_app_join also sets a default [expire TTL](http://redis.io/commands/expire) of 1 week.  You can change it in your initializer by setting `REDIS_APP_JOIN_TTL = 1.day`.

I will continue to work on the gem but if anyone has ideas/suggestions feel free to file an issue or submit PR via GitHub page.  
