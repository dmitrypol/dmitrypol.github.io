---
title: "MVC"
date: 2016-10-02
categories:
---

When we first start with frameworks like [Ruby on Rails](http://rubyonrails.org/) or [Python's Django](https://www.djangoproject.com/) it is easy to follow [MVC](https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93controller) pattern.  You have layers with `Articles` table in your DB, `Article` model, `ArticlesController` with [7 RESTful actions](http://guides.rubyonrails.org/routing.html#resource-routing-the-rails-default) and `Articles View` with index, show, edit, new template files.  

In this pattern data goes up and down from DB to UI.  But as our applications grow things get more complex and data moves in different directions.  

I like to think of framework as a collections of objects (and modules) put together in very specific manner.  In traditional Rails application you have `app` folder with several subfolders.  There are `models`, `views` and `controlers` but there are also `helpers` and `mailers`.  [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) creates `jobs` subfolder and third party gems wil have their own subfolders ([Pundit](https://github.com/elabs/pundit) - `policies`, [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers) - `serializers`).  

But there is no reason you can't create your own subfolders.  You can have `services` for [service objects](https://blog.engineyard.com/2014/keeping-your-rails-controllers-dry-with-services), `forms` for [form objects](https://robots.thoughtbot.com/activemodel-form-objects).  Recently I started moving [validator classes](http://guides.rubyonrails.org/active_record_validations.html#custom-validators) into `validators` subfolder.  Inside these subfolders you can create POROs and follow Rails pattern of inheriting from common `ApplicationService` or `ApplicationFrom`.  You can test these PORO classes with tests in `spec\forms` and `spec\validators`.

Here are additional design patterns that I have come across.

* TOC
{:toc}

### Model only

You might have a model tied to a table but not have a controller or view for it.  [delayed_job](https://github.com/collectiveidea/delayed_job) has a model and table it uses for running background jobs.  But you would not build a controller and view to present this data to your users (perhaps at some internal Admin dashboard).  

### Controller only

You can have a controller end point that queues up a background job that will query external APIs, download data from FTP or use a static data file stored with application.  After processing that data it could email a spreadsheet to the user.

### View only

Often in your application you would have a `home#index` page (and perhaps also `home#about` and `home#help).  If those pages only present static text you can just need routes and a blank controller w/o any actions.  

{% highlight ruby %}
# config/routes.rb
Rails.application.routes.draw do
  get 'home/index'
  get 'home/about'
  get 'home/help'
end
# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
end
# app/views/welcome/index.html.erb
Welcome to our site
{% endhighlight %}



### Expand concept of model

Not just something tied to a DB table but a place to put business model logic.  

#### Form objects

Receive data from controller and save to multiple tables or send emails.  

Often we include different Rails modules in some of the classes.  

{% highlight ruby %}
class UserForm
  include ActiveModel::Model
  attr_accessor :name, :email
  validates :name, :email, presence: true
  def initialize(attributes={})
  end
end
{% endhighlight %}


#### Service objects

Either save or extract data.  

CanCanCan `ability.rb` lives in app/models but it's not fied to a table.  

We can also include specific Rails modules to get the functionality we need.

{% highlight ruby %}
class MyService
  include Rails.application.routes.url_helpers
end
{% endhighlight %}

#### Decorators and Serializers

Closesly tied to models backed by DB tables.  


#### Pundit policies


#### Validators


#### Mailers




### Conclusion




{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
