---
title: "Processing time series data"
date: 2018-04-16
categories: aws elastic terraform
---

Modern software systems can collect LOTS of time series data.  It could be an analytics platform tracking user interactions or it could be IoT system receiving measurements from sensors.  How do we process this data in timely and cost effective way?  We will explore two different approaches below.  

* TOC
{:toc}

### API - queue - workers - DB

We will build an API that will receive inbound messages and put them in a queue.  Then workers running on different servers will grab these messages from the queue, process them and store data in MongoDB.  Since are working with time series data we will create daily collections for these events.  Separating API servers from workers servers will help us to properly scale them.    

We will be using AWS ElasticBeanstalk with SQS.  Our code will be Ruby on Rails API with Shoryuken library for integration with SQS.  Here is a sample request that will be receiving `/events?cid=123&aid=abc&...`

Here is high level Terraform config file to build AWS infrastructure (Terraform and ElasticBeanstalk are not the primary focus of this article).

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
    return false unless params[:cid].present?
    ...
    return true
  end
end
{% endhighlight %}

We will create a job to process events and push them into MongoDB.  We will be using timestamp that is passed in with each job to ensure proper date attribution if there is a delay in data processing.  

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

Here is shoryuken configuration with ActiveJob

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

Data in Mongo will look like this:

{% highlight ruby %}
{
  "_id" : ObjectId("5a497a00d2a93e49c8a01909"),
  "params" : {
      "cid" : "123",
      "aid" : "abc",
      "ip" : "55.108.213.2",
      "os_version" : "Mozilla/5.0 (Linux; Android 6.0.1; SM-G550T Build/MMB29K)...",
      ...
  },
  {
    "_id" : ObjectId("5a6babf6a6b37e593953a0b4"),
    "params" : {
        "cid" : "456",
        "aid" : "xyz",
        ...
    }
  },
  ...  
}
{% endhighlight %}

Once data is in Mongo DB we can write additional code to create summaries and eventually delete the detailed records.

There are several pros and cons with this approach.  We MUST keep our API servers running at all times otherwise we will loose data.  But we can stop the workers and messages will simply pile up in SQS.  With SQS we pay per use so if we are running billions of messages this could become expensive.  To start with we can build this as one application and later separate it into microservices.  

### ELB - S3 logs - Logstash - Elasticsearch

Alternative approach is to take server logs and extract parameters from them.  We will setup frontend Nginx web servers to simply load the 1x1 pixel.  AWS ELB will publish logs to S3 bucket every 5 minutes.  From there logs will be picked up by Logstash and processed into Elasticsearch.  Then we will build our reports, implement rollup indexes and snapshot data to a different S3 bucket (backup and archiving).

Sample line from ELB log file:

{% highlight ruby %}
2018-04-10T03:55:57.940787Z ELB_NAME 75.67.169.50:60708 10.0.1.42:80 0.000021
0.000303 0.000014 200 200 0 68 "GET https://website.com:443/events?cid=123&aid=abc&...
HTTP/1.1" "Mozilla/5.0 (Linux; Android 7.0; SM-T580 Build/NRD90M; wv)
AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/65.0.3325.109 Safari/537.36 [Pinterest/Android]"
ECDHE-RSA-AES128-GCM-SHA256 TLSv1.2
{% endhighlight %}

#### Logstash config

We will start with Logstash S3 input plugin:

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf
input {
  s3 {
    aws_credentials_file => "./aws_credentials_file.yml"
    bucket               => "my-elb-logs"
    prefix               => "subfolder/path/here"
  }
}
{% endhighlight %}

Then we configure Elasticsearch output plugin which will create daily indexes.  `stdout` is commented out but can be used for debugging.  

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf
output {
  # stdout { codec => rubydebug }
  elasticsearch {
    hosts     => [127.0.0.1]
    user      => "elastic"
    password  => "password-here"
    index     => "events-%{+YYYY.MM.dd}"
  }
}
{% endhighlight %}

