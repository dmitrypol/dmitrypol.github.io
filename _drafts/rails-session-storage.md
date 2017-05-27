---
title: "Rails session storage"
date: 2017-05-25
categories: rails redis mongo
---

When we build our site on a singleton application server things are very simple.  But then we need to start scaling out (usually better approach than scaling up) and we need to worry about session state management.  Here is a great [article by Justin Weiss](http://www.justinweiss.com/articles/how-rails-sessions-work/) on Rails sessions.

* TOC
{:toc}

### Sticky sessions

The simplest thing on AWS Elastic Load Balancer is to enable [sticky sessions](http://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-sticky-sessions.html).  ELB will create a cookie and the next time request comes back it will be sent to the same EC2 instance as before.  

The downside of this is that if we need to take server out of the load balancer to do maintenance / deploy code there could still be users on it.  Another approach is to use dedicated state server to store session info.  

### Redis
https://github.com/roidrage/redis-session-store

{% highlight ruby %}

{% endhighlight %}


### Mongo
We have been using that approach for a couple of years with [mongo_session_store-rails4](https://rubygems.org/gems/mongo_session_store-rails4) gem.  

{% highlight ruby %}
class Sessions
  include Mongoid::Document
  field :data
  field :created_at, 	type: DateTime
  field :updated_at, 	type: DateTime
  # create index to clean out the collection
	index({updated_at: 1}, {expire_after_seconds: 1.week})  
end
{% endhighlight %}

The nice thing about [MongoDB](https://www.mongodb.com/) is that we can create [TTL indexes](https://docs.mongodb.com/manual/core/index-ttl/) which will purge old records.  We can do it by creating this model in `app/models` and defining `index`.  

### MySQL
https://github.com/rails/activerecord-session_store

Since MySQL does not have TTL process we need to create a background job to clean out these records.

{% highlight ruby %}
class SessionCleanJob < ApplicationJob
  queue_as :low # need to create separate queue
  def perform(*args)
    # delete all session records older than X time
  end
end
{% endhighlight %}


### Links

* [http://www.justinweiss.com/articles/how-rails-sessions-work/]()
*[http://stackoverflow.com/questions/10494431/sticky-and-non-sticky-sessions](http://stackoverflow.com/questions/10494431/sticky-and-non-sticky-sessions)
*[http://stackoverflow.com/questions/1553645/pros-and-cons-of-sticky-session-session-affinity-load-blancing-strategy](http://stackoverflow.com/questions/1553645/pros-and-cons-of-sticky-session-session-affinity-load-blancing-strategy)
*[https://www.safaribooksonline.com/library/view/rails-cookbook/0596527314/ch04s15.html](https://www.safaribooksonline.com/library/view/rails-cookbook/0596527314/ch04s15.html)
*[http://guides.rubyonrails.org/security.html](http://guides.rubyonrails.org/security.html)
