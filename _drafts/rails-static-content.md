---
title: "Rails and static content"
date: 2016-11-19
categories: rails redis
---

Often in our applications we need to add pages with content (FAQ, About Us,, etc).  We could implement a full blown CMS or we could just create a few HTML files.  

Let's start by creating `home/about` page and controller.  

{% highlight ruby %}
# app/controllers/home_controller.rb
class HomeController < ApplicationController
end
# app/views/home/about.html.erb
<h1>About Us</h1>
...
<% end %>
{% endhighlight %}

Later we can decide to implement [caching](http://guides.rubyonrails.org/caching_with_rails.html#fragment-caching) to speed up loading of these pages.  

#### Fragment caching

To enable Rails view caching we update development.rb or production.rb.

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

#### High Voltage gem

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



#### Static site generators

For more complex cases (technical documentation for the system) we can implement a static site generator like [middleman](https://middlemanapp.com/) or [jekyll](https://jekyllrb.com/)


https://www.sitepoint.com/jekyll-rails/


{% highlight ruby %}

{% endhighlight %}





#### Full blown CMS


Rails CMS https://hackhands.com/9-best-ruby-rails-content-management-systems-cms/

Using Rais to edit data in DB and then generating static content files from it to push to S3.  


{% highlight ruby %}

{% endhighlight %}



