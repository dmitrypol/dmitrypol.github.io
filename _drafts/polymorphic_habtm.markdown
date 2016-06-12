---
title: "Polymorphic has_and_belongs_to_many relationships"
date: 2016-06-12
categories:
---

When we first start designing appliciations we encounter typical has_many and belongs_to relationships.  User has_many Pctures and Picture belongs_to User.

{% highlight ruby %}
class User
  has_many :pictures
end
class Picture
  belongs_to :user
end
{% endhighlight %}

A more advanced use case is [has_and_belongs_to_many](http://guides.rubyonrails.org/association_basics.html#the-has-and-belongs-to-many-association).  Users can belong to many clubs and Clubs have many users.  Using [Mongoid](https://github.com/mongodb/mongoid) we can model it like this:

{% highlight ruby %}
class User
  has_and_belongs_to_many :clubs
end
# { "_id" : ObjectId("..."), "club_ids" : [ObjectId("...")], ... }
class Club
  has_and_belongs_to_many :users
end
# { "_id" : ObjectId("..."), "user_ids" : [ObjectId("...")], ... }
{% endhighlight %}
Relationship IDs are stored in arrays on both sides.  If you are using a SQL DB you will need to create a mapping table user_clubs.

Another advanced use case is [polymorphic associations](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations).  Here is a good [RailsCast](http://railscasts.com/episodes/154-polymorphic-association-revised).

{% highlight ruby %}
class Picture
  belongs_to :imageable, polymorphic: true
end
# has imageable_id and imageable_type
class User
  has_many :pictures, as: :imageable
end
class Club
  has_many :pictures, as: :imageable
end
{% endhighlight %}

I recently had to combine both polymorphic and has_and_belongs_to_many relationship between different models in our Mongo DB.  The challenge is that when I store relationship IDs in array with the record, I cannot define the relationship_type.  Solution is to go with SQL style mapping table and define polymorphic relationship there.  

{% highlight ruby %}
class Picture
  belongs_to :imageable, polymorphic: true
end
class User
  has_many :user_clubs
end
class Club
  has_many :user_clubs
end
class UserClub
  belongs_to :user
  belongs_to :club
  has_many :pictures, as: :imageable
end
{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}


