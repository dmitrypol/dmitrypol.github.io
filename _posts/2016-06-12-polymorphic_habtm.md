---
title: "Polymorphic has_and_belongs_to_many relationships"
date: 2016-06-12
categories: mongo
---

When we first start designing appliciations we encounter typical has_many and belongs_to relationships.  User has_many Articles and Article belongs_to User.

{% highlight ruby %}
class User
  has_many :articles
end
class Article
  belongs_to :user
end
{% endhighlight %}

A more complex design is [has_and_belongs_to_many](http://guides.rubyonrails.org/association_basics.html#the-has-and-belongs-to-many-association).  User can have many Articles and Article can be owned by many Users.  Using [Mongoid](https://github.com/mongodb/mongoid) we can model it like this:

{% highlight ruby %}
class User
  has_and_belongs_to_many :articles
end
# { "_id" : ObjectId("..."), "article_ids" : [ObjectId("...")], ... }
class Article
  has_and_belongs_to_many :users
end
# { "_id" : ObjectId("..."), "user_ids" : [ObjectId("...")], ... }
{% endhighlight %}
Relationship IDs are stored in arrays on both sides.  If you are using a SQL DB you will need to create article_user mapping table.

Another advanced use case is [polymorphic associations](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations).  Here is a good [RailsCast](http://railscasts.com/episodes/154-polymorphic-association-revised).

{% highlight ruby %}
class User
  has_many :articles, as: :author
end
class Organization
  has_many :articles, as: :author
end
class Article
  belongs_to :author, polymorphic: true
  # has author_id and author_type (User or Organization)
end
{% endhighlight %}

I recently had to combine both polymorphic and has_and_belongs_to_many relationship between different models in our Mongo DB.  The challenge is that when I store relationship IDs in array with the record, I cannot define the relationship_type.  Solution is to go with mapping table and define polymorphic relationship there.

{% highlight ruby %}
# extract common code for User and Organization to app/models/concerns/
module ArticleAuthorMap
  extend ActiveSupport::Concern
  included do
    has_many :article_authors, as: :author
  end
  def articles
    article_authors.map(&:article)
  end
end
class User
  include ArticleAuthorMap
end
class Organization
  include ArticleAuthorMap
end
class Article
  has_many :article_authors
  def authors
    article_authors.map(&:author)
  end
end
class ArticleAuthor
  belongs_to :article
  belongs_to :author, polymorphic: true
end
{% endhighlight %}

You can do **article.authors**, **user.articles** and **organization.articles**.  In retrospect the solution was fairly straightforward but I could not find any examples online so I decided to write my own blog post.
