---
title: "Callbacks and Background Jobs"
date: 2017-03-26
categories: redis
---

In building complex applications we can use [callbacks](http://guides.rubyonrails.org/active_record_callbacks.html) to perform additonal actions before / after records are created / updated / deleted.  The challenge is that these callbacks often fire additional DB queries which slows down with scale.  

How can we use background jobs to separate saving the primary record from the secondary process of creating/updating other records?  

### Counter caches

[counter_cache](http://guides.rubyonrails.org/association_basics.html#options-for-has-many-counter-cache) is a common pattern of pre-generating data.  

{% highlight ruby %}
class User
  has_many :articles
  field :articles_count, type: Integer
end
class Articles
  belongs_to :user, counter_cache: true
end
{% endhighlight %}

Behind the scenes creating / deleting `Article` fires updates to increment / decrement `User.articles_count`.  Now we can sort users by the number of articles they have written w/o having to do `join` and `group_by` to `Articles` table.  

Constantly updating `User` table can be a problem too so there is an interesting library [counter-cache](https://github.com/wanelo/counter-cache
) which queues these updates in the background.  

But counter cache updates are pretty fast and we have to reach REALLY large scale before it starts impacting system performance.  Let's look at a more real world example.  

### More complex DB updates

At my day job I work on a fundraising platform where on behalf of our customers (large universities) we send emails to prospective donors asking for donations .  Here are our basic models (rather oversimplified):

{% highlight ruby %}
class User
  field :name
  field :email
  has_many :donations
  has_many :emails
end
class Fundraiser
  field :name
  has_many :donations
  has_many :emails
end
class Email
  belongs_to :user
  belongs_to :fundraiser
  field :opens,   type: Integer
  field :clicks,  type: Integer
  field :donated, type: Boolean
end
class Donation
  field :amount,   type: Money
  belongs_to :user
  belongs_to :fundraiser
end
{% endhighlight %}

In a [previous post]({% post_url 2017-03-16-sendgrid-webhooks-background-jobs %}) I wrote how we use background jobs to increment opens and clicks so our customers can see which recepients interacted with emails.  But the final step in the conversion process is whether specific email resulted in user donating money to the fundraiser.  

To do that we built a callback in our `Donation` model.  

{% highlight ruby %}
class Donation
  after_save  { update_email_donation }
  def update_email_donation
    # check if donation was succesfully processed by the credit card processor
    # use the unique email_id in the URL to find email record
    # if email_id is blank/invalid query if the email address used during
    # donation matches existing user and look for an email record
    if email_record.present?
      email_record.update(donated: true)
    end
  end
end
{% endhighlight %}

These queries take time and we do not want to keep the user waiting during donation process.  We created a background job with [ActiveJob](http://guides.rubyonrails.org/active_job_basics.html).  

{% highlight ruby %}
class Donation
  after_save  { update_email_donation }
  def update_email_donation
    # if donation was processed succesfully
    UpdateEmailDonationJob.perform_later(donation: self)
  end
end
class UpdateEmailDonationJob < ApplicationJob
  def perform(donation:)
    # same logic to query DB and update record
  end
end
{% endhighlight %}

We also want the queueing to be as fast as possible otherwise it can still slow down our primary DB update.  For that we use [Sidekiq](https://github.com/mperham/sidekiq) which in turn uses [Redis](https://redis.io/).  Alternatively we could have used other queueing solutions such as [AWS SQS](https://aws.amazon.com/sqs/).  

This creates a small delay between the primary record creation and the time when the summarized data is updated but for us that time differnce is insignificant.

The same pattern can be extended to many other tasks (such as generating reporting data in separate OLAP DB).  Instead of running few large periodic jobs we can constantly run lots of small jobs.  Data is more in sync between different systems AND there is less likely to be issues of large job not completing in time before the next job is scheduled to start.  
