---
title: "Keeping your tests dry"
date: 2016-02-19
categories:
---

As you add more features to your application you inevitably have to change previous written code.  I was recently introducing polymorphic relation to a model.  Previously it was simply this:

{% highlight ruby %}
class Foo
  include Mongoid::Document
  belongs_to :bar
end
class Bar
  include Mongoid::Document
  has_many :foos
end
{% endhighlight %}

But I changed it to:

{% highlight ruby %}
class Foo
  include Mongoid::Document
  belongs_to :foobar,   polymorphic: true
end
class Bar
  include Mongoid::Document
  has_many :foos,   as: :foobar
end
class Far
  include Mongoid::Document
  has_many :foos,   as: :foobar
end
# Plus I had to do a small data migration
class MyMigration < Mongoid::Migration
  def self.up
    Foo.all.update_all(foobar_type: 'Bar')
    Foo.all.rename(bar_id: :foobar_id)
  end
  def self.down
    Foo.all.rename(foobar_id: :bar_id)
    Foo.all.unset(:foobar_type)
  end
end
{% endhighlight %}


Under the hood Rails uses **foobar_id** and **foobar_type** fields in Foo model.  But this post is not about polymorphic relations (you can read more [here](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations)).

After I made the change I was going through my code changing **foo.bar** to **foo.foobar**.  I also changed my Rspec test and FactoryGirl factories.  I noticed that while I only changed a few model / controller (core code) files I had to change LOTS of test files.  I do have pretty decent coverage (over 80%) but maintaining those tests can be quite time consuming.

The most common reason I had to change my tests is because I was explicity calling this in my tests:
{% highlight ruby %}
bar = create(:bar)
foo = create(:foo, bar: bar)
{% endhighlight %}

Even though I create association in the factory
{% highlight ruby %}
FactoryGirl.define do
  factory :bar do
    ...
  end
end
FactoryGirl.define do
  factory :foo do
    bar
  end
end
{% endhighlight %}

I had to call methods on Foo or Bar that expected a specific instance and it was just too easy to create in the test (only one line) than to properly think through how to setup the factory.