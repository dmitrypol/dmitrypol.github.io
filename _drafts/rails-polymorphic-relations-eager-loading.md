---
title: "Rails polymorphic relations and eager loading"
date: 2016-10-26
categories:
---


2016-10-26-rails-nested-routes-polymorphic-associations.md


Let's imagine a CMS where Article can belong to either User or Company.  With polymorphic relations we can model it like this:

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

Now on to controller

{% highlight ruby %}
class ArticlesController < ApplicationController
  def index
    @articles = Article.all.includes(:author)
  end
end
{% endhighlight %}

Otherwise we cause N+1 queries as we query for each author (user or company)
