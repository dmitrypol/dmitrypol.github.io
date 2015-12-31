---
title: "Using Mongo flexible schema with Rails app"
date: 2015-11-15
categories: mongo
---

One of the great things about [MongoDB](https://www.mongodb.org/) is the flexible schema.  In the past whenever we had to store custom data attributes in relational DBs we had to create separate lookup tables.  There would be a preset number of these custom fields with specific data types and separately we stored what their labels should be.  Or we would create tables for key/value pairs and do complex lookups.  It was a pain.  That's where flexible schema is great.

Let's say you are building an online shopping mall where different Stores have multiple Orders.  With flexible schema your document just shrinks and expands as needed storing different fields for different Order documents (depending on which Store they belong to).  We are using [Mongoid](https://github.com/mongodb/mongoid) ODM so our models look like this

{% highlight ruby %}
class Store
  include Mongoid::Document
  has_many :orders
  field :name,                  type: String
  ...
end
class Order
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic # this enables Mongoid to store dynamic fields
  belongs_to :store
  # list common fields here
  ...
end
{% endhighlight %}

But how do you read/write these dynamic attributes from your code?  To do that we created a new model which describes these dynamic attributes:

{% highlight ruby %}
class DynamicAttributes
  include Mongoid::Document
  embedded_in :store    
  # there is inverse embeds_many: dynamic_attributes defined in Store model
  field :name,                  type: String
  field :html_control,          type: String # this could be input, boolean or select
  ...
end
{% endhighlight %}

In our UI we use this to generate custom HTML for each order form so users can enter the information:
{% highlight ruby %}
order.store.dynamic_attributes.each do |field|
  # render your HTML
end
{% endhighlight %}

And we used **order.write_attribute(:field_name_here)** and **order.read_attribute(:field_name_here)** in models/controllers to access the data.  This way Order model can have certain common fields and then each store can be configured with dynamic fields.  The example above is not what we actually implemented at work but I wanted to simplify things.  

#### Usefull links
* [https://docs.mongodb.org/ecosystem/tutorial/ruby-mongoid-tutorial/#dynamic-fields](https://docs.mongodb.org/ecosystem/tutorial/ruby-mongoid-tutorial/#dynamic-fields)
* [http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Attributes](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Attributes)
