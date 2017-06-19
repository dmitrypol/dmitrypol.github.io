---
title: "Does SQL plus Key Value equal Document?"
date: 2017-06-19
categories: redis mongo
---

Storing records in SQL DB requires a fixed set of columns.  User has `first name`, `last name`, `email`, etc.  But in a [mutltitenant applications](https://en.wikipedia.org/wiki/Multitenancy) some records may require specific fields.  We can have optional fields (`middle name`) but having too many of them is not practical.

What if we had to build an online shopping mall with multiple `Stores`.  They all have `Purchases` but store selling t-shirts will require `size` and `color` in `purchase` record.  Another store would require different custom fields.  

We do not want to create optional columns `color` and `size` in our DB.  It will result in a messy database and require developers to make code/schema changes for new customers.  

* TOC
{:toc}

### Document structure

If we are already using a document DB like [Mongo](https://www.mongodb.com) or [Couch](http://couchdb.apache.org/) we are not constrained by that rigid table structure.  I used [Mongoid Dynamic attributes](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Attributes/Dynamic) in several applications which gave me ability to define these custom fields that are only present in some of the records.  I previously wrote about that [here]({% post_url 2015-11-15-dynamic-fields %})

{% highlight ruby %}
class Store
  include Mongoid::Document
  has_many :purchases
end
class Purchase
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  belongs_to :store
end
{% endhighlight %}

### Predefined columns

But often we NEED that SQL structure.  We need joins and transactions or its simply not an option to move from existing MySQL or Postgres.  

One option is to create a predefined number of fields of different datatypes.  `Purchases` table will have `text_field1` - `text_field5` and `num_field1` - `num_field5`.  Then in `Store` model we add `text_label1` - `text_label5` and `num_label1` - `num_label5`.  

Store admins can configure these values via their dashboard.  Then we create methods to display appropriate labels in the UI for end users.  

{% highlight ruby %}
class Purchase
  def get_text_label1
    store.text_label1
  end
  ...
end
{% endhighlight %}

The downside is it restricts us to only having a preset number of these custom fields and creates a bunch of optional columns in the DB.  

### Serialized data

We could create a dedicated field to store serialized version of multiple custom fields.  Both [MySQL](https://dev.mysql.com/doc/refman/5.7/en/json.html) and [Postgres](https://www.postgresql.org/docs/9.3/static/functions-json.html) support JSON data type.  

The downside with this approach is that it can limit using rich SQL querying capabilities.  How do we query all Purchases where size is large if size is serialized in this JSON field?  Unless we are using latest versions of MySQL / Postgres we will have to do [SQL LIKE](http://www.tutorialspoint.com/sql/sql-like-clause.htm) queries which is slow and less reliable.  But we can do queries like this which can solve a lot of our problems:

{% highlight ruby %}
SELECT name, custom_fields->"$[0]" AS `custom_field1` FROM `purchases`;
{% endhighlight %}

### Custom tables per client

At a previous job we ended up building custom solution that created special tables (one for each customer).  They had the columns that those customer's user records needed and were linked to the main `Users` table.  It took a long time to build and maintain.  

### SQL plus Key Value

I would like to expore how can we solve this challenge by combining SQL DB with a Key/Value store like [Redis](http://redis.io/).  

In [Ruby on Rails](http://rubyonrails.org/) there is an interesting gem [redis-objects](https://github.com/nateware/redis-objects) but the same approach could be adapated to other languages / frameworks.  

{% highlight ruby %}
class Store
  has_many :custom_fields
end
class CustomFields
  belongs_to :store
  # define name, html_control (input, boolean, select), required (boolean), ...
end
class Purchase
  include Redis::Objects
  hash_key :custom_values
end
{% endhighlight %}

Internal users can configure `custom_fields` on `store` level.  Then UI will display appropriate HTMl controls.  When data is submitted to the server it can be saved like this:  `purchase.custom_values.update({"size"=>"xl", "color"=>"red"})`

To display data for internal reporting purposes we can do this:

{% highlight ruby %}
@purchases.each do |purchase|
  purchase.user_name
  purchase.custom_values.each do |cv|
    ...
  end
end
{% endhighlight %}

#### Pros

* We can use rich [data structures](http://redis.io/topics/data-types) like Redis Hashes, Sets and Lists.
* Redis is FAST.  

#### Cons

* We are introducing additional technologies into our stack.  Our application needs to talk to both MySQL and Redis.  
* We cannot use native DB transactions across MySQL and Redis and will need to build custom logic in our application to rollback.  
* We cannot combine data attributes we store in Redis with the ones stored in SQL in our queries.  
* Redis requires RAM which is more expensive.  So if we are storing LOTS of custom attributes we need a big Redis instance.  

### Links

* [http://tylerstroud.com/2014/11/18/storing-and-querying-objects-in-redis/](http://tylerstroud.com/2014/11/18/storing-and-querying-objects-in-redis/)
* [https://www.sitepoint.com/use-json-data-fields-mysql-databases/](https://www.sitepoint.com/use-json-data-fields-mysql-databases/)
