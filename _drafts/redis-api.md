---
title: "Redis for APIs"
date: 2016-07-26
categories: redis
---

Redis make a great backend store for APIs.  Usually you need to respond very quickly


### Asynchronous Reporting API.

Several years ago I worked on a project where we built reporting API for our customers.  Unlike traditional APIs which respond quickly we had to build an asynchronous Reporting API.  Client would make a request and we would respond with a ID.  We would then kick off a background job to generate the report.  Client would make a secondary request in X minutes with that ID and we would respond with either the content of the report or a message that data was not ready yet.  Report data for that ID would be available for download for 24 hours after which we deleted it.  Client would then need to make a separate request with same parameters to re-generate the data if needed.  

#### Generating reports

To generate reports API kicks off Sidekiq jobs.  Job ID is returned to the client.  

Once report is generated it's ID is placed in Available Reports list and the JSON file is placed in AWS S3 bucket.

#### Available reports

IDs of available reports are stored as Redis keys with TTL of 24 hours.  

#### S3 storage

Report data is stored on S3 in JSON format.  Use S3 delete policy to purge actual files (separate from report IDs stored in Redis).


#### Client code

Sample app for reporting API client.  It uses Sidekiq scheduled job to pick up report.  If message is "data is not ready" then it retries.  Maximum number of request to download report

https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs




### Throttling APIs

When you build APIs you want to make sure your clients use them efficiently.  You want to build various bulk update features (active 1000 accounts in one request) and you also want to enable clients to edit individual records (modify one account).  To enforce this appropriate usage you need to keep track of the number of requests your clients make and cap, throttle or charge them.  

Redis counters give us a great way to do that.  

Each client has unique credentials used by that client to securely communicate with the API

API has the following endpoints:
REST for accounts

API has the following bulk action endpoints that accept array of account IDs:
Activate
De-activate

{% highlight ruby %}
class Client
  has_many :accounts
end
class Account
  belongs_to :client
end
{% endhighlight %}





{% highlight ruby %}

{% endhighlight %}
