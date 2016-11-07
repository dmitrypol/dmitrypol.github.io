---
title: "Batch email sending"
date: 2016-11-07
categories: redis
---

In our application we send out LOTS of emails.  And our clients need to control when the emails are sent and the exact content.  Here is a previous [post]({% post_url 2015-12-20-rails-bulk-email-send %}) on how we attempted to solve it.  We later switched to use SendGrid bulk sending [API](https://sendgrid.com/docs/Integrate/Code_Examples/v2_Mail/ruby.html) to avoid making individual API calls for every email.  

Here are the basic models implemented with [Mongoid](https://github.com/mongodb/mongoid):

{% highlight ruby %}
# app/models/client.rb
class Client
  has_many :users
  has_many :newsletters
end
# app/models/user.rb
class User
  belongs_to :client
  field :email,     type: String
end
# app/models/newsletter.rb
class Newsletter
  belongs_to :client
  field :subject,   type: String
  field :body,      type: String
  field :sent_at,   type: Time
  field :status,    type: String,   default: :draft
  extend Enumerize
  enumerize :status, in: [:draft, :approved, :sending, :sent]
  scope :to_send, ->{ where(status: :approved, :sent_at.lte => DateTime.now) }  
end
{% endhighlight %}

We created a simple job and cron it to run every 5 minutes `SendNewslettersJob.perform_later`.  If there are no newsletters to send, it does nothing.  

{% highlight ruby %}
# app/jobs/send_newsletters_job.rb
class SendNewslettersJob < ApplicationJob
  def perform
    Newsletter.to_send.each do |newsletter|
      newsletter.update(status: :sending)
      Sendgrd.new.perform newsletter
      newsletter.update(status: :sent)
    end  
  end
end
# app/services/sendgrid.rb
class Sendgrd
  def perform newsletter
    users = newsletter.client.users
    # pass user emails and text to SendGrid API
  end
end
{% endhighlight %}

The problem with this approach is that newsletter might go to 100 users or 100K users.  And the process runs sequentially so one large sending can delay others.  And it's best to pass email addresses to SendGrid in reasonable sizes chunks (say 100 at a time).  

The first step is to break up each newsletter sending into separate job so they can run in parallel.  

{% highlight ruby %}
# app/jobs/send_newsletters_job.rb
class SendNewslettersJob < ApplicationJob
  def perform
    Newsletter.to_send.each do |newsletter|
      newsletter.update(status: :sending)
      SendEachNewsletterJob.perform_later newsletter
    end  
  end
end
# app/jobs/send_each_newsletter_job.rb
class SendEachNewsletterJob < ApplicationJob
  def perform newsletter
    Sendgrd.new.perform newsletter
    newsletter.update(status: :sent)
  end
end
{% endhighlight %}

Next let's change it so each sending goes to a group of 100 users.  

{% highlight ruby %}
# app/jobs/send_each_newsletter_job.rb
class SendEachNewsletterJob < ApplicationJob
  def perform newsletter
    user_ids = newsletter.client.users.pluck(:_id)
    user_ids.in_groups_of(100).each do |user_id_group|
      SendNewsletterUserGroupJob.perform_later(newsletter, user_id_group)
    end
    newsletter.update(status: :sent)
  end
end
# app/jobs/send_newsletter_user_group_job.rb
class SendNewsletterUserGroupJob < ApplicationJob
  def perform newsletter, users_ids
    # sendgrid code here
  end
end
{% endhighlight %}

One problem with this approach is `newsletter.update(status: :sent)`.  We did not actually send the emails to the users yet, the jobs are simply queued.  What we really want to do is run each sending job and update newsletter status when the last job completes.  

We need to record the IDs of all individual jobs in the batch.  I like using [Redis](http://redis.io/) for storing this kind of ephemeral data.  For unique list of IDs [Redis SETs](http://redis.io/commands#set) are a good data structure.  

{% highlight ruby %}
# config/initializer/redis.rb
redis_conn = Redis.new(host: 'localhost', port: 6379, db: 0)
SEND_NEWSLTTER_BATCH = Redis::Namespace.new('news_batch', redis: redis_conn)
{% endhighlight %}

We create uniuque batch_id, grab job_id and record them using [SADD](http://www.rubydoc.info/github/redis/redis-rb/Redis#sadd-instance_method).

{% highlight ruby %}
# app/jobs/send_each_newsletter_job.rb
class SendEachNewsletterJob < ApplicationJob
  def perform newsletter
    newsletter.update(status: :sending)
    user_ids = newsletter.client.users.pluck(:_id)
    batch_id = SecureRandom.uuid
    user_ids.in_groups_of(100).each do |user_id_group|
      job = SendNewsletterUserGroupJob.perform_later(newsletter, user_id_group, batch_id)
      # record job ID in Redis SET
      SEND_NEWSLTTER_BATCH.sadd(batch_id, job.job_id)
    end
  end
end
{% endhighlight %}

Now in each sending job upon completion we can remove its own job ID from Redis and check whether there are other jobs left.  

{% highlight ruby %}
# app/jobs/send_newsletter_user_group_job.rb
class SendNewsletterUserGroupJob < ApplicationJob
  after_perform :batch_tasks
  def perform newsletter, users_ids, batch_id
    ...
  end
private
  def batch_tasks
    # remove own ID
    SEND_NEWSLTTER_BATCH.srem(batch_id, self.job_id)
    # check if other IDs are present
    if SEND_NEWSLTTER_BATCH.scard(batch_id) == 0
      newsletter.update(status: :sent)
      SEND_NEWSLTTER_BATCH.del batch_id
    end
  end
end
{% endhighlight %}

We can now consolidate our jobs so `SendNewslettersJob` calls `SendNewsletterUserGroupJob` directly.

{% highlight ruby %}
class SendNewslettersJob < ApplicationJob
  def perform
    Newsletter.to_send.each do |newsletter|
      newsletter.update(status: :sending)
      user_ids = newsletter.client.users.pluck(:_id)
      batch_id = SecureRandom.uuid
      user_ids.in_groups_of(100).each do |user_id_group|
        job = SendNewsletterUserGroupJob.perform_later(newsletter, user_id_group, batch_id)
        # record job ID in Redis SET
        SEND_NEWSLTTER_BATCH.sadd(batch_id, job.job_id)
      end
    end  
  end
end
{% endhighlight %}

Also, here is a relevant [post]({% post_url 2016-03-18-sidekiq-batches %}) on using Sidekiq batches for data import.  
