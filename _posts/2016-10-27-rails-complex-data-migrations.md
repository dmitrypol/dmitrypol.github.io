---
title: "Rails and complex data migrations"
date: 2016-10-27
categories: rails
redirect_from:
  - /2016/10/27/rails-complex-data-migrations.html
---

When working with NoSQL DBs we do not worry about schema changes but we still need to do data migrations.  We have been using [mongoid_rails_migrations](https://github.com/adacosta/mongoid_rails_migrations) for this.

* TOC
{:toc}

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

### Private methods

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
private
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

### Polymorphic relationships

Here are a few simple [polymorphic](http://guides.rubyonrails.org/association_basics.html#polymorphic-associations) models.  

{% highlight ruby %}
# app/models/user.rb
class User
  has_many :articles, as: :author, dependent: :delete
end
# app/models/article.rb
class Article
  belongs_to :article, polymorphic: true
end
{% endhighlight %}

We now need to rename User model to Person.  We can rename the class and DB table but how do we change the article relationships?  Well, as long as the IDs of indvividual person/user records did not change we can do this:

{% highlight ruby %}
Article.where(author_type: 'User').update_all(author_type: 'Person')
{% endhighlight %}

### Has And Belongs To Many relationships

With [Mongoid has_and_belongs_to_many](https://docs.mongodb.com/ruby-driver/master/tutorials/6.0.0/mongoid-relations/#has-and-belongs-to-many) we can store child records in an array inside the parent.  

{% highlight ruby %}
# app/models/user.rb
class User
  has_and_belongs_to_many :groups
end
# app/models/group.rb
class Group
  has_and_belongs_to_many :users
end
{% endhighlight %}

It will look like this in the DB:

{% highlight ruby %}
# User record
{
    "_id" : ObjectId("56941557213ae91d96000002"),
    "name" : "Bob Smith",
    "group_ids" : [
        ObjectId("56158d9269702d7a8c00018a")
    ]
}
# Group record
{
    "_id" : ObjectId("56158d9269702d7a8c00018a"),
    "name" : "Soccer group",
    "user_ids" : [
        ObjectId("56941557213ae91d96000002")
    ]
}
{% endhighlight %}

Now we need to rename Group to Team.  Here is the migraiton.  

{% highlight ruby %}
User.exists(group_ids: true).rename(group_ids: :team_ids)
{% endhighlight %}

### Lots of data

Let's imagine a blogging platform.  

{% highlight ruby %}
class Company
  has_many :users
end
class User
  belongs_to :company
  has_many :articles
end
class Article
  belongs_to :user
  has_many :comments
end
class Comment
  belongs_to :article
end
{% endhighlight %}

Now we need to create a relationship between `comment` and `article author`.  

{% highlight ruby %}
class User
  has_many :article_comments, class_name: 'Comment', inverse_of: :article_author
end
class Comment
  belongs_to :article_author, class_name: 'User', inverse_of: :article_comments
end
{% endhighlight %}

And we need a migration to update records.  But we have millions of comments and thousands of articles.  This will be VERY slow as it will query for each article AND user and then do indvividual updates.  

{% highlight ruby %}
Comment.all.no_timeout.each do |c|
  c.update(article_author_id: c.article.user_id)
end
{% endhighlight %}

This will be faster because it will [eager load](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid%2FCriteria%3Aincludes) related articles.  But it will require lots of RAM.  

{% highlight ruby %}
Comment.all.includes(:article).no_timeout.each do |c|
  c.update(article_author_id: c.article.user_id)
end
{% endhighlight %}

This will be even faster because it will do bulk updates for ALL comments for specific article but will still require lots of RAM.

{% highlight ruby %}
Article.all.includes(:comments).no_timeout.each do |a|
  a.comments.update_all(article_author_id: a.user_id)
end
{% endhighlight %}

This will break up work into smaller chunks for each group of users (by company).  It will require far less RAM.

{% highlight ruby %}
def self.up
  Company.all.no_timeout.each do |company|
    update_comments company.users.pluck(:_id)
  end
end
def self.update_comments user_ids
  Article.in(user_id: user_ids).includes(:comments).no_timeout.each do |art|
    art.comments.update_all(article_author_id: art.user_id)
  end
end
{% endhighlight %}

Alternatively we could batch users.  With ActiveRecord we could use [find_in_batches](http://apidock.com/rails/ActiveRecord/Batches/find_in_batches). For Mongoid use something like this  [gist](https://gist.github.com/justinko/1272234)

{% highlight ruby %}
def self.up
  User.find_in_batches(batch_size: 100) do |batch|
    update_comments batch.pluck(:id)
  end
end
def update_comments user_ids
end
{% endhighlight %}


### Useful links

* [https://robots.thoughtbot.com/data-migrations-in-rails](https://robots.thoughtbot.com/data-migrations-in-rails)
* [http://edgeguides.rubyonrails.org/active_record_migrations.html](http://edgeguides.rubyonrails.org/active_record_migrations.html)
* [http://stackoverflow.com/questions/6079016/how-do-i-test-rails-migrations](http://stackoverflow.com/questions/6079016/how-do-i-test-rails-migrations)
