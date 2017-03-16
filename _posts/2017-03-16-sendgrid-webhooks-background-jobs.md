---
title: "SendGrid Webhooks and background jobs"
date: 2017-03-16
categories: redis sidekiq
---

We use SendGrid for sending emails from our [Rails](http://rubyonrails.org/) application.  [SendGrid Webhooks](https://sendgrid.com/docs/API_Reference/Webhooks/index.html) sends us notifications when the emails are opened / clicked.  We then use the `email_id` to find appropriate record in our DB and increment `opens` and `clicks` counters.  This enables us to quickly aggregate stats on how each mailing is performing.  

Our basic models are:

{% highlight ruby %}
class Mailing
  has_many :emails
end
class Email
  belongs_to :user
  belongs_to :mailing
  field :opens,   type: Integer
  field :clicks,  type: Integer
end
{% endhighlight %}

To keep our controllers light we put the logic to find and appropriately increment the `email` record in a separate class.

{% highlight ruby %}
# config/routes.rb
match 'sendgrid',  to: 'sendgrid#webhook',  via: [:post, :get]
# app/controllers/sendgrid_controller.rb
class SendgridController < ApplicationController
  def webhook
    WebhookRecorder.new.perform(params)
    render nothing: true
  end
end
# app/services/webhook_recorder.rb
class WebhookRecorder
  def perform(params)
    # find email record by email_id in the params
  end
end
{% endhighlight %}

But with success come inevitable scalability challenges.  Our customers started sending very large mailings (tens or hundreds of thousands of recipients).  Then our servers would receive thousands of notifications in brief amount of time as people were opening and clicking their emails.  This caused very sharp spikes in system load.  

Solution was to create a background job between controller and the Ruby class.  We use [Sidekiq](http://sidekiq.org/) and [Redis](https://redis.io/) so queuing jobs is lightning fast.  

{% highlight ruby %}
class SendgridController < ApplicationController
  def webhook
    WebhookRecorderJob.perform_later(params)
    render nothing: true
  end
end
class WebhookRecorderJob < ApplicationJob
  queue_as :low
  def perform(params)
    WebhookRecorder.perform(params)
  end
end
{% endhighlight %}

Now whenever we have a very large mailing we can see how these jobs queue up but after a few minutes they all process.  And the system load remains much more even.  

Alternatively we could have moved the code from the `WebhookRecorder` class to methods in `WebhookRecorderJob`.  It's simply a matter of preference whether to keep the job as a very small wrapper around the class or whether to put more logic in it.  
