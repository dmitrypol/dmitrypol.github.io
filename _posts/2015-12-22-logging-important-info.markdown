---
layout: post
title:  "Logging important info"
date:   2015-12-22 08:23:07
categories:
---

As we build sites they hopefully grow in functionality and usage.  It becomes important to log appropriate information so you can later investigate issues in case something goes wrong.  Grepping multiple log files across many servers is quite time consuming so services like Logentries and Loggly can be helpful.  Or you can roll your own with Fluentd or https://github.com/le0pard/mongodb_logger.  But sometimes you just need something simple for a very specific need.  Here is how I recently solved it at work in our Rails 4.1 app.

Created separate log file using https://github.com/lulalala/multi_logger

{% highlight ruby %}
MultiLogger.add_logger('important')
{% endhighlight %}

Created ErrorMailer (just a simple ActionMailer) with method internal_notification (no need for templates).

{% highlight ruby %}
class ErrorMailer < ActionMailer::Base
  default to: 'dev_team@company.com'
  default from: 'prod_alert@company.com'
  def internal_notification(subject, body)
    # send email here
  end
end
{% endhighlight %}

Created ErrorLog model with the following fields:  object, method, record, exception, message (we are using MongoDB but this would work for other databases).

Created a ErrorLogService service object (PORO).

{% highlight ruby %}
class ErrorLogService
	...
  def log_errors(object, method, record, exception, message, send_email=false)
    record = record.try(:to_json)
    ErrorLog.create(object: object, method: method, record: record, exception: exception, message: message)
    if send_email
      email_subject = "#{object} #{method}"
      email_body = "#{record} \n #{exception} \n #{message}"
      ErrorMailer.internal_notification(subject, body)
    end
    Rails.logger.important.error "#{object} #{method} \n #{record} \n #{exception} \n #{message}"
  rescue Exception => e
    ...
  end
  ...
end
{% endhighlight %}

Then in various places in my code where I do error/exception handling I simply call ErrorLogService.log_errors passing approrpriate parameters.

{% highlight ruby %}
...
msg = 'custom message with some useful information'
ErrorLogService.log_errrors self.class.name, __method__, e, nil, msg
...
{% endhighlight %}

You can build simple web interface (we use RailsAdmin) to view contents of ErrorLog model and see which object and method cause the error, what was the exception, when it occured (created_at timestamp), etc.  For especially important issues I can choose to send notification email to the dev team.  And information is also logged in the files on the server (just in case).

There are many equivalents to the specific gems I listed above in Ruby or other languages.
