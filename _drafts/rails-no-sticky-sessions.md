---
title: "Rails session storage"
date: 2016-09-21
categories: rails redis mongo
---

When you build your site on a singleton application server thins are very simple.  But then you need to start scaling out (usually better approach than scaling up) and you need to worry about session state management.  

The simplest thing on AWS ELB is to enable sticky sessions http://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-sticky-sessions.html.  
Load Ballance simply creates a cookie and the thext time request comes back it will send user to the same EC2 instance as before.  The downside of this approach is that if you need to take server out of load ballancer to do maintenance there could still be users on it.  

Another approach is to use dedicated state server to store session info.  

### Redis
https://github.com/roidrage/redis-session-store

{% highlight ruby %}

{% endhighlight %}


### Mongo
We have been using that approach for a couple of years.  
https://rubygems.org/gems/mongo_session_store-rails4/

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


### MySQL
https://github.com/rails/activerecord-session_store

Since MySQL does not have TTL process you will probably need to create a job to clean out these records

{% highlight ruby %}
class SessionCleanJob < ApplicationJob
  queue_as :low # need to create separate queue
  def perform(*args)
    # delete all session records older than X time
  end
end
{% endhighlight %}



### Useful links

http://www.justinweiss.com/articles/how-rails-sessions-work/
http://stackoverflow.com/questions/10494431/sticky-and-non-sticky-sessions
http://stackoverflow.com/questions/1553645/pros-and-cons-of-sticky-session-session-affinity-load-blancing-strategy
https://www.safaribooksonline.com/library/view/rails-cookbook/0596527314/ch04s15.html
http://guides.rubyonrails.org/security.html
