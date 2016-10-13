---
title: "Redis and production code coverage"
date: 2016-10-13
categories: redis
---

Would you like to know how much of your code in production is actually getting used?  And how often?  When we run our tests we can use code coverage metrics (like [simplecov](https://github.com/colszowka/simplecov)) to see which parts of our code are tested or not.  

I recently created [redis_code_cov gem](https://rubygems.org/gems/redis_code_cov) to do the same in production for [Ruby on Rails](http://rubyonrails.org/) applications.  It can show you which parts of your code are used and perhaps need to be improved for performance or test coverage.  And you can see which parts of your code are not exercised and perhaps those features can be removed.  

Warning - this gem is still ALPHA quality so be careful before using it in prod.  It will [increment](http://redis.io/commands/INCR) a Redis counter for EACH method call.  Depending on your traffic it could slow down your application and Redis DB.  

### Config

You can read instructions on the [GitHub page](https://github.com/dmitrypol/redis_code_cov) but after installing the gem you run `rails g redis_code_cov:install` to create initializer.  

{% highlight ruby %}
# config/initializers/redis_code_cov.rb
redis_conn = Redis.new(host: 'localhost', port: 6379, db: 0, driver: :hiredis)
REDIS_CODE_COV =  Redis::Namespace.new('codecov', redis: redis_conn)
{% endhighlight %}

To enable the functionality you do this:

{% highlight ruby %}
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RedisCodeCov::Controller
end
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  include RedisCodeCov::Job
end
{% endhighlight %}

Data will be stored in Redis DB and namespace configured in the initializer.  Currently the gem supports only [Controllers](http://guides.rubyonrails.org/action_controller_overview.html) and [Jobs](http://edgeguides.rubyonrails.org/active_job_basics.html).  If you are concerned about performance impact you can selectively enable it for specific Controllers or Jobs instead of Application.

You can also setup an exclustion list `EXCLUDE_REDIS_CODE_COV = ['ClassName.method_name']` in the initializer.  If you have a specific method that is getting hit all the time and you just don't want to record that.  

The gem uses [ActiveSupport::Concern](http://api.rubyonrails.org/classes/ActiveSupport/Concern.html) with `before_action` for Controllers and `before_perform` for Jobs.  Redis keys use `ClassName.method_name` and look like this `codecov:HomeController.index` and `codecov:YourJob.perform`.

In a way this gem is similar to exception notification services like [Rollbar](https://rollbar.com).  But instead of making outbound HTTP request (which will slow things way down) it's using your Redis instance.  

### TODOs

First, I need to write some decent tests in the gem.  I am currently testing it inside the app from which I extracted the functionality.  

And I am working to expand this to other classes (models, serializers, POROs).  I am thinking of creating a callback to fire each time a method is called.  There is an interesting gem [after_do](https://github.com/PragTob/after_do) that might help with it.  I plan to use [Ruby hooks](https://www.sitepoint.com/rubys-important-hook-methods/) and [run code for every method](http://stackoverflow.com/questions/5513558/executing-code-for-every-method-call-in-a-ruby-module).

I also want to build a reporting feature where you would see the list of all classes/methods that were called AND all classes / methods in the app.  Then you can show the diff of classes/methods that were not called.  

So that's it.  Enjoy the gem.  Feedback and PRs are welcomed.  
