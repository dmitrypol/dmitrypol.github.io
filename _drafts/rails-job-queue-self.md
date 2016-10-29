---
title: "Rails job queueing self"
date: 2016-10-25
categories: rails
---

http://guides.rubyonrails.org/active_job_basics.html

https://github.com/steelThread/redmon

{% highlight ruby %}
class MyJob < ApplicationJob
  queue_as :low
  self.queue_adapter = :sidekiq
  def perform
    # do stuff
  ensure
    self.class.set(wait: 30.seconds).perform_later
  end
end
{% endhighlight %}


https://github.com/ondrejbartas/sidekiq-cron

https://github.com/mperham/sidekiq/wiki/Scheduled-Jobs
