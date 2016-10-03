---
title: "MVC"
date: 2016-10-02
categories:
---

When we first start with frameworks like Ruby on Rails or Python's Django it is easy to follow [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller) pattern.  You have 4 layers with Articles table in your DB, `Article` model, `ArticlesController` with [7 RESTful actions](http://guides.rubyonrails.org/routing.html#resource-routing-the-rails-default) and Articles View with index, show, edit, new template files.  

In this pattern data goes up and down from DB to UI.  But as our applications grow things get more complex and data moves in different directions.  Here are additional design patterns.  

## Model only

You might have a model tied to a table but not have a controller or view for it.  [delayed_job](https://github.com/collectiveidea/delayed_job) has a model and table it uses for running background jobs.  But you would not build a controller and view to present this data to your users (perhaps at some internal Admin dashboard).  

## Controller only

You can have a controller end point that queues up a background job that will query external APIs, download data from FTP or use a static data file stored with application.  After processing that data it could email a spreadsheet to the user.

## View only

Often in your application you would have a `home#index` page (and perhaps also `home#about` and `home#help).  If those pages only present static text you can just need routes and a blank controller w/o any actions.

{% highlight ruby %}
# config/routes.rb
Rails.application.routes.draw do
  get 'home/home'
  get 'home/index'
  get 'home/about'
end
# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
end
{% endhighlight %}




## Expand concept of model

Not just something tied to a DB table but a place to put business model logic.  


### Service objects

Either save or extract data.  

CanCanCan `ability.rb` lives in app/models but it's not fied to a table.  


### Form objects

Receive data from controller and save to multiple tables or send emails.  


### Decorators and Serializers

Closesly tied to models backed by DB tables.  


### Pundit policies


### Validators


### Mailers





{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
