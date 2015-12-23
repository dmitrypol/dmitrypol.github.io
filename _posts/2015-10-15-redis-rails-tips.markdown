---
title:  "Tips & Tricks with Redis and Rails"
date: 	2015-10-15
categories: redis
---

Much has been written about using Redis in Rails for various things.  We are using it for [caching data](http://guides.rubyonrails.org/caching_with_rails.html) and running [Sidekiq](https://github.com/mperham/sidekiq).  Sidekiq web UI gives you nice visibility into how Sidekiq is doing but I wanted to have a more in-depth view of what is actually stored in my Redis DB.  I came across [Redis-Browser](https://github.com/monterail/redis-browser) and wanted to share some lessons learned.

Create config/initalizers/redis-browser.rb
{% highlight ruby %}
unless Rails.env.test?
	settings = {"connections"=>{
		"default"=>{"url"=>"redis://#{Rails.application.config.redis_host}:6379/0"},
		"db1"		 =>{"url"=>"redis://#{Rails.application.config.redis_host}:6379/1"},
		}}
	RedisBrowser.configure(settings)
end
{% endhighlight %}
This will allow you to connect to Redis DB0 or DB1 via simple selector.  We are storing cache in DB0 and Sidekiq jobs in DB1.  This way we can flushdb on specific DB in emergency.

Modify routes.rb.
{% highlight ruby %}
	...
  require 'sidekiq/web'
  authenticate :user, lambda { |u| u.roles.include? :superadmin } do
  	unless Rails.env.test?
    	mount Sidekiq::Web => '/sidekiq'
    	mount RedisBrowser::Web => '/redis'
    end
  end
  ...
{% endhighlight %}
This will ensure that only users with role superadmin will be able to access the route.  Much easier than separate HTTP auth username/password.  Both Sidekiq Web and Redis-Browser run as Sinatra apps so see their respective docs for install instructions.

You can also put this in your Sidekiq initializer to link to /redis URL.
{% highlight ruby %}
Sidekiq::Web.app_url = '/redis'
{% endhighlight %}
