---
title: "Rails routes for wp-login.php and other URLs"
date: 2016-08-12
categories:
---

You work hard and build your awesome Rails app.  You launch your MVP and slowly users start coming to your site.  But then you start noticing exceptions in your logs for URLs like "wp-login.php" and "login.aspx".

Welcome to the Internet where bots scrape your site looking for vulnerabilities.  You can't control what others do but it would be nice NOT to have all these exceptions in your logs.  There are several solutions to the problem.

One options is to create a catch-all route as is explained in this [StackOverflow article](http://stackoverflow.com/questions/19368799/how-to-create-a-catch-all-route-in-ruby-on-rails).  Or you could redirect to root like [this](http://stackoverflow.com/questions/4132039/rails-redirect-all-unknown-routes-to-root-url).  The downside is that you might have an error in your routes and these approaches can mask it.

What I prefer is to define a list of specific routes that I do NOT want to cause exceptions for and respond with blank page or redirect.  You can do it all in your routes.rb (it's a ruby file after all) without creating special controller.

{% highlight ruby %}
Rails.application.routes.draw do
  respond_200 = ['wp-login.php']
  respond_200.each do |r2|
    get "/#{r2}", to: proc { [200, {}, ['']] }
  end
  redirect_root = ['login.aspx']
  redirect_root.each do |rr|
    get "/#{rr}", to: redirect('/')
  end
  #
end
{% endhighlight %}

Here is an [article](http://stackoverflow.com/questions/1139353/simplest-way-to-define-a-route-that-returns-a-404) discussing how to do it.  But as you add more URLs your routes.rb will become messy so you want to move the them to a different file.  You could put them in application.rb:

{% highlight ruby %}
# application.rb
class Application < Rails::Application
  config.respond_200 = ['wp-login.php']
  config.redirect_root = ['login.aspx']
  #
end
# routes.rb
Rails.application.routes.draw do
  Rails.application.config.respond_200.each do |r2|
    get "/#{r2}", to: proc { [200, {}, ['']] }
  end
  Rails.application.config.redirect_root.each do |rr|
    get "/#{rr}", to: redirect('/')
  end
  #
{% endhighlight %}

But this can clutter your application.rb.  Why not create an initializer?

{% highlight ruby %}
# config/initializers/routes_exceptions.rb
RESPOND_200 = ['wp-login.php']
REDIRECT_ROOT = ['login.aspx']
# routes.rb
RESPOND_200.each do |r2|
  get "/#{r2}", to: proc { [200, {}, ['']] }
end
REDIRECT_ROOT.each do |rr|
  get "/#{rr}", to: redirect('/')
end
{% endhighlight %}

You can create additional rules for redirecting to different destinations or responding with other HTTP codes.  Keep in mind that your routes are evaluated in the order being listed in your routes.rb.  And having a huge routes.rb file could slow down your app.

But otherwise this a simple solution for keeping your logs clean.  You can also sign up for service like [AirBrake](https://airbrake.io/) or [Rollbar](https://rollbar.com) so you don't have to search logs.
