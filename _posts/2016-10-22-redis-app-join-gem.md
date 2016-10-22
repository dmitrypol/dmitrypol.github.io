---
title: "redis_app_join ruby gem"
date: 2016-10-22
categories: redis
---

Last week I wrote a post [Redis as temp cache for application-side joins]({% post_url 2016-10-11-redis-application-join %}).  I kept thinking of ways to make the process easier so I decided to create a [redis_app_join](https://rubygems.org/gems/redis_app_join) gem.  

Gem's [GitHub page](https://github.com/dmitrypol/redis_app_join) has examples on how to use it.  In this post I want to explain my reasoning behind the gem and where I see it going.  

First, let's acknowledge that if we can write a good SQL JOIN we should probably use it to grab the data in one request.  Unfortunately that's not always possible (my current challenge is using a NoSQL DB).  Below I want to describe additional situations where this approach could be useful.  

### Querying separate DBs

When we build simple [Ruby on Rails](http://rubyonrails.org/) or [Python Django](https://www.djangoproject.com/) apps there is usually only one DB behind it.  But large IT organizations have mulitiple software systems written in different languages and using different databases.  Frequently same DBs are used by multiple applications and one application can talk to multiple DBs.  I worked in environments where we used MS SQL Server, Oracle, Postgres and MySQL.  The business stakeholders did not care where the data was stored, they just needed to see their reports.  

To aggregate data we built complex [ETL](https://en.wikipedia.org/wiki/Extract,_transform,_load) tools but they can be slow.  In one org data had to flow through 3 separate DB servers (impacting other applications that used them) before being aggregated in Oracle data warehouse.  The process took most of the day and impacted ability to make business decisions.

Let's imagine that we have a group of records.  In DB1 we find them by `account.id` but in DB2 the corresponding records are stored in `Company` table and we need to use `external_id` for lookup.  DB2 also contains other important data attributes.  BTW, here is a good article on how to [connect to multiple DBs from Rails app](http://stackoverflow.com/questions/1825844/multiple-databases-in-rails).  Our biz users need to aggregate data in one report.  We could query the first DB and then loop through the records querying 2nd DB every time.  Or we could fetch records from both sources in 2 separate queries and then work with them in our application.  

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
    companies = Company.in(external_id: @accounts_external_ids).only(:description)
    cache_records(records: companies)
  end
end
{% endhighlight %}

Data will be cached like this in Redis:

{% highlight ruby %}
# record from 1st DB
{"db":0,"key":"appjoin:Account:id1","ttl":-1,"type":"hash",
  "value":{"name":"account 1","external_id":"eid1",...}}
# record from 2nd DB, eid1 is part of the key
{"db":0,"key":"appjoin:Company:eid1","ttl":-1,"type":"hash",
  "value":{"description":"company description1",...}}
{% endhighlight %}

We can now loop through the records and combine the data like this `company = fetch_records(record_class: 'Company', record_ids: [account.external_id]).first`.  But we NOT making separate DB queries for each account which signifiantly speeds up the process and decreases DB load.  

### Querying external APIs

Now let's imagine that we need to query an external API to get more data for a group of users associated with our accounts.  Let's use [GitHub](https://api.github.com/users/dmitrypol) as example.   

{% highlight ruby %}
class DataDownloader
  include RedisAppJoin
  def perform
    profiles = User.where(...).only(:profile).pluck(:profile)
    profiles.each do |p|
      url = "https://api.github.com/users/#{p}"
      profile_data = HTTP.get(url).slice(:name, :company, :location)
      cache_records(records: [profile_data], record_class: 'Github')
    end
  end
end
{% endhighlight %}

Since the JSON is not an [ActiveModel](http://api.rubyonrails.org/classes/ActiveModel/Model.html) we need to specify `record_class` to ensure unique keys will be created in Redis.  We also can make bulk API requests downloading data in batches (cheaper and faster).  We could have persisted the data to a SQL DB but since we are already using Redis why not store it there?  

### Conclusion

What I like abou this design is that it allows us to break up our process into separate phases.  We fetch the first dataset and cache it.  Then we grab a specific attribute from those records (using `fetch_records_field`) and query the second data source for the corresponding data.  We continue this until we have all necessary data cached.  Then we proceed with consolidating these separate data sets into combined result.  

Since Redis uses RAM you want to cache only the portions of the records you care about.  For example, in our DB query we specify the fields we need and in JSON API we use `slice`.  

There are more examples on the gem's GitHub page (for example, how to delete records).  I will continue to work on the gem but if anyone has ideas/suggestions feel free to file an issue or submit PR via GitHub page.  
