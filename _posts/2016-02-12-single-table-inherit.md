---
title: "Single table inheritance"
date: 2016-02-11
categories:
---

Often you have models with optional fields. And then you have to implement business logic that makes those fields required IF another field is set to specific value.  Otherwise these fields are not allowed.

{% highlight ruby %}
class Mymodel
  include Mongoid::Document
  field :field1, type: String
  field :opt_field1, type: String
  validates :opt_field1, presence: true, if: Proc.new { |a| a.field1 == 'foo' }
  validates :opt_field1, absence:  true, unless: Proc.new { |a| a.field1 == 'foo' }
  ...
end
{% endhighlight %}
It's pretty simple if you do it for one or two fields.  But often you need to build custom business logic around those fields and things get messy.

One option is to split the logic between several classes.
{% highlight ruby %}
class Mymodel
  include Mongoid::Document
  field :field1, type: String
  ...
  # add common methods
end
class Mymodel2 < Mymodel
  include Mongoid::Document
  field :opt_field1, type: String
  validates :opt_field1, presence: true
  ...
  # add custom methods or override the ones from Mymodel
end
{% endhighlight %}
With Mongoid it will automatically create _type field.  With AR you will need to add the column manually.  But now all your records are stored in the same table and you can define commong behavior and fields in the base class.  You can read more [here](http://api.rubyonrails.org/classes/ActiveRecord/Inheritance.html) and [here](http://www.informit.com/articles/article.aspx?p=2220311&seqNum=4).
