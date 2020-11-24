---
title: "RabbitMQ vs AWS SNS & SQS"
date: 2018-01-08
categories: aws terraform
---

In previous [post]({% post_url 2017-12-17-queues %}) we briefly touched on how RabbitMQ can route message to multiple destinations via [exchanges](https://www.rabbitmq.com/tutorials/tutorial-four-python.html).  In this article we will explore how similar functionality can be built with AWS [SNS](https://aws.amazon.com/sns/) and [SQS](https://aws.amazon.com/sqs/).

* TOC
{:toc}

### Web and Worker servers

We will have Web and Worker servers.  We need to run specific tasks on specific groups of servers.  For example, we need to check to make sure Nginx is running on the web servers and background job daemon is running on worker servers.  And we want to check CPU/RAM on all servers.  We will use [Terraform](https://www.terraform.io/) to build this AWS configuration.  Terraform supports more compact syntax with [count](https://www.terraform.io/intro/examples/count.html) command but syntax below is easier to understand (even though it's more verbose).

{% highlight ruby %}
provider "aws" {
}
# sns
resource "aws_sns_topic" "all" {
  name = "all"
}
resource "aws_sns_topic" "web" {
  name = "web"
}
resource "aws_sns_topic" "worker" {
  name = "worker"
}
# sqs
resource "aws_sqs_queue" "web" {
  count = 2
  name  = "web${count.index}"
}
resource "aws_sqs_queue" "worker" {
  count = 2
  name  = "worker${count.index}"
}
# subscriptions
resource "aws_sns_topic_subscription" "all-web" {
  count                  = 2
  protocol               = "sqs"
  topic_arn              = "${aws_sns_topic.all.arn}"
  endpoint               = "${aws_sqs_queue.web.*.arn[count.index]}"
  endpoint_auto_confirms = true
}
resource "aws_sns_topic_subscription" "all-worker" {
  count                  = 2
  protocol               = "sqs"
  topic_arn              = "${aws_sns_topic.all.arn}"
  endpoint               = "${aws_sqs_queue.worker.*.arn[count.index]}"
  endpoint_auto_confirms = true
}
resource "aws_sns_topic_subscription" "web" {
  count                  = 2
  protocol               = "sqs"
  topic_arn              = "${aws_sns_topic.web.arn}"
  endpoint               = "${aws_sqs_queue.web.*.arn[count.index]}"
  endpoint_auto_confirms = true
}
resource "aws_sns_topic_subscription" "worker" {
  count                  = 2
  protocol               = "sqs"
  topic_arn              = "${aws_sns_topic.worker.arn}"
  endpoint               = "${aws_sqs_queue.worker.*.arn[count.index]}"
  endpoint_auto_confirms = true
}
{% endhighlight %}

To run specific tasks on each type of server we can send messages to either **web** or **worker** SNS topics.  SNS will route the message to ALL queues that are subscribed to it.  To run task on ALL servers we will send it to **all** topic and it will be routed appropriately.  

What if we need to run a task anywhere but only once (like sending email)?  For that we can create SQS queues NOT subscribed to SNS topics and push messages directly there.  

{% highlight ruby %}
resource "aws_sqs_queue" "high" {
  name  = "high"
}
resource "aws_sqs_queue" "default" {
  name  = "default"
}
resource "aws_sqs_queue" "low" {
  name  = "low"
}
{% endhighlight %}

Now each server has to subscribe to appropriate SQS queues.  Here is an example with Ruby [shoryuken](https://github.com/phstc/shoryuken) client and [capistrano-shoryuken](https://github.com/joekhoobyar/capistrano-shoryuken) deployment tool.  

{% highlight ruby %}
# config/deploy/web1.rb
set :shoryuken_queues,         -> { [:high, :default, :low, :web1] }
# config/deploy/web2.rb
set :shoryuken_queues,         -> { [:high, :default, :low, :web2] }
# config/deploy/worker1.rb
set :shoryuken_queues,         -> { [:high, :default, :low, :worker1] }
# config/deploy/worker2.rb
set :shoryuken_queues,         -> { [:high, :default, :low, :worker2] }
{% endhighlight %}

Shoryuken workers do not need to know anything about SNS because they are just watching the SQS queues.  

Unfortunately Shoryuken no longer supports sending messages to SNS.  
https://github.com/phstc/shoryuken/issues/367
https://github.com/phstc/shoryuken/issues/443

To do that we need to send messages to SNS using AWS SDK.  


### Filtering messages

https://aws.amazon.com/getting-started/tutorials/filter-messages-published-to-topics/


{% highlight ruby %}


{% endhighlight %}



### Logstash

Sometimes instead of writing code to work with data we use various ETL tools.  Logstash is a powerful tool that originally started for moving log data into Elasticsearch.  It can be extended with various plugins to move data in an out of various data stores.  


https://www.elastic.co/guide/en/logstash/6.1/plugins-outputs-sns.html
https://www.elastic.co/guide/en/logstash/6.1/plugins-outputs-sqs.html
https://www.elastic.co/guide/en/logstash/current/plugins-inputs-sqs.html




{% highlight ruby %}


{% endhighlight %}


https://github.com/jakesgordon/rack-rabbit/
