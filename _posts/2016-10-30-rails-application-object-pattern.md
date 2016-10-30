---
title: "Rails application object pattern"
date: 2016-10-30
categories: rails
---

[Ruby on Rails](http://rubyonrails.org/) has patterns for [ApplicationRecord](http://blog.bigbinary.com/2015/12/28/application-record-in-rails-5.html), [ApplicationMailer](http://guides.rubyonrails.org/action_mailer_basics.html), [ApplicationJob](http://guides.rubyonrails.org/active_job_basics.html), etc.  Other gems follow this approach.  [Pundit](https://github.com/elabs/pundit) has ApplicationPolicy and [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers) has AppliciationSerializer.  

In post about [Rails concerns]({% post_url 2016-10-29-rails-concerns %}) I shared examples on how to extract common logic into modules.  This post is about using base classes to DRY our code.  We can extend `Application*` pattern to other gems and our own classes.  [Draper](https://github.com/drapergem/draper) does not have `ApplicationDecorator` but we can create one.  

{% highlight ruby %}
# app/decorators/application_decorator.rb
class ApplicationDecorator < Draper::Decorator
  delegate_all
  ...
end
# app/decorators/user_decorator.rb
class UserDecorator < ApplicationDecorator
  ...
end
{% endhighlight %}

Additonally our applications can have other POROs for forms, service objects, validators, etc.  Where needed we can create those base `Application*` classes and inherit from them.  

{% highlight ruby %}
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  ...
end
class UserRegisterForm < ApplicationForm
  ...
end
{% endhighlight %}

At the end of the day this is just basic object oriented inheritance, use it where it makes sense.  But this pattern makes things easy to follow.