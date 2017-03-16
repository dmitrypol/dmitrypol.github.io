---
title: "SendGrid Webhooks and background jobs"
date: 2017-03-16
categories: redis sidekiq
---

We use SendGrid for sending emails from our [Rails](http://rubyonrails.org/) application.  [SendGrid Webhooks](https://sendgrid.com/docs/API_Reference/Webhooks/index.html) sends us notifications when the emails are opened / clicked.  We then use the `email_id` to find appropriate record in our DB and increment `opens` and `clicks` counters.  This enables us to quickly aggregate stats on how each mailing is performing.  

Our basic models are:

{% highlight ruby %}
class Mailing
  field :subject
  field :body
  has_many :emails
end
class Email
  belongs_to :user
  belongs_to :mailing
  field :opens,   type: Integer
  field :clicks,  type: Integer
end
{% endhighlight %}

To keep our controllers simple we created a separate class with the logic to find and update the `email` record.

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
    # find email record by email_id in the params, update stats
  end
end
{% endhighlight %}

But with success come inevitable scalability challenges.  Our customers started sending large mailings (tens or hundreds of thousands of recipients).  Then our servers would receive thousands of notifications in brief amount of time as people were opening and clicking their emails.  This caused sharp spikes in system load.  

Solution was to create a background job between controller and the Ruby class.  We use [Sidekiq](http://sidekiq.org/) and [Redis](https://redis.io/) so queuing jobs is lightning fast.  

{% highlight ruby %}
class SendgridController < ApplicationController
  def webhook
    WebhookRecorderJob.perform_later(params)
    render nothing: true
  end
end
# app/jobs/webhook_recorder_job.rb
class WebhookRecorderJob < ApplicationJob
  queue_as :low
  def perform(params)
    WebhookRecorder.perform(params)
  end
end
{% endhighlight %}

Alternatively we could have moved the code from the `WebhookRecorder` class to methods in `WebhookRecorderJob`.  It's simply a matter of preference whether to keep the job as a small wrapper around the class or whether to put more logic in it.  

Now whenever we have a large mailing we can see how these jobs queue up but after a few minutes they all process.  And the system load remains much more even.  

The same pattern can be applied to other situations where the system can receive a large influx of inbound messages in a short amount of time and where it is OK to have slight delay between the time the message is received and when it's processed.  
