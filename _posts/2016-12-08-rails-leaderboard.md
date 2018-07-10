---
title: "Rails leaderboards"
date: 2016-12-08
categories: rails redis
---

Leaderboard is a usefull way to show ranking of various records by specific criteria.  Let's imagine a system where Users have Purchases.  We want to display users by the following metrics:  number of purchases, total amount spent and average purchase amount.  

* TOC
{:toc}

### Object methods

First we will simply calculate these metrics live on each request.  To speed things up we will use [method caching](http://guides.rubyonrails.org/caching_with_rails.html#low-level-caching):

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
    Rails.cache.fetch([cache_key, __method__]) do
      purchases.count
    end
  end
  def get_purchases_sum
    Rails.cache.fetch([cache_key, __method__]) do
      purchases.sum(:amount)
    end
  end
  def get_purchases_avg
    return 0 if get_purchases_sum == 0
    get_purchases_count / get_purchases_sum
  end
end
{% endhighlight %}

Here is the UI:

{% highlight ruby %}
# app/controllers/leaderboard_controller.rb
def methods
  @users = User.all
end
# app/views/leaderboard/methods.html.erb
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

This approach is useful for grabbing data for one User record but leaderboard is slow due to numerous queries.  And there is no easy way to sort records w/o loading them all into the application.  

### Pre-generating data in the DB

We can use [counter_cache](http://guides.rubyonrails.org/association_basics.html) and custom callbacks from `Purchase` side to pre-generate summary data on `User` record in the DB.

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

We can now sort by either `purchases_count`, `purchases_avg` or `purchases_sum` and view records via `http://localhost:3000/leaderboard/db?order_by=purchases_count`

{% highlight ruby %}
# app/controllers/leaderboard_controller.rb
def db
  order_by = params[:order_by] || 'purchases_count'
  @users = User.all.order_by(:"#{order_by}" => 'desc')  
end
# app/views/leaderboard/db.html.erb
<table class='table'>
  ...
  <% rank = 1 %>  
  <% @users.each do |u| %>
    <tr>
      <td><%= rank %></td>
      <td><%= u.name %></td>
      <td><%= u.purchases_count %></td>
      <td><%= u.purchases_sum %></td>
      <td><%= u.purchases_avg %></td>
    </tr>
    <% rank += 1 %>
  <% end %>
</table>
{% endhighlight %}

To calculate the rank w/in that metric we can add simple counter to the view.  One downside is that we might need to filter users by separate query.  Than the rank will be only w/in the filtered records.  

A more complex option is to create a custom callback that in addition to `purchases_count`, `purchases_sum` and `purchases_avg` will calculate rank w/in those metric and persist data in DB.  But it will potentially need to update ALL user records on each purchase as the ranks might change in all metrics.

### Leaderboard gem

[leaderboard](https://github.com/agoragames/leaderboard) is an interesting gem that uses Redis [sorted sets](https://redis.io/topics/data-types#sorted-sets) to store data.  Storing data in RAM allows us to update it very quickly and Redis returns records in sorted order.  

{% highlight ruby %}
# config/initializers/redis.rb
USER_PURCHASES_COUNT = Leaderboard.new('user_purchases_count')
USER_PURCHASES_SUM = Leaderboard.new('user_purchases_sum')
USER_PURCHASES_AVG = Leaderboard.new('user_purchases_avg')
# app/models/user.rb
class User
  def update_leaderboard
    USER_PURCHASES_COUNT.rank_member(id.to_s, purchases_count,
      {name: name}.to_json)
    USER_PURCHASES_SUM.rank_member(  id.to_s, purchases_sum,   
      {name: name}.to_json)
    USER_PURCHASES_AVG.rank_member(  id.to_s, purchases_avg,   
      {name: name}.to_json)
  end
end
# app/models/purchase.rb
class Purchase
  ...
  after_save :update_user_stats
private
  def update_user_stats
    user.update_leaderboard
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
#  app/controllers/leaderboard_controller.rb
def redis
  if ['count', 'sum', 'avg'].include? params['leaderboard']
    lb_param = params['leaderboard']
  else
    lb_param = 'count'
  end
  @default_lb = "USER_PURCHASES_#{lb_param.upcase}".constantize
  @users = @default_lb.leaders(1, page_size: 10, with_member_data: true,
    members_only: true)
end
{% endhighlight %}

We can browse to `http://localhost:3000/leaderboard/redis1?leaderboard=avg` and display data by different criteria.  Leaderboard gem gives us `rank` and `score`.  We first grab membes from the default leaderboard that is determined via `leaderboard` param.  Then we use `score_and_rank_for` to grab data from different leaderboard sorted sets.  

{% highlight ruby %}
# app/views/leaderboard/redis.html.erb
<%= @default_lb.total_members %> records total
<table class='table'>
  <thead>
    <th>User</th>
    <th class='success'>Count Rank</th>
    <th class='success'>Count Score</th>
    <th class='info'>Sum Rank</th>
    <th class='info'>Sum Score</th>
    <th class='warning'>Avg Rank</th>
    <th class='warning'>Avg Score</th>
  </thead>
  <% @users.each do |u| %>
    <tr>
      <td><%= JSON.parse(u[:member_data])['name'] %></td>
      <% data_count = USER_PURCHASES_COUNT.score_and_rank_for(u[:member]) %>
      <td class='success'><%= data_count[:rank] %></td>
      <td class='success'><%= data_count[:score] %></td>
      <% data_sum = USER_PURCHASES_SUM.score_and_rank_for(u[:member]) %>
      <td class='info'><%= data_sum[:rank] %></td>
      <td class='info'><%= data_sum[:score] %></td>
      <% data_avg = USER_PURCHASES_AVG.score_and_rank_for(u[:member]) %>
      <td class='warning'><%= data_avg[:rank] %></td>
      <td class='warning'><%= data_avg[:score] %></td>
    </tr>
  <% end %>
</table>
{% endhighlight %}

#### Reds - main DB data sync

In Purchase model we have `after_save :update_user_stats` callback to create/update stats in Redis.  We need to also call it on 'after_destroy' so that user stats are updated if purchase is deleted.  

Separately we can create a feature to refresh all leaderboard data for all users and run it via `rails r User.update_all_leaderboards`.

{% highlight ruby %}
# app/models/user.rb
class User
  def self.update_all_leaderboards
    USER_PURCHASES_COUNT.delete_leaderboard
    USER_PURCHASES_AVG.delete_leaderboard
    USER_PURCHASES_SUM.delete_leaderboard
    User.each do |u|
      u.update_leaderboard
    end
  end
end
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

As expected method calls is the slowest. It took ~ 1.5 seconds to load page with 100 users and fired hundreds of DB queries.  Once the method calls are cached it loads in about 0.5 seconds.  

Pre-generated data was fast at ~70 ms since it was only 1 query.  

Redis leaderboard was also fast at ~70 ms and 0 queries against primary DB as all data was grabbed from Redis.  Load times for Redis leaderboard remain constant as we load more and more records.  

So which approach is better?  That depends on a number of various, including how volatile is the data.  Redis leaderboard does introduce complexity but it will be faster.  Plus we might not want to persist data in our main DB.  

### Links

* [https://www.sitepoint.com/leaderboards-rails/](https://www.sitepoint.com/leaderboards-rails/)
* [http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WD9z0HUrJB0](http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WD9z0HUrJB0)
* [http://www.justinweiss.com/articles/how-should-my-rails-app-talk-to-redis/](http://www.justinweiss.com/articles/how-should-my-rails-app-talk-to-redis/)
* [https://github.com/redis/redis-rb/blob/master/lib/redis.rb](https://github.com/redis/redis-rb/blob/master/lib/redis.rb)
* [https://redis.io/commands/zrange](https://redis.io/commands/zrange)


{% highlight ruby %}

{% endhighlight %}
