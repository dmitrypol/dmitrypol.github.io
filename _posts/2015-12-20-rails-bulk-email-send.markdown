---
title:  "Sending LOTS of emails from Rails ActionMailer"
date:   2015-12-20
categories:
---

ActionMailer is great.  It allows you to create view templates and put logic in Mailer classes.  You can use [Roadie](https://github.com/Mange/roadie-rails) to merge CSS further customizing their look and feel (one customer can have red background and another blue).  The problem arises when you have to send tens or hundreds of thousands of emails.  Each one is a separate API or SMTP call to your email service provider.  

We were able to achieve some perf gains by breaking up our jobs in smaller batches and then running 2 (or more) processes per server with ActiveJob.  But the HTTP REST or SMTP calls are still very time consuming when you are doing one per email.

Alternatively if you build email templates in the Mandrill or Sendgrid UI you can then call their API passing smaller hashes with the appropriate parameters (first_name, last_name, etc) and they will do the appropriate substitution.  That approach is much faster but you loose a lot of flexibility of being able to build your emails in code.  Plus someone could change email template in Mandrill UI and you have no revision control.

So here is how we recently attempted to solve it (it's still work in progress).

{% highlight ruby %}
class MyMailer < ActionMailer::Base
	...
	def batch_email(to, from, subject)
		mail(to: to, from: from, subject: subject)
	end
	...
end
{% endhighlight %}
Create appropriate templates for this mailer in views.

Created SendEmailsJob in app/jobs.  It can be run as ActiveJob via Sidekiq, DelayedJob or another queue.
{% highlight ruby %}
class SendEmailsJob < ActiveJob::Base
  queue_as :default
  def perform()
		#	do appropriate logic to determine which emails needs to be sent and to whom
  	MyMailer.batch_email(to, from, subject)
  end
end
{% endhighlight %}

Create EmailInterceptor class.  You can put email_interceptor.rb in mailers folder.
{% highlight ruby %}
class EmailInterceptor
	def self.delivering_email(message)
		#	stop the actual send
		message.perform_deliveries = false
		#	queue up the email with complete message generated
		SendEmailBatchJob.perform_later(message.to, message.from, message.subject, message.html_part.body.to_s)
	end
end
{% endhighlight %}

You will need to put this in an initializer
{% highlight ruby %}
require 'email_interceptor'
ActionMailer::Base.register_interceptor(EmailInterceptor)
{% endhighlight %}

Create a template in Mandrill or Sendgrid with one basic variable like {{body}}

Create SendEmailBatchJob which actually sends emails via API call to the email service provider.  The problem is that queueing up these emails will take TONS of RAM in Redis because you are storing the actual HTML (could be tens of kilobytes per message once you include the fancy CSS).  So unless you have a huge Redis instance just sitting around, it's not a good approach.

You can use [AWS SQS](https://aws.amazon.com/sqs/) and [Shoryuken](https://github.com/phstc/shoryuken) but what if you do not want all your jobs going through SQS?  Fortunately I found this issue [https://github.com/rails/rails/issues/16960](https://github.com/rails/rails/issues/16960) which allows you to configure queueing systems on per Job class.

{% highlight ruby %}
class SendEmailBatchJob < ActiveJob::Base
  queue_as :each_email
  self.queue_adapter= :shoryuken
  def perform()
  	#	grab 10 or more SQS jobs at a time and send then to email service provider specifying your template and to, from, body, etc.  You need to be careful not to exceed the max size of the payload as you will be passing a large chunk of HTML to replace the body.
  end
end
{% endhighlight %}

* Set config.active_job.queue_adapter = :sidekiq in application.rb (or production.rb).  This way your regular jobs will run through Sidekiq and only run these huge batches of emails through SQS.
* Login to AWS SQS web console and create the each_email queue.  Keep in mind the AWS SQS max message size is 256KB but that should be enought.

You can spin up multiple workers/threads to run SendEmailBatchJob across different servers or even setup separate cluster.  All they do is grab jobs from SQS and call email service provider API.

We are still in the process of rolling it out and testing so I will post updates on our progress.

For those who are not running Rails 4.2 there is [ActiveJob Backport](https://github.com/ankane/activejob_backport) which works great.