For filtering we will first grok and then remove unnecessary fields:

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf
filter {
  grok  {    
     match => { "message" => "%{ELB_ACCESS_LOG}"}  
  }
  mutate {    
     remove_field => [ "elb", "backendip", "backendport",...]   
  }
}
{% endhighlight %}

#### Ruby code

Now comes the hard part.  We need to implement complex biz logic to validate and transform our data.  For greater control we will use Logstash Ruby filter plugin.  

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf
filter {
  ruby {
    code =>  "params = event.get('params')
              event.cancel if params.nil?
              params_parsed = CGI::parse(params)
              ['cid', 'aid'].each do |p|
                value = params_parsed[p].first
                event.set(p, value)
              end
              "
  }
{% endhighlight %}

Placing code in a config file is not a great solution and it will be difficult to test.  Fortunately latest version of the Ruby filter plugin supports referencing separate Ruby script from .conf file.  This helps us test our code with automates tests.  

{% highlight ruby %}
# /etc/logstash/conf.d/s3_elastic.conf file
filter {
  ruby {
    path => "/etc/logstash/ruby/ruby_script.rb"
    # script_params => {  }
  }
}
# /etc/logstash/ruby/ruby_script.rb
def filter(event)
  params = event.get('params')
  return [] if params.nil?
  params_parsed = CGI::parse(params)
  ['cid', 'aid'].each do |p|
    value = params_parsed[p].first
    event.set(p, value)
  end
  return [event]
end
test 'valid test' do
  in_event do { 'params' => '?cid=123&aid=abc' } end
  expect('params') do |events|
    events.first.get('cid') == '123'
    events.first.get('aid') == 'abc'
  end
end
{% endhighlight %}

Ruby scripts are nice but Ruby objects are even better.  Here is the next refactor.  We can write additional classes to encapsulate common logic and inherit from them.  

{% highlight ruby %}
# /etc/logstash/ruby/ruby_script.rb
require_relative './ruby_class.rb'
def filter(event)
  MyClass.new(event).perform
end
# /etc/logstash/ruby/ruby_class.rb
class MyClass
  def initialize event
    @event = event
  end
  def perform
    return [] if invalid?
    params = @event.get('params')
    params_parsed = CGI::parse(params)
    ['cid', 'aid'].each do |p|
      value = params_parsed[p].first
      @event.set(p, value)
    end
    return [@event]
  end
private
  def invalid?
    params = @event.get('params')
    return true if params.nil? || params == '?' || params == ''
    return false
  end
  ...
end
{% endhighlight %}

We also moved validation logic into separate method.  Now we can leverage Ruby unit testing frameworks such as Rspec.  We will need to create mock event object that responds to `get` and `set` methods.  Alternatively we could still test this class via the tests provided by Logstash.  

{% highlight ruby %}
# /etc/logstash/ruby/spec/ruby_class_spec.rb
require_relative '../ruby_class.rb'
describe MyClass do
  before(:each) do
    @event = double('event')
    allow(@event).to receive(:set)
    allow(@event).to receive(:get)
    ...
  end
  it 'perform' do
    test = MyClass.new(@event).perform
    expect(test).to eq ...
    end
  end
  it 'invalid?' do
    ['?', nil, ''].each do |param|
      ...
      test = MyClass.new(@event).perform
      expect(test).to eq []
    end
  end
  ...
end
{% endhighlight %}

If we need to load external Ruby gems we cannot do it directly.  One workaround is to install another Logstash plugin which uses that specific gem.  For example, if we need to access Redis from our Ruby code we can install either Logstash Redis input or output plugins and then call `Redis.new` in the class.

Next step is to build a full blown Logstash plugin (Ruby gem) which gives us the greatest amount of flexibility but that is beyond the scope of this post.  

### Links
* https://www.terraform.io/docs/providers/aws/r/elastic_beanstalk_environment.html
* http://guides.rubyonrails.org/api_app.html
* https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html
* https://www.elastic.co/blog/moving-ruby-code-out-of-logstash-pipeline
* https://github.com/logstash-plugins/logstash-patterns-core/blob/master/patterns/aws
* https://relishapp.com/rspec/rspec-mocks/v/3-7/docs
