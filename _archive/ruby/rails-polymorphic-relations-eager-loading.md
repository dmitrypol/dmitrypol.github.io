---
title: "Rails polymorphic relations and eager loading"
date: 2016-10-27
categories: rails
---

This is a follow up on previous post about [nested routes and polymorphic associations]({% post_url 2016-10-26-rails-nested-routes-polymorphic-associations %}).  

Let's look at our CMS where Article can belong to either User or Company.  Here are the DB models:

{% highlight ruby %}
# app/models/user.rb
class User
  has_many :articles, as: :author, dependent: :delete
end
# app/models/company.rb
class Company
  has_many :articles, as: :author, dependent: :delete
end
# app/models/article.rb
class Article
  belongs_to :article, polymorphic: true
end
{% endhighlight %}

UI behind `http://localhost:3000/articles` will have this:

{% highlight ruby %}
# app/views/articles/index.html.erb
<% @articles.each do |article| %>
  ...
  <td><%= article.author.name %></td>
  ...
<% end %>
{% endhighlight %}

The problem is it will cause N+1 queries as we fetch each user and company names separately.  We can try to implement the usual [Rails includes](http://guides.rubyonrails.org/active_record_querying.html)

{% highlight ruby %}
class ArticlesController < ApplicationController
  def index
    @articles = Article.all.includes(:author)
  end
end
{% endhighlight %}


http://stackoverflow.com/questions/22012832/rails-includes-with-polymorphic-association



This does not work with [Mongoid includes](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid%2FCriteria%3Aincludes) and  results in error message:

{% highlight ruby %}
message:
  Eager loading :author is not supported since it is a polymorphic
  belongs_to relation.
summary:
  Mongoid cannot currently determine the classes it needs to eager load when
  the relation is polymorphic. The parents reside in different collections
  so a simple id lookup is not sufficient enough.
resolution:
  Don't attempt to perform this action and have patience,
  maybe this will be supported in the future.
{% endhighlight %}
