---
title: "Rails leaderboards"
date: 2016-12-02
categories: rails redis
---

Leaderboard is a usefull way to show ranking of various records by specific criteria.  Let's imagine a system where Users have Purchases.  We want to display users by the following metrics:  number of purchases, total amount spent and average purchase amount.  

### Class methods

{% highlight ruby %}
# app/models/purchase.rb
class Purchase
  field :amount, type: Float
  belongs_to :user
end
# app/models/user.rb
class User
  has_many :purchases
  ...
  def get_purchases_count
    purchases.count
  end
  def get_purchases_sum
    purchases.sum(:amount)
  end
  def get_purchases_avg
    return 0 if get_purchases_sum == 0
    get_purchases_count / get_purchases_sum
  end
end
{% endhighlight %}

Here is the UI (with [high_voltage](https://github.com/thoughtbot/high_voltage) gem):

{% highlight ruby %}
# app/views/pages/leaderboard/methods.html.erb
<table class='table'>
  <thead>
    <th>User</th>
    <th>Count</th>
    <th>Sum</th>
    <th>Avg</th>
  </thead>
  <% User.all.each do |u| %>
    <tr>
      <td><%= u.name %></td>
      <td><%= u.get_purchases_count %></td>
      <td><%= u.get_purchases_sum %></td>
      <td><%= u.get_purchases_avg %></td>
    </tr>
  <% end %>
</table>
{% endhighlight %}

This approach is useful for grabbing data for 1 User record but leaderboard is slow due to numerous N+1 queries.  And there is no easy way to sort records w/o loading them all into the application.  

### Pre-generating data in the DB

We can use [counter_cache](http://guides.rubyonrails.org/association_basics.html) and custom callbacks from `Purchase` side to pre-generate summary data on `User` record.  

{% highlight ruby %}
# app/models/purchase.rb
class Purchase
  ...
  belongs_to :user, counter_cache: true
  after_save :update_user_stats
private
  def update_user_stats
    user.update(purchases_sum: user.get_purchases_sum,
      purchases_avg: user.get_purchases_avg)
  end
end
# app/models/user.rb
class User
  ...
  field :purchases_count, type: Integer
  field :purchases_sum,   type: Integer
  field :purchases_avg,   type: Float
end
{% endhighlight %}

We can now sort by either `purchases_count`, `purchases_avg` or `purchases_sum`.

{% highlight ruby %}
# app/views/pages/leaderboard/db.html.erb
<table class='table'>
  ...
  <% User.all.order_by(:purchases_count.desc).each do |u| %>
    <tr>
      <td><%= u.name %></td>
      <td><%= u.purchases_count %></td>
      <td><%= u.purchases_sum %></td>
      <td><%= u.purchases_avg %></td>
    </tr>
  <% end %>
</table>
{% endhighlight %}

### Leaderboard gem

[leaderboard](https://github.com/agoragames/leaderboard) is an interesting gem that uses Redis [sorted sets](https://redis.io/topics/data-types#sorted-sets) to store data.  Storing data in RAM allows us to update it very quickly and Redis returns records in sorted order.  

{% highlight ruby %}
# config/initializers/redis.rb
USER_PURCHASES_COUNT = Leaderboard.new('user_purchases_count')
USER_PURCHASES_SUM = Leaderboard.new('user_purchases_sum')
USER_PURCHASES_AVG = Leaderboard.new('user_purchases_avg')
# app/models/purchase.rb
class Purchase
  ...
  after_save :update_user_stats
private
  def update_user_stats
    USER_PURCHASES_COUNT.rank_member(user.id.to_s,
      user.purchases_count, {name: user.name}.to_json)
    USER_PURCHASES_SUM.rank_member(  user.id.to_s,
      user.purchases_sum,   {name: user.name}.to_json)
    USER_PURCHASES_AVG.rank_member(  user.id.to_s,
      user.purchases_avg,   {name: user.name}.to_json)
  end
end
{% endhighlight %}

Data stored in Redis

{% highlight ruby %}
{"db":0,"key":"user_purchases_count","ttl":-1,"type":"zset",
  "value":[["id1",2.0],["id2",5.0],["id3",10.0]...]}
{"db":0,"key":"user_purchases_sum","ttl":-1,"type":"zset",
  "value":[["id2",57.0],["id1",65.0],["id3",101.0]...]}
{"db":0,"key":"user_purchases_avg","ttl":-1,"type":"zset",
  "value":[["id3",17.1],["id2",25.0],["id3",42.5]...]}
#
{"db":0,"key":"user_purchases_count:member_data","ttl":-1,"type":"hash",
  "value":{"id1":"{\"name\":\"user1@email.com\"}","id2":"{\"name\":\"user2@email.com\"}"}...}
{% endhighlight %}

In addition to leaderboard sorted set we are also using a hash to store related user attributes.  Leaderboard gem provides easy ways to access this data.  UI will be a little different this time:

{% highlight ruby %}
# app/views/pages/leaderboard/redis.html.erb
<h4><%= leaderboard.leaderboard_name %></h4>
<table class='table'>
  <thead>
    <th>User</th>
    <th>Rank</th>
    <th>Score</th>
  </thead>
  <% USER_PURCHASES_COUNT.all_leaders(with_member_data: true).each do |u| %>
    <tr>
      <% member_data = JSON.parse u[:member_data] %>
      <td><%= member_data['name'] %></td>
      <td><%= u[:rank] %></td>
      <td><%= u[:score] %></td>
    </tr>
  <% end %>
</table>
# repeat for 2 other leaderboards
{% endhighlight %}

### Load times

Let's create some test data:

{% highlight ruby %}
# db/seeds.rb
100.times do |i|
  u = User.create!(email: "user#{i}@email.com", password: 'password')
end
500.times do |i|
  Purchase.create!(amount: rand(10..100), user: User.all.sample)
end
{% endhighlight %}

As expected method calls is the slowest. It took over a second to load page with 100 users and fired over 500 DB queries.  Pre-generated data was fast at ~70 ms since it was only 1 query.  Redis leaderboard was also fast at ~70 ms and 0 queries against primary DB as all data was grabbed from Redis.  

So which approach is better?  That depends on a number of various, including how volatile is the data.  Redis leaderboard does introduce complexity but it will be faster.  Plus we might not want to persist data in our main DB.  

### Links

* [https://www.sitepoint.com/leaderboards-rails/](https://www.sitepoint.com/leaderboards-rails/)
* [http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WD9z0HUrJB0](http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WD9z0HUrJB0)
* [http://www.justinweiss.com/articles/how-should-my-rails-app-talk-to-redis/](http://www.justinweiss.com/articles/how-should-my-rails-app-talk-to-redis/)
* [https://github.com/redis/redis-rb/blob/master/lib/redis.rb](https://github.com/redis/redis-rb/blob/master/lib/redis.rb)
* [https://redis.io/commands/zrange](https://redis.io/commands/zrange)


{% highlight ruby %}

{% endhighlight %}
