---
layout: post
title:  "Using one field hash vs embedded documents in MongoDB"
date: 	2015-10-22
categories:
---

I have been using [MongoDB](https://www.mongodb.org/) for over 2 years and really like for various things.  One useful feature is ability to store complex data types such as Hashes or Arrays in fields.  Actually MongoDB itself does not support Hashes but you can do it using ODM like [Mongoid](https://github.com/mongodb/mongoid).  It is much eaiser than serializing objects and storing them as strings in the DB.

The challenge comes when you have to manually edit these fields.  You know those situations where you get a call from a customer who made a mistake and you have to fix the data.  We are using [RailsAdmin](https://github.com/sferik/rails_admin) which works very well with Mongoid.

For editing Arrays you can create a RailsAdmin custom field following these [instructions](https://github.com/sferik/rails_admin/issues/1218).  But Hashes are tricky and you often have to edit it as a string, manually modifying complex data structure.

Instead of Hashes why not create separate models and embed it inside the main document?

Create models:
{% highlight ruby %}
class Foo
  include Mongoid::Document
  embeds_many  :bars
  accepts_nested_attributes_for :bars, allow_destroy: true  #	this will allow editing and deleteing embedded records
  ...
end
class Bar
  include Mongoid::Document
  embedded_in :foo
  field :name,                  type: String
	field :required,              type: Boolean, default: false
  field :options,               type: Array
  #	specify all kinds of fields, add validations and enumeration if you need to
  ...
end
{% endhighlight %}

I can now use RailsAdmin to edit Foo and inside it I can edit various Bars.  So I am not ready to completely gave up on Hashes but for certain things I am starting to really like them.  Embedding it in parent document makes it very easy to access and just loop through Foo.bars.each