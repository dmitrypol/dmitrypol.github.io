---
title: "Processing time series data"
date: 2018-03-27
categories: aws elastic terraform
---

Modern software systems collect LOTS of time series data.  It could be an analytics platform tracking user interactions or it could be IoT system receiving measurements from sensors.  How do we process this data in timely and cost effective way?  We will explore different options below.  

* TOC
{:toc}

### API - queue - workers - DB

We will build an API that will receive inbound messages and put them in a queue.  Then workers running on different servers will grab these messages from the queue, process them and store data in MongoDB.  Since are working with time series data we will create daily collections for these events.  Separating API servers from workers servers will help us to properly scale them.    

We will be using AWS ElasticBeanstalk with SQS.  Our code will be Ruby on Rails API with Shoryuken library for integration with SQS.  Here is a sample request that will be receiving `/events?client_id=abc123&event_type=click&foo=bar`

High level Terraform config file to build AWS infrastructure (Terraform and ElasticBeanstalk are not the primary focus of this article).

{% highlight ruby %}
provider "aws" {
  region = "us-east-1"
}
resource "aws_elastic_beanstalk_application" "events" {
  name = "events"
}
resource "aws_elastic_beanstalk_environment" "events-webserver" {
  name                = "WebServer"
  application         = "${aws_elastic_beanstalk_application.events.name}"
  solution_stack_name = "64bit Amazon Linux 2017.09 v2.7.1 running Ruby 2.5 (Puma)"
  tier                = "WebServer"
}
resource "aws_elastic_beanstalk_environment" "events-worker" {
  name                = "Worker"
  application         = "${aws_elastic_beanstalk_application.events.name}"
  solution_stack_name = "64bit Amazon Linux 2017.09 v2.7.1 running Ruby 2.5 (Puma)"
  tier                = "Worker"
}
{% endhighlight %}

We will specifically use Rails API which is faster than full Rails app.  Code in controllers should be as light as possible.  We could add simple validations to ensure that the necessary parameters are passed in before we put item on the queue.  

{% highlight ruby %}
# config/routes.rb
get 'events', to: 'events#create'
# app/controllers/
class EventsController < ApplicationController
  def create
    params[:timestamp] = Time.now
    EventJob.perform_later(params) if validate_params
    render status: :created
  end
private
  def validate_params
    return false unless params[:client_id].present?
    ...
    return true
  end
end
{% endhighlight %}

Job to process events and push them into MongoDB.  We will be using timestamp that is passed in with each job to ensure proper date attribution if there is a delay in data processing.  

{% highlight ruby %}
# config/initializers/mongo.rb
MONGO_CLIENT = Mongo::Client.new [ '127.0.0.1:27017' ]
MONGO_DB = Mongo::Database.new(MONGO_CLIENT, 'events')
# app/jobs/
class EventJob < ApplicationJob
  queue_as :low
  def perform(params)
    collection = "events:#{params[:timestamp].strftime("%Y-%m-%d")}"
    doc = { validate and transform here }
    MONGO_DB[collection].insert_one(doc)
  end
end
{% endhighlight %}

Shoryuken configuration with ActiveJob

{% highlight ruby %}
# config/environments/production.rb
config.active_job.queue_adapter = :shoryuken
# config/initializers/shoryuken.rb
Shoryuken.sqs_client_receive_message_opts = {
  # config here
}
Shoryuken.configure_server do |config|
  # config here
end
# config/shoryuken.yml
concurrency: 25
pidfile: tmp/pids/shoryuken.pid
logfile: log/shoryuken.log
queues:
  - [high, 3]
  - [default, 2]
  - [low, 1]
{% endhighlight %}

Data in Mongo

{% highlight ruby %}
{
  "_id" : ObjectId("5a497a00d2a93e49c8a01909"),
  "params" : {
      "client_id" : "abc123",
      "event_type" : "click",
      "foo" : "bar",
      "ip" : "55.108.213.2",
      "os_version" : "Mozilla/5.0 (Linux; Android 6.0.1; SM-G550T Build/MMB29K)...",
      ...
  },
  {
    "_id" : ObjectId("5a6babf6a6b37e593953a0b4"),
    "params" : {
        "client_id" : "xyz456",
        "event_type" : "scroll",
        ...
    }
  },
  ...  
}
{% endhighlight %}

Once data is in our DB we can write additional code to create rollup summaries and eventually delete the detailed records.

There are several pros and cons with this approach.  We MUST keep our API servers running at all times otherwise we will loose data.  But we can stop the workers and messages will simply pile up in SQS.  With SQS we pay per use so if we are running billions of messages this could become expensive.  To start with we can build this as one application but scale API vs workers separately.  When the app becomes bigger we can separate it into several microsites.  

### ELB - S3 logs - Logstash - ElasticSearch

Instead of building an API and a queue we can take server logs and extract parameters from them.  We will setup a frontend Nginx web servers to simply load the 1x1 pixel (there will be no code on these servers).  ELB will publish logs to S3 bucket every 5 minutes.  From there log files will be picked up by Logstash and processed into ElasticSearch.  Then we will build our reports, implement rollup indexes and snapshot data to different S3 bucket (backup and archiving).

Terraform config.  

{% highlight ruby %}

{% endhighlight %}


#### Logstash config

We will be using Logstash S3 input and ElasticSearch output plugins.  

{% highlight ruby %}

{% endhighlight %}


#### Ruby code

The challenge is that we often have to do complex validations / transformations on our data.  We will be using Logstash Ruby filter plugin.  But we will place out business logic in separate Ruby scripts.  This helps us thoroughly test our code with automates tests.  Logstash will run it but it's our responsibility to make sure it's correct.  

{% highlight ruby %}

{% endhighlight %}

One limitation of this approach is we cannot pull in third party Ruby gems.  If we want that we we will need to build a full blown Logstash plugin (Ruby gem).  


### Links
* https://www.terraform.io/docs/providers/aws/r/elastic_beanstalk_environment.html
* http://guides.rubyonrails.org/api_app.html
* https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html
* https://www.elastic.co/blog/moving-ruby-code-out-of-logstash-pipeline



107.15.253.203 - - [26/Mar/2018:23:17:13 +0000] "OPTIONS /microsites/add_events?qn=tmobile HTTP/1.1" 204 0 "-" "Mozilla/5.0 (Linux; Android 7.0; SM-J327T Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.109 Mobile Safari/537.36"

{"http_version":"HTTP/1.0","env":"production","method":"POST","path":"/microsites/add_events","query_string":"?qn=tmobile","http_status":"204","size":null,"time":"2018-03-26T23:17:05.332+00:00","duration":0.008460673,"@timestamp":"2018-03-26T23:17:05.340Z","@version":"1","message":"[] POST /microsites/add_events"}
