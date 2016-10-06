---
title: "Redis code coverage"
date: 2016-10-06
categories: redis
---

Would you like to know how much of your code in production is actually getting used?  And how often?  When we run our tests we can use code coverage metrics (like https://github.com/colszowka/simplecov) to see which parts of our code are not tested.  

This can be a great tool to see which parts of your code are used often and perhaps need to be improved for performance or test coverage.  Also, you can see which parts of your code are not exercised and perhaps those features can be removed.  

* TOC
{:toc}

### Config

{% highlight ruby %}
# config/initializers/redis_code_cov.rb
redis_conn = Redis.new(host: Rails.application.config.redis_host, port: 6379, db: 0, driver: :hiredis)
REDIS_CODE_COV =  Redis::Namespace.new('codecov', redis: redis_conn)
{% endhighlight %}

If you are concerned about performance impact you can selectively enable this for specific classes or groups of classes using steps outlined below.  

Default TTL of 1 week to expire

### Controllers

{% highlight ruby %}
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RedisCodeCovController
end
# app/controllers/concerns/redis_code_cov_controlle.rb
module RedisCodeCovController
  extend ActiveSupport::Concern
  included do
    before_action :redis_code_cov
  end
  def redis_code_cov
    key = [self.class.name, params[:action]].join('.')
    REDIS_CODE_COV.incr key
  end
end
{% endhighlight %}

Create concern and load from app controller or select controllers.


What do you hook into to fire each time a method is called?  before_ callback?  


### Models


### Views


### Other classes


#### Jobs


#### Serializers


#### Decorators


### Service or Form objects



### Data analysis

Get the list of all classes / methods in Rails app?  Show the diff and you have classes/methods that were not called.  

### Config



### Useful links

http://stackoverflow.com/questions/9355704/invoke-a-method-before-running-another-method-in-rails
http://stackoverflow.com/questions/20558826/rails-call-back-before-every-calling-a-method-before-every-static-method
http://stackoverflow.com/questions/5513558/executing-code-for-every-method-call-in-a-ruby-module
http://stackoverflow.com/questions/6991264/running-code-before-every-method-in-a-class-ruby
https://github.com/PragTob/after_do
https://www.sitepoint.com/rubys-important-hook-methods/


{% highlight ruby %}

{% endhighlight %}
