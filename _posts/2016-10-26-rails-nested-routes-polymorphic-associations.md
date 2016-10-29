---
title: "Rails nested routes and  polymorphic associations"
date: 2016-10-26
categories: rails
redirect_from:
  - /2016/10/26/rails-nested-routes-polymorphic-associations.html
---

Recently at work we had to implement [Rails nested resources](http://guides.rubyonrails.org/routing.html#nested-resources) with a [polymorphic association](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations).  I thought it would create an interesting blog post.  

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

We seed our DB:

{% highlight ruby %}
Article.delete_all
User.delete_all
Company.delete_all
5.times do |i|
  user = User.create(email: "user#{i}@email.com", password: "password", first_name: "first #{i}", last_name: "last #{i}")
  company = Company.create(name: "company#{i}")
  Article.create(title: "title#{i}", body: "body#{i}", author: user)
  Article.create(title: "title#{i}", body: "body#{i}", author: company)
end
{% endhighlight %}

Users and Companies need to do CRUD operations on their Articles.  Separately CMS internal editors need to CRUD operations on ALL articles.  We create routes like this:

{% highlight ruby %}
#routes.rb
resources :users do
  resources :articles
end
resources :companies do
  resources :articles
end
resources :articles
{% endhighlight %}

Now we need to implement controllers

{% highlight ruby %}
class ArticlesController < ApplicationController
  def index
    if params[:user_id].present?
      @articles = User.find(params[:user_id]).articles
    elsif params[:company_id].present?
      @articles = Company.find(params[:company_id]).articles
    else
      @articles = Article.all
    end
  end
  ...
end
{% endhighlight %}

Browsing to `http://localhost:3000/articles` will show all Articles.  Browsing to `http://localhost:3000/users/1/articles` and `http://localhost:3000/companies/1/articles` will filter articles for specific user / company.

When we browse to `http://localhost:3000/users/1/articles` and click Show on specific Article we want to be taken to `http://localhost:3000/users/1/articles/1`.  By default the `<%= link_to 'Show', article %>` will take us to `http://localhost:3000/articles/1`.  

{% highlight ruby %}
# app/views/articles/index.html.erb
<% if params[:user_id].present? %>
  <td><%= link_to 'Show', user_article_path(params[:user_id], article) %></td>
<% elsif params[:company_id].present? %>
  <td><%= link_to 'Show', company_article_path(params[:company_id], article) %></td>
<% else %>
  <td><%= link_to 'Show', article %></td>
<% end %>
{% endhighlight %}

To return to proper index route we modfiy

{% highlight ruby %}
# app/views/articles/show.html.erb
<% if params[:user_id].present? %>
  <%= link_to 'Back', user_articles_path %>
<% elsif params[:company_id].present? %>
  <%= link_to 'Back', company_articles_path %>
<% else %>
  <%= link_to 'Back', articles_path %>
<% end %>
{% endhighlight %}

But this puts the biz logic into our ERB files which will be hard to test.  Let's create a separate PORO.  

{% highlight ruby %}
# app/services/pathfinder.rb
class Pathfinder
  include Rails.application.routes.url_helpers
  def initialize(params:, record:)
    @params = params
    @record = record
  end
  def index
    # we can DRY this code by following user_id / company_id
    # pattern when deciding with `_path` helper to return.  
    if @params[:user_id].present?
      user_articles_path(@params[:user_id])
    elsif @params[:company_id].present?
      company_articles_path(@params[:company_id])
    else
      articles_path
    end  
  end
  def show
    ...
  end
  def edit
    ...
  end
  def new
    ...
  end
end
{% endhighlight %}

Now we can replace our `link_to` helpers in ERB files with these:

{% highlight ruby %}
<%= link_to 'Back', Pathfinder.new(params: params, record: @article).index %>
<%= link_to 'New Article', Pathfinder.new(params: params, record: nil).new %>
<%= link_to 'Edit', Pathfinder.new(params: params, record: article).edit %>
<%= link_to 'Show', Pathfinder.new(params: params, record: article).show %>
{% endhighlight %}

To restrict permissions so Users and Companies can view/edit only their own Articles we can implement [Pundit](https://github.com/elabs/pundit) or [CanCanCan](https://github.com/CanCanCommunity/cancancan).  I recenly wrote a [post]({% post_url 2016-09-29-roles-permissions %}) about that.  
