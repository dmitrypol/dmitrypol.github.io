---
title: "Redis NFL Leaderboard"
date: 2017-03-05
categories: redis
---

In a previous [post]({% post_url 2016-12-08-rails-leaderboard %}) I discussed using Redis for Leaderboards.  Let's expand on these ideas.  Recently at work we upgraded our fundraiser leaderboard and switched to use Redis as the data store with [leaderboard](https://github.com/agoragames/leaderboard) gem.

But fundraising is not nearly as fun as football.  My young son is a big fan of Seattle Seahawks so to explain to him what I do at work we built an NFL Leaderboard together.  We made a great team because he knows football and I know coding.

* TOC
{:toc}

#### Core models

Basic models with [Mongoid](https://docs.mongodb.com/ruby-driver/master/mongoid/#ruby-mongoid-tutorial).

{% highlight ruby %}
# app/models/*
class Division
  field :conference
  field :title
  has_many :teams
end
class Team
  field :name
  has_many :away_games, class_name: 'Game', inverse_of: :away_team
  has_many :home_games, class_name: 'Game', inverse_of: :home_team
  has_many :scores
  belongs_to :division
end
class Game
  belongs_to :home_team, class_name: 'Team', inverse_of: :home_games
  belongs_to :away_team, class_name: 'Team', inverse_of: :away_games
  has_many :scores
end
class Score
  belongs_to :game
  belongs_to :team
end
{% endhighlight %}

We wanted to make the leaderboard more sophisticated so we created `LeaderboardGroup` which has `has_and_belongs_to_many` relationship to `Team`.  This way many teams can complete in different groupings.  

{% highlight ruby %}
class LeaderboardGroup
  field :name
  has_and_belongs_to_many :teams
end
class Team
  has_and_belongs_to_many :leaderboard_groups
end
{% endhighlight %}

Then we created a simple callback from the `Score` model:

{% highlight ruby %}
class Score
...
  after_create  do
    LeaderboardSet.new(self).perform
  end
end
{% endhighlight %}

#### Leaderboard specific Ruby classes

To encapsulate logic for accessing data in [Redis Sorted Sets](https://redis.io/topics/data-types#sorted-sets) we created two Ruby classes (`LeaderboardGet` and `LeaderboardSet`) to wrap around `leaderboard` gem (but we could have talked to Redis API directly).

{% highlight ruby %}
# config/initializers/redis.rb
NFL_LDBR = Leaderboard.new
# app/services/leaderboard_set.rb
class LeaderboardSet
  def initialize score
    @member = score.team.id
    @score = score.team.total_points
    @leaderboard_groups = score.team.leaderboard_groups
  end
  def perform
    # loop through all groups
    @leaderboard_groups.each do |leaderboard_group|
      process_leaderboard(leaderboard_group)
    end
  end
private
  def process_leaderboard leaderboard_group
    leaderboard_name = leaderboard_group.id
    NFL_LDBR.rank_member_in(leaderboard_name, @member, @score)
  end
end
{% endhighlight %}

`team.total_points` is a method to get sum of all points for different scores (touchdowns, field goals, etc).  `rank_member_in` is a method provided by the leaderboard gem.  

Data in Redis looks like this:

{% highlight ruby %}
{"db":0,"key":"leaderboard_id1:","ttl":-1,"type":"zset","value":
  [["team1_id",14.0], ["team2_id",6.0]]...}
{% endhighlight %}

`LeaderboardGet` class uses `all_members_from` method from `leaderboard` gem to extract data from Redis for JSON API output which looks like this:  `{ rank: 1, score: 14, id: "team1_id", }, ...`

{% highlight ruby %}
class LeaderboardGet
  def initialize leaderboard_name: nil
    @leaderboard_name = leaderboard_name
  end
  def perform
    teams = NFL_LDBR.all_members_from(@leaderboard_name, with_member_data: true)
  end
end
{% endhighlight %}

#### Additonal team data

But all we have are team IDs which are not very useful for display.  How can we get additonal information such as team names, logos, descriptions w/o having to query our primary DB?  That data can be stored in Redis [hashes](https://redis.io/topics/data-types-intro#hashes).  Fortunately the `leaderboard` gem provides useful abstraction but underneath it are just regular Redis API calls.  

{% highlight ruby %}
class LeaderboardSet
...
private
  def process_leaderboard leaderboard_group
    leaderboard_name = leaderboard_group.id
    member_data = {name: team.name}
    NFL_LDBR.rank_member_in(leaderboard_name, @member, @score, member_data)
  end
end
class LeaderboardGet
...
  def perform
    teams = NFL_LDBR.all_members_from(@leaderboard_name, with_member_data: true)
    teams.each do |hash|
      # format data
      if hash[:member_data].present?
        member_data = JSON.parse(hash.delete(:member_data))
        hash[:name] = member_data['name']
      end
    end
    return teams
  end
end
{% endhighlight %}

Here we are adding just team names but same approach can be used for other attributes.

Redis hashes use team ID for the key and value is JSON encoded string of attributes.  `{"db":0,"key":"leaderboard:nfl-ldbr:member_data","ttl":-1,"type":"hash","value":{"team1_id":"{\"name\":\"washington-redskins\"}","team2_id":"{\"name\":\"arizona-cardinals\"}",...}`

And JSON output looks like this `{ rank: 1, score: 14, id: "team1_id", name: "Arizona Cardinals"},...`

#### Storing even more data in Redis

To make our Leaderboard even more interesting we wanted to keep the history of how the team rankings move up or down.  So how can we store this data in Redis?  

We decided to use different Sorted Sets (one for each team) where the key would use team ID with `rank_history` appended to it.  Members would be the positions in which the team was and scores would be times when team was in that position.  This will give use chronologically sorted history of rank changes.  

More updates to `LeaderboardGet` and `LeaderboardSet`

{% highlight ruby %}
class LeaderboardSet
  def process_leaderboard leaderboard_group
    ...
    NFL_LDBR.rank_member_in(leaderboard_name, @member, @score, member_data)
    set_rank_history leaderboard_name
  end
  def set_rank_history leaderboard_name
    # => loop through all members in leaderboard set
    all_leaders = NFL_LDBR.all_leaders_from(leaderboard_name, members_only: false)
    all_leaders.each do |leader|
      # create separate SortedSet record where key = leaderboard_name + member
      # member = leaderboard rank, score = timestamp
      rank_history_zset = [leaderboard_name, leader[:member], 'rank_history'].join(':')
      member = leader[:rank]
      score = Time.now.to_f
      NFL_LDBR.rank_member_in(rank_history_zset, member, score)
      update_last_rank_change(leader[:member], leaderboard_name)
    end
  end
  def update_last_rank_change(member, leaderboard_name)
    last_rank_change = {last_rank_change:
      get_last_rank_change(member, leaderboard_name)}.to_json
    NFL_LDBR.update_member_data_in(leaderboard_name, member, last_rank_change)
  end
  # whether member moved up or down on last re-ranking in specific leaderboard
  def get_last_rank_change member, leaderboard_name
    rank_history_zset = [leaderboard_name, member, 'rank_history'].join(':')
    rank_history = NFL_LDBR.all_members_from(rank_history_zset,
      members_only: true).map(&:values).flatten
    if rank_history.first and rank_history.second
      if rank_history.first.to_i < rank_history.second.to_i
        return 'up'
      elsif rank_history.first.to_i > rank_history.second.to_i
        return 'down'
      else
        return ''
      end
    end
  end
end
{% endhighlight %}

These new data structures will look like this `{"db":0,"key":"leaderboard:nfl-ldbr:team1_id:rank_history","ttl":-1,"type":"zset","value":[["7",1488739923.3964453],["8",1488739934.261501],["9",1488739939.2733278],["10",1488739942.9806864],["11",1488739944.2791183]],"size":96}`

At the end of the `set_rank_history` we fire `update_last_rank_change` to update the Hash of team meta-data.  So in the `LeaderboardGet` we just need to format it properly for output.  Now the combined API output looks like this `{ rank: 1, score: 14, id: "team1_id", name: "Arizona Cardinals", last_rank_change: "up" }, ...`

#### Storing total_points counter in Redis

But we were not done.  Since the scores were changing so fast we did not want to query the primary DB to calculate `total_points` every time.  We wanted to keep a counter in Redis during this time of high data volatility.  [redis-objects](https://github.com/nateware/redis-objects) enables us to easily create methods on `Team` model for such purpose.

{% highlight ruby %}
class Team
  ...
  include Redis::Objects
  counter :redis_total_points
  # => permanently store total_points after the games are over
  field :perm_total_points
  def total_points
    redis_total_points.value || perm_total_points
  end
end
{% endhighlight %}

We fire `incr` and `decr` calls when scores are created or destroyed right before we call `LeaderboardSet`.

{% highlight ruby %}
class Score
  ...
  after_create  do update_redis('create')  end
  after_destroy do update_redis('destroy')  end
  def update_redis action
    if action == 'create'
      team.redis_total_points.incr(score_points)
    elsif action == 'destroy'
      team.redis_total_points.decr(score_points)
    end
    LeaderboardSet.new(self).perform
  end
end
{% endhighlight %}

Data is stored like this `{"db":0,"key":"team:team1_id:redis_total_points","ttl":-1,"type":"string","value":"14","size":1}`.  RedisObjects creates a key based on model name, record ID and method name.  

But you may be wondering what is `perm_total_points`?  We liked storing data in Redis when it was rapidly changing but we also wanted to preserve it in the main DB once the games were over.  So we created another Ruby class to move the attributes.  

{% highlight ruby %}
class RedisSync
  # => move data from Redis to main DB
  def sync_total_points
    Team.all.each do |team|
      current_value = team.redis_total_points.value
      team.update(perm_total_points: current_value)
      team.redis_total_points.decrement(current_value)
    end
  end
end
{% endhighlight %}

Main appliation code simply uses `team.total_points` method and the data is returned from either DB.  

#### Resetting data in the leaderboard

But what if something happens to the data in Redis or there is a bug in our code?  We need to have a way recreate these Sorted Sets and Hashes.  For that we created `LeaderboardReset` class.  

{% highlight ruby %}
class LeaderboardReset
  def reset_all_stats
    LeaderboardGroup.all.no_timeout.each do |leaderboard_group|
      reset_stats leaderboard_group
    end
  end
  def reset_stats leaderboard_group
    delete_stats leaderboard_group
    leaderboard_group.teams.no_timeout.each do |team|
      LeaderboardSet.new(team.scores.last).perform
    end
  end
  def delete_all_stats
    LeaderboardGroup.all.no_timeout.each do |leaderboard_group|
      delete_stats leaderboard_group
    end
  end
  def delete_stats leaderboard_group
    NFL_LDBR.delete_leaderboard_named leaderboard_group.id
  end
end
{% endhighlight %}

These methods can be called from an internal dashboard or CLI when necessary.  

#### Background job to simulate games

To make the demo exciting we built a simple UI using [ReactJS](https://facebook.github.io/react/tutorial/tutorial.html) with [react-refetch](https://github.com/heroku/react-refetch) and [react-flip-move](https://github.com/joshwcomeau/react-flip-move).  

We also created a background job to create fake games and scores.  It runs for 1 minute pausing 1 second between each score and all teams are playing at the same time.  

{% highlight ruby %}
class ScoresJob < ApplicationJob
  before_perform do
    remove_previous_data
    create_games
  end
  after_perform do
    RedisSync.new.sync_total_points
  end
  def perform
    60.times do |i|
      create_score
      sleep 1
    end
  end
private
  def remove_previous_data
    ...
  end
  def create_games
    ...
  end
  def create_score
    ...
  end

end
{% endhighlight %}

You can view the leaderboard at [https://nfl-leaderboard.herokuapp.com/](https://nfl-leaderboard.herokuapp.com/) and play a few games if you want.  

#### Links

* [https://github.com/agoragames/leaderboard](https://github.com/agoragames/leaderboard)
* [https://github.com/nateware/redis-objects](https://github.com/nateware/redis-objects)
* [https://github.com/redis/redis-rb](https://github.com/redis/redis-rb)
* [https://github.com/resque/redis-namespace](https://github.com/resque/redis-namespace)
* [https://ruby-doc.org/stdlib-2.3.3/libdoc/set/rdoc/SortedSet.html](https://ruby-doc.org/stdlib-2.3.3/libdoc/set/rdoc/SortedSet.html)
* [http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html](http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html)
* [https://redis.io/topics/distlock](https://redis.io/topics/distlock)


{% highlight ruby %}

{% endhighlight %}
