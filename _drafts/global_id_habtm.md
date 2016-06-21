---
title: "Global ID and has_and_belongs_to_many"
date: 2016-06-20
categories:
---

I previously wrote about creating [polymorphic has_and_belongs_to_many]({% post_url 2016-06-12-polymorphic_habtm %}) relationships.  But recently I came across an interesting idea of using Global ID to create polymorphic relationships.

With traditional polymorphic relationship you have parent_id and parent_type fields defined for child record.  You also have has_many :children defined from parent.

But using [GlobalID](https://github.com/rails/globalid) we can have a URI like this `gid://YourApp/Some::Model/id`.  We can store array of these on the child record.

{% highlight ruby %}
class Child
  field :parent_ids, type: Array
  def parent1s
  end
  def parent2s
  end
end
{% endhighlight %}

From the child side to get parent

{% highlight ruby %}
class Parent1
  def children
  end
end
class Parent2
  def children
  end
end
{% endhighlight %}

You definetely have to write a lot more custom code so it's not as simple as belongs_to and has_many.

http://stefan.haflidason.com/simpler-polymorphic-selects-in-rails-4-with-global-id/

http://stackoverflow.com/questions/34084140/using-global-id-to-specify-an-object-in-a-polymorphic-association
