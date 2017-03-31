---
title: "API Integration via Background Jobs"
date: 2017-03-31
categories:
---

Often our applications integrate with different APIs.  User may click one button but the application will make multiple API calls behind the scenes.  That can take time and lead to situations where one API call succeeds but others fail.  How can we make the process faster and more reliable?

Here is an example from my day job.  I work on online fundraising platform.  When users give donations our application calls credit card processor API.  If the first transaction succeeds we make another API call to get credit card token which we can store in our system.  Then we call [SendGrid](https://sendgrid.com) API to send a receipt.  

Here is one way to do this:

{% highlight ruby %}
# application initializer
CREDIT_CARD_CLIENT = CreditCardClientObject.new(credentials here)
# Ruby class
class CreditCardProcessor
  def perform
    # make the initial API call to charge the card
    response = CREDIT_CARD_CLIENT.charge_card(card_number, card_expiration, ...)
    if response.success?
      # update donation in the DB
      # 2nd API call using transaction_id from the first one
      response2 = CREDIT_CARD_CLIENT.tokenize_card(response.transaction_id)
      if response2.success?
        # update donation.user with response2.credit_card_token
      end
      # call email service provider API to send receipt
      MyAppMailer.receipt(donation)
    else
      # display errors
    end
  rescue Exception => e
    ...
  end
end
{% endhighlight %}

Not only is this code difficult to maintain but all 3 API calls have to complete before response comes back to the user.  How can we make it better?  

We can separate the process into tasks that must be done immediately and tasks that can be done in the background shortly thereafter.  Ruby on Rails provides [ActiveJob](http://guides.rubyonrails.org/active_job_basics.html) framework but other languages have similar solutions.  

{% highlight ruby %}
class CreditCardProcessor
  def perform
    response = CREDIT_CARD_CLIENT.charge_card(...)
    if response.success?
      # update donation in the DB with the transaction_id
      CreditCardTokenJob.perform_later(donation)
      MyAppMailer.receipt(donation).deliver_later
    else
      ...
    end
  rescue Exception => e
    ...
  end
end
{% endhighlight %}

The second API call to `tokenize_card` is now done via background job so we grab the `transaction_id` from `donation` record in the DB (or we could pass it as parameter to the job).

{% highlight ruby %}
class CreditCardTokenJob < ApplicationJob
  def perform (donation)
    response = CREDIT_CARD_CLIENT.tokenize_card(donation.transaction_id)
    if response.success?
      # update donation.user with response.credit_card_token
    end
  end
end
{% endhighlight %}

For the 3rd API call to SendGrid API [Rails ActionMailer](http://guides.rubyonrails.org/action_mailer_basics.html) provides a handy `deliver_later` method.  The email will be automatically thrown in the queue and picked up by background job.  But we could build the job ourselves and call it from `CreditCardProcessor` like this `SendReceiptJob.perform_later(donation)` if the charge succeeds.

{% highlight ruby %}
class SendReceiptJob < ApplicationJob
  def perform (donation)
    MyAppMailer.receipt(donation)
  end
end
{% endhighlight %}

To go even further we could do the initial credit card processing request in the background but that would require changing UI to use [long polling](https://www.pubnub.com/blog/2014-12-01-http-long-polling/) or [ActionCable](http://guides.rubyonrails.org/action_cable_overview.html) to refresh when the first job completes.  

But what happens when these background API calls fail?  That depends on what they do.  If sending email receipt times out the on the first request the job framework will usually automatically retry it which is fine.  But there could be situations where we do not want to retry it.  Or perhaps we would need to build monitors to alert biz users / sysadmins when the background jobs get backed up too much or had too many errors.

Other APIs and client libraries will have methods and parameters different than `success?` or `transaction_id`.  And the examples are above are highly oversimplified.  They are meant to illustrate a pattern of how by breaking up big tasks into smaller ones we can execute them separately.  

#### Links
* [https://www.youtube.com/watch?v=O1UxbZVP6N8](https://www.youtube.com/watch?v=O1UxbZVP6N8) - great presentation by [Shopify](https://www.shopify.com)
