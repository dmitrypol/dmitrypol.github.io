---
title: "Rails and complex data migrations"
date: 2016-10-27
categories:
---

When working with NoSQL DBs we do not worry about schema changes but we still need to do data migrations.  We have been using [mongoid_rails_migrations](https://github.com/adacosta/mongoid_rails_migrations) for this.

Sometimes the migrations are pretty simple.  

{% highlight ruby %}
class MyMigration < Mongoid::Migration
  def self.up
    Model.where(field: 'value1').update_all(field: 'value2')
  end
  def self.down
    Model.where(field: 'value2').update_all(field: 'value1')
  end
end
{% endhighlight %}

And sometimes they are more complex.  We can have 30+ lines in the `up` method as we are looping through records, validating / transforming the data and then updating / creating other records in our DB.  Why not move that logic into separate private methods in the migration class (it's a Ruby class after all) and call them as needed?  

{% highlight ruby %}
class AnotherMigration < Mongoid::Migration
  def self.up
    Model.where(field: 'value1').each do |record|
      result = process_record(record)
      update_related_record(result)
    end
  end
  def self.down
    Model.where(field: 'value1').each do |record|
      revert_record(record)
    end
  end
def private
  # need to use self because these class methods
  def self.process_record
    # actual logic here
  end
  def self.update_related_record(result)
    ...
  end
  def self.revert_record
    ...
  end
end
{% endhighlight %}


### Exception handling

When running these migrations it might be OK to just skip a few errors and continue.  For that we can use  [exceptions](http://rubylearning.com/satishtalim/ruby_exceptions.html).  I also like to use `limit` clause to speed things up when debugging.

{% highlight ruby %}
def self.up
  Model.where(field: 'value1').limit(10).each do |record|
    begin
      # do stuff
    rescue Exception => e
      puts e
    end
  end
end
{% endhighlight %}

### Testing

Sometimes the migrations are so complex that we want to write actual automated tests.  

{% highlight ruby %}
# spec/migrations/user_migration_spec.rb
require 'rails_helper'
# load migration class
require Dir[Rails.root.join('db/migrate/*_user_migration.rb')].first
describe UserMigration, type: :migration do
  it 'up' do
    # create records using FactoryGirl
    user = create(:user)
    UserMigration.up
    expect(user.reload.field).to eq 'new value'
  end
  it 'down' do
    user = create(:user, field: 'new value')
    UserMigration.down
    expect(user.reload.field).to eq 'old value'
  end
end
{% endhighlight %}

The same approach should work with data migrations in SQL DBs.  Just treat migrations as Ruby classes and test their methods.  

### Useful links

* [https://robots.thoughtbot.com/data-migrations-in-rails](https://robots.thoughtbot.com/data-migrations-in-rails)
* [http://edgeguides.rubyonrails.org/active_record_migrations.html](http://edgeguides.rubyonrails.org/active_record_migrations.html)
* [http://stackoverflow.com/questions/6079016/how-do-i-test-rails-migrations](http://stackoverflow.com/questions/6079016/how-do-i-test-rails-migrations)
