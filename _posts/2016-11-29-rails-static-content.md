---
title: "Rails and static content"
date: 2016-11-29
categories: rails redis
---

Often in our applications we need to add pages with fairly static content (FAQ, About Us, etc).  We could implement a full blown [CMS](https://hackhands.com/9-best-ruby-rails-content-management-systems-cms/) or we could create a few HTML/ERB files.  Let's explore different approaches.  

* TOC
{:toc}

### Template and controller

First we create `home/about` template and controller.  

{% highlight ruby %}
# config/routes.rb
get 'home/about'
# app/controllers/home_controller.rb
class HomeController < ApplicationController
end
# app/views/home/about.html.erb
<h1>About Us</h1>
...
<% end %>
{% endhighlight %}

Let's do a quick perf test using [wrk](https://github.com/wg/wrk).  `./wrk -d30s http://localhost:3000/home/about` gives us `Requests/sec:  71.21`

#### Fragment caching

Now we implement [caching](http://guides.rubyonrails.org/caching_with_rails.html#fragment-caching) to speed up page loading.  To enable Rails view caching we update development.rb or production.rb.

{% highlight ruby %}
config.action_controller.perform_caching = true
config.cache_store = :readthis_store, { expires_in: 10.minutes, namespace:
'cache_ns', redis: { host: 'localhost', port: 6379, db: 0 }, driver: :hiredis }
{% endhighlight %}

Add `cache` block to `app/views/home/about.html.erb`

{% highlight ruby %}
<% cache do %>
  <h1>About Us</h1>
  ...
<% end %>
{% endhighlight %}

Data will be cached like this:

`{"db":0,"key":"cache_ns:views/localhost:3000/home/about/
26b9257e71f9836c872a85c2d2f8359c","ttl":591,"type":"string","value":"...","size":17}`

Running same perf test as before gives us `Requests/sec:  66.16` which is slower.  

### High Voltage gem

[high_voltage](https://github.com/thoughtbot/high_voltage) is a Rails engine for creating static pages.  We can add `cache` block to these files same as before.

{% highlight ruby %}
# app/views/pages/products.html.erb`
<% cache do %>
  <h1>List of Products</h1>
  ...
<% end %>
{% endhighlight %}

`{"db":0,"key":"cache_ns:views/localhost:3000/pages/products/
79fa0ff0d0bfcd1ab0b3b85a27f3c3bc","ttl":590,"type":"string","value":"...","size":29}`

We can create folder/subfolder structure and apply caching to it.  

{% highlight ruby %}
# app/views/pages/products/product1.html.erb`
<% cache do %>
  <h1>Product1</h1>
  ...
<% end %>
{% endhighlight %}

`{"db":0,"key":"cache_ns:views/localhost:3000/pages/products/product1/
712c98b51df8e161a1a89c8b56a636ac","ttl":597,"type":"string","value":"...","size":29}`

Without caching running `./wrk -d30s http://localhost:3000/pages/products` gives us `Requests/sec:  73.55`.  With caching enabled we get `Requests/sec:  66.78`.

Applying caching to such static files actually slows things down a little bit.  If our pages had rich CSS or pulled data from DB then caching would likely speed things up.  

### HTML files

Another option is to simply put HTML/CSS/JS into public folder.  

{% highlight ruby %}
# public/about.html
<h1>About</h1>
...
{% endhighlight %}

`./wrk -d30s http://localhost:3000/about.html` gives us `Requests/sec: 56277.05`.  MUCH faster.  

### Static site generators

For more complex docs (such as technical documentation) we can integrate a static site generator like [middleman](https://middlemanapp.com/) or [jekyll](https://www.sitepoint.com/jekyll-rails/) into our Rails app.  Middleman gives us tools similar to Rails (helpers, partials, layouts) to speed up our development.  

Add `middleman` to Gemfile and run `middleman init content` from app root.  It will create `content` subfolder.  We want to output static HTML to public/content subfolder to serve via our webserver.  

{% highlight ruby %}
# content/config.rb
...
set :build_dir, '../public/content'
set :http_prefix, 'content'
# .gitignore
...
public/content/*
{% endhighlight %}

Running perf test `./wrk -d30s http://localhost:3000/content` gives us `Requests/sec: 9936.43`.  Slower than plain about.html page but now our page is much richer with CSS / JS.  

After we deploy the application we need to run `cd content && middleman build` via a post deploy hook on production server.  Read middleman documentation for how to implement various features it supports.  

### Links

* [https://blog.engineyard.com/2015/middleman-static-sites-arent-just-for-blogs](https://blog.engineyard.com/2015/middleman-static-sites-arent-just-for-blogs)
* [https://www.datocms.com/blog/datocms-middleman-beginners-guide/](https://www.datocms.com/blog/datocms-middleman-beginners-guide/)



{% highlight ruby %}

{% endhighlight %}
