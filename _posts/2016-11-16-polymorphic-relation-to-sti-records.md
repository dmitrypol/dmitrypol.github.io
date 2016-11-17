---
title: "Polymorphic relation to Single Table Inhertiance records"
date: 2016-11-16
categories:
---

Previously I have written about [single table inheritance]({% post_url 2016-02-12-single-table-inherit%}) and [polymorphic relations]({% post_url 2016-06-12-polymorphic-habtm%}).  Here is an interesting combination of the two.  

Let's start with a simple `belongs_to` and `has_many` relationship with [Mongoid](https://github.com/mongodb/mongoid)

{% highlight ruby %}
class Article
  belongs_to :user
  field :body
end
class User
  has_many :articles
end
# Article data
{
  "_id" : ObjectId("56d76d37a7785f2a18000000"),
  "user_id" : ObjectId("56bbb6a9213ae95efa00017a"),
  "body" : "blah, blah, blah",
  ...
}
{% endhighlight %}

Here is a more complex polymorphic relationship.  

{% highlight ruby %}
class Article
  belongs_to :author, polymorphic: true	
  field :body
end
class User
  has_many :articles, as: :author
end
class Company
  has_many :articles, as: :author
end
# Article data
{
  "_id" : ObjectId("56d76d37a7785f2a18000000"),
  "author_id" : ObjectId("56bbb6a9213ae95efa00017a"),
  "author_type" : "User",
  "body" : "blah, blah, blah",
  ...
}
{% endhighlight %}

Now we introduce [single table inheritance](https://en.wikipedia.org/wiki/Single_Table_Inheritance) to store `admin` users.  

{% highlight ruby %}
class Admin < User
  # additonal fields
end
# Admin data in Users table/collection
{
  "_id" : ObjectId("5773f5e7a7785f5989ef2ae9"),
  "_type" : "Admin",
  ...
}
{% endhighlight %}

When Admin writes an Article data is stored like this:

{% highlight ruby %}
{
  "_id" : ObjectId("56d76d37a7785f2a18000000"),
  "author_id" : ObjectId("56bbb6a9213ae95efa00017a"),
  "author_type" : "Admin",
  "body" : "blah, blah, blah",
  ...
}
{% endhighlight %}

Now we decide to get rid of Admin model and just have User model.  We create a migration to change User records by removing `_type` attribute.  

{% highlight ruby %}
  User.where(_type: 'Admin').unset(:_type)
{% endhighlight %}

But what about our Article records?  We need to update them too.  

{% highlight ruby %}
  Article.where(author_type: 'Admin').update_all(author_type: 'User')
{% endhighlight %}

Otherwise we will get `uninitialized constant Admin` when trying to load articles with those relations.  Here is a link to [Rails documentation](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations).  