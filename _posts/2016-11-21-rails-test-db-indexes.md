---
title: "Rails testing DB indexes"
date: 2016-11-21
categories: rails mongo
---

With [ActiveRecord](http://edgeguides.rubyonrails.org/active_record_migrations.html) to create indexes we need to run migrations.  But with [Mongoid](https://github.com/mongodb/mongoid) we simply specify indexes in our models.  Here is a hypothetical User model.  We want email and name to be required and email to be unique.  

{% highlight ruby %}
# app/models/user.rb
class User
  field :name
  field :email
  validates :email, name, presence: true
  validates :email, uniqueness: true
end
{% endhighlight %}

Instead of doing email uniqueness validation in application code it's better to shift it to DB index via `index({ email: 1 }, { unique: true })`.

### Removing / creating indexes

 To update our DB we need to run these commands after deploying to production.  

{% highlight ruby %}
bundle exec rake db:mongoid:remove_undefined_indexes RAILS_ENV=production
bundle exec rake db:mongoid:create_indexes RAILS_ENV=production
{% endhighlight %}

But when we run tests it can be useful to bypass certain validations in test data setup.  We could use [factory girl](https://github.com/thoughtbot/factory_girl_rails) and put required fields into our factory file.  The problem is that sometimes records must belong to other records and then to create child we must first create parent just to make validation happy.  

Here we are creating users w/o name or email:

{% highlight ruby %}
user1 = User.new
user1.save(validate: false)
user2 = User.new
user2.save(validate: false)
{% endhighlight %}

The problem is it will fail to create second user because there is already a user with blank email in our DB.  

{% highlight ruby %}
Failure/Error: [0muser2.save([35mvalidate[0m: [1;36mfalse[0m)
Mongo::Error::OperationFailure:
  E11000 duplicate key error collection: my_db_test.users
  index: _email_1 dup key: { : undefined } (11000)
{% endhighlight %}

So we need to manually specify email (but not necessarily name) to make MongoDB happy:

{% highlight ruby %}
user1 = User.new(email: 'foo@bar.com')
user1.save(validate: false)
user2 = User.new(email: 'bar@foo.com')
user2.save(validate: false)
{% endhighlight %}

But how do we keep our test DB indexes in sync with production DB w/o manually running `rake db:*` when we update indexes?  If we forget it can cause situation where the tests pass but code fails in production.  

`rake db:*` are simply Rake tasks so what we need to is run [rake](http://stackoverflow.com/questions/13704976/how-to-call-a-rake-task-in-rspec) from Rspec.  

{% highlight ruby %}
# spec/rails_helper.rb
...
require 'rspec/rails'
# add these lines
require 'rake'
Rails.application.load_tasks
...
RSpec.configure do |config|
  config.before(:all) do
    # add these lines
    Rake::Task['db:mongoid:remove_undefined_indexes'].invoke
    Rake::Task['db:mongoid:create_indexes'].invoke
    ...
  end
end
{% endhighlight %}

Now the indexes are refreshed before every test suite run.  

### Updating existing indexes

Another important issue to address is when we update current indexes.  What if we implement [multitenancy](https://en.wikipedia.org/wiki/Multitenancy) where Users belong to Clients and email uniqueness has to be w/in Client?  We need to update DB index.  

{% highlight ruby %}
# app/models/client.rb
class Client
  has_many :users
end
# app/models/user.rb
class User
  belongs_to :client
  field :email
  index({ client: 1,  email: 1 }, { unique: true })
end
{% endhighlight %}

When we run `rake db:mongoid:create_indexes` it will create new index with named `email_1_client_1` vs `email_1` before.  

But what if the name does not change?  We can switch to [background indexes](https://docs.mongodb.com/v3.2/core/index-creation/) with `index({ client: 1,  email: 1 }, { unique: true, background: true })`.  The best way I can think of is to manually edit index in the DB which is a little messy.  In test environment we can just drop the index, collection or entire DB.  Otherwise you get this error:

{% highlight ruby %}
Failure/Error: Rake::Task['db:mongoid:create_indexes'].invoke
Mongo::Error::OperationFailure:
  Index with name: email_1_client_1 already exists with different options (85)
{% endhighlight %}
