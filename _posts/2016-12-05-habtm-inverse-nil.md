---
title: "Mongoid has_and_belongs_to_many with inverse_of :nil"
date: 2016-12-05
categories: mongo
---

[Mongoid has_and_belongs_to_many](https://docs.mongodb.com/ruby-driver/master/tutorials/5.1.0/mongoid-relations/#has-and-belongs-to-many) gives us new ways of modeling relationships by not creating mapping tables/collections.  

* TOC
{:toc}

### Traditional has_and_belongs_to_many

{% highlight ruby %}
# app/models/user.rb
class User
  field :email
  has_and_belongs_to_many :roles
end
# app/models/role.rb
class Role
  field :name
  has_and_belongs_to_many :users
end
{% endhighlight %}

Records are stored in MongoDB like this:

{% highlight ruby %}
# role record
{
    "_id" : ObjectId("5845ac55f5740c5ddd970421"),
    "name" : "role1",
    "user_ids" : [
        ObjectId("5845ac56f5740c5ddd970433"),
        ObjectId("5845ac55f5740c5ddd970430")
    ]
}
# user record
{
    "_id" : ObjectId("5845ac56f5740c5ddd970433"),
    "email" : "user1@email.com",
    "role_ids" : [
        ObjectId("5845ac55f5740c5ddd970421"),
        ObjectId("5845ac55f5740c5ddd970428")
    ],
}
{% endhighlight %}

When we delete a user it's `user_id` will be automatically removed from all `role.user_ids` arrays.  And when we delete `role` that `role_id` will be removed from all `user.role_ids`.

### inverse_of: nil

But then our our system grows with tens of thousands of users in each role.  We do not want to store all those `user_ids` in `role`.  We can modify `has_and_belongs_to_many` like this to only store `role_ids` in `user` record.

{% highlight ruby %}
class User
  has_and_belongs_to_many :roles, inverse_of: nil
end
class Role
  #remove has_and_belongs_to_many :users
  # this method will query Users collection
  def get_users
    User.in(role_ids: self.id)
  end
end
{% endhighlight %}

Data is now stored like this:

{% highlight ruby %}
# role record
{
    "_id" : ObjectId("5845ac55f5740c5ddd970421"),
    "name" : "role1",
    # no user_ids array
}
# user record
{
    "_id" : ObjectId("5845ac56f5740c5ddd970433"),
    "email" : "user1@email.com",
    "role_ids" : [
        ObjectId("5845ac55f5740c5ddd970421"),
        ObjectId("5845ac55f5740c5ddd970428")
    ],
}
{% endhighlight %}

The problem is when we delete Role record it's `ObjectId` will remain in all `User.role_ids`.  Since there is no relationship defined in Role model the default callbacks do not fire.  So we need to create a custom callback to remove specific role `ObjectId` from ALL `user.role_ids`.  Instead of `array.push` we will use `array.pull`.

{% highlight ruby %}
class Role
  after_destroy :update_user_role_ids
private
  def update_user_role_ids
    User.all.pull(role_ids: self.id)
  end
end
{% endhighlight %}

When we look in development.log we will see the DB queries which are the same as if there was a default relationship from Role to User.

{% highlight ruby %}
# delete role
{"delete"=>"roles", "deletes"=>[{"q"=>{"_id"=>BSON::ObjectId(
  '5845baf8f5740c7bc8c03952')}, "limit"=>1}], "ordered"=>true}
# update users
{"update"=>"users", "updates"=>[{"q"=>{}, "u"=>{"$pull"=>{"role_ids"=>BSON::
  ObjectId('5845baf8f5740c7bc8c03952')}}, "multi"=>true, "upsert"=>false}], "ordered"=>true}
{% endhighlight %}

Let's write some tests to make sure it works:

{% highlight ruby %}
# spec/models/role_spec.rb
require 'rails_helper'
RSpec.describe Role, type: :model do
  it 'update_user_role_ids' do
    r1 = Role.new
    r1.save(validate: false)
    r2 = Role.new
    r2.save(validate: false)
    # =>
    u1 = User.new(roles: [r1, r2])
    u1.save(validate: false)
    u2 = User.new(roles: [r1, r2])
    u2.save(validate: false)
    # =>
    expect(u1.roles.count).to eq 2
    expect(u2.roles.count).to eq 2
    expect(r1.get_users.count).to eq 2
    expect(r2.get_users.count).to eq 2
    # =>
    r1.destroy
    expect(u1.roles).to eq [r2]
    expect(u2.roles).to eq [r1]
    r2.destroy
    expect(u1.roles).to eq []
    expect(u2.roles).to eq []    
  end
end
{% endhighlight %}

#### counter_cache

What if we want to sort roles by the number of users in each one?  In traditional `belongs_to` relationship we can use [counter_cache](https://docs.mongodb.com/ruby-driver/master/tutorials/6.0.0/mongoid-relations/#the-counter-cache-option).  For `has_and_belongs_to_many` we need to create a custom callback.  

{% highlight ruby %}
class Role
  field :users_count, type: Integer
end
class User
  after_save :update_role_users_count
private
  def update_role_users_count
    roles.each do |team|
      role.update(users_count: role.get_users.count)
    end
  end
end
{% endhighlight %}

The downside with this approach is it will cause count queries against Users collection for specific roles on each user save.  We can make this approach smarter by checking if roles changed and then incrementing/decrementing `role.users_count`.

Having these custom callbacks can complicate the application (lead to bugs) so I prefer using traditional two sided `has_and_belongs_to_many`.

### Roles array

Another way we can store this data is to create a simple array on the user record and store roles as strings.  To get users by role we create scopes on User model (`User.role1`, `User.role2`)

{% highlight ruby %}
# config/application.rb
config.roles = ['role1', 'role2']
# app/models/user.rb
class User
  field :email
  field :roles, type: Array
  enumerize :roles, in: Rails.application.config.roles, multiple: true
  Rails.application.config.roles.each do |r|
    scope r, ->{ where(:roles.in => r) }
  end
end
# user record in the DB
{
    "_id" : ObjectId("5845ac56f5740c5ddd970433"),
    "email" : "user1@email.com",
    "roles" : [
        'role1',
        'role2'
    ],
}
{% endhighlight %}

This approach is fine if we have a fairly fixed number of roles.  But what if we want to store something like tags for our users?  The only difference is we do not restrict tags field to specific enumeration and change scope to accept `tags` parameter.  

{% highlight ruby %}
# app/models/user.rb
class User
  field :email
  field :tags, type: Array
  scope :by_tags, -> ( tags ) { where(:roles.in => tags) }
end
{% endhighlight %}
