---
title: "Redis leaderboards"
date: 2017-01-10
categories: redis
---

In previous [post]({% post_url 2016-12-08-rails-leaderboard %}) I touched on using Redis for Leaderboard.  Let's expand on these ideas.  Recently at work we upgraded our fundraiser leaderboard and switched to use Redis as the data store with [Leaderboard](https://github.com/agoragames/leaderboard) gem.  

* TOC
{:toc}

Here are our requirements:

* Donors give Gifts to Fundraisers
* Fundraiser can belong to one or more Leaderboards.
* Leaderboard has a `metric` which is used to calculate the fundraiser (member) score and that determines the rank.  
* Store the history of rank changes and display up/down arrows in the UI as part of fundraiser info.
* Send alerts to donors when fundraisers to which they gave gifts drop by more than X positions in Y minutes (X and Y need to be configurable per leaderboard).  

#### Core models

Basic models with [Mongoid](https://docs.mongodb.com/ruby-driver/master/mongoid/#ruby-mongoid-tutorial).

{% highlight ruby %}
# app/models/*
class Gift
  belongs_to :donor
  belongs_to :fundraiser
end
class Donor
  has_many :gifts
end
class Fundraiser
  has_many :gifts
  has_and_belongs_to_many :fund_leaderboards
end
class FundLeaderboard
  has_and_belongs_to_many :fundraisers
  field :rank_drop_alert, type: Integer  # => number of place rank dropped
  field :rank_drop_alert_interval, type: Integer # => in minutes  
  field :metric, default: 'gifts_sum'
  extend Enumerize
  enumerize :metric, in: ['gifts_sum', 'gifts_count']
end
{% endhighlight %}

When gift is saved we fire a callback:

{% highlight ruby %}
class Gift
  after_save do update_leaderboard end
  after_destroy do update_leaderboard end
  def update_leaderboard
    LeaderboardSet.new(fundraiser: gift.fundraiser).perform
  end  
end
{% endhighlight %}

#### Leaderboard specific POROs

We can store these in `app/services/leaderboard/*`.  

Base class will establish Redis Leaderboard connection:

{% highlight ruby %}
class LeaderboardBase
  def initialize
    @ldbr = Leaderboard.new(nil)  
  end
end
{% endhighlight %}

`LeaderboardSet` class will be used to update data in Redis.  It expects a `Fundraiser` record.  We are using [Redis Sorted Set](https://redis.io/topics/data-types-intro#redis-sorted-sets), fundraiser IDs are members and we calculate `score` based on specified metric.  Separately `member_data` is stored in [Redis Hash](https://redis.io/topics/data-types-intro#redis-hashes).

{% highlight ruby %}
class LeaderboardSet
  def initialize fundraiser:
    @fundraiser = fundraiser
    super()
  end
  def perform
    member_data = {name: @fundraiser.name}.to_json
    @fundraiser.fund_leaderboards.each do |fund_ldbr|
      @ldbr.rank_member_in(fund_ldbr.id, @fundraiser.id,
        get_score(fund_ldbr.metric), member_data)
    end  
  end
private
  def get_score metric
    case metric
    when 'gifts_sum'
      @fundraiser.gifts.paid.sum(:amount)
     when 'gifts_count'
      @fundraiser.gifts.paid.count
     end
    end
end
# data in Redis
{"db":0,"key":"leaderboard_id1:","ttl":-1,"type":"zset","value":[["fund_id1",873.0],
  ["fund_id2",1305.0]]...}
{"db":0,"key":"leaderboard_id1:member_data","ttl":-1,"type":"hash","value":
  {"fund_id1":"{\"name\":\"fundraiser 1\"}","fund_id2":"{\"name\":\"fundraiser 2\"}"}...}
{% endhighlight %}

`LeaderboardGet` class will format data for UI presentation.  It will expect a `FundLeaderboard` record.  It also supports pagination and search.  There is a very interesting [RedisSearch](https://github.com/RedisLabsModules/RediSearch) module but we used [mongoid_search](https://github.com/mongoid/mongoid_search) gem.  We first need to query MongoDB to get fundraiser IDs and then hit Redis to get leaderboard data for those members.  `Page` and `page_size` can be passed from controller as parameters.

{% highlight ruby %}
class LeaderboardGet
  def initialize fund_leaderboard:, page: nil, page_size: nil, query: nil
    @fund_leaderboard = fund_leaderboard
    @page = page || 1
    @page_size = page_size || 25
    @query = query
    super()
  end
  def perform
    if @query.blank?
      data = get_leaders
    else
      data = get_ranked_in_list
    end
    format_data data
  end
private
  # by default will bring first 25
  def get_leaders
    options = {with_member_data: true, page_size: @page_size}
    data = @ldbr.leaders_in(, @page, options)
  end
  # get data for specific members based on query
  def get_ranked_in_list
    members = @fund_ldbr.fundraisers.full_text_search(@query).pluck(:id).map(&:to_s)
    options = {with_member_data: true, sort_by: :rank}
    @ldbr.ranked_in_list_in(@fund_leaderboard.id, members, options)
  end
  def format_data
    data.each do |hash|
      hash[:id] = hash.delete(:member)
      if hash[:member_data].present?
        member_data = JSON.parse(hash.delete(:member_data))
        hash[:name] = member_data['name']
      end
    end
    return data  
  end
end
# data output
{
  "id": "fund_id1",
  "rank": 1,
  "score": "873.00",
  "name": "fundraiser 1",
},
{% endhighlight %}

#### Rank history

So far we were using the common features present in [Leaderboard](https://github.com/agoragames/leaderboard) gem and we were able to meet the first two requirements of ranking members by different metric scores.  How can store the rank_history changes?  For that we wrote other methods utilizing [RedisObjects](https://github.com/nateware/redis-objects) gem (we could have used Redis API directly).  We create separate Sorted Set for each fundraiser where key = leaderboard member (fund_id), member = leaderboard rank and score = timestamp.  We also update the `member_data` hash with the new attribute `last_rank_change` and set TTL of 1 week for these separate Sorted Sets.  

{% highlight ruby %}
class LeaderboardSet < LeaderboardBase
  def perform
    @fundraiser.fund_leaderboards.each do |fund_ldbr|
      ...
      set_rank_history(fund_ldbr.id)
    end
  end
private
  def set_rank_history(leaderboard_name)
    all_leaders = @ldbr.all_leaders_from(leaderboard_name)
    all_leaders.each do |leader|
      key = ['rank_history', leader[:member]].join(':')
      member = leader[:rank]
      score = Time.now.to_f
      zset = Redis::SortedSet.new(key)
      zset[member] = score
      update_last_rank_change(leaderboard_name, leader[:member])
      zset.expire(1.week)
    end
  end
  # update member_data hash
  def update_last_rank_change(leaderboard_name, member)
    current_member_data = JSON.parse( @ldbr.member_data_for_in(leaderboard_name, member) )
    last_rank_change = {last_rank_change: get_last_rank_change(member)}
    new_member_data = current_member_data.merge(last_rank_change).to_json
    @ldbr.update_member_data_in(leaderboard_name, member, new_member_data)
  end
  # whether member moved up or down on last re-ranking
  def get_last_rank_change member
    key = ['rank_history', member].join(':')
    zset = Redis::SortedSet.new(key)
    rank_history = zset.members(with_scores: false).reverse
    if rank_history.first and rank_history.second
      if rank_history.first < rank_history.second
        return 'up'
      elsif rank_history.first > rank_history.second
        return 'down'
      else
        return ''
      end
    end
  end  
end
{% endhighlight %}

#### Sending alerts

To send alerts we create another class.  

{% highlight ruby %}
class LeaderboardSet < LeaderboardBase
  def perform
    @fundraiser.fund_leaderboards.each do |fund_ldbr|
      ...
      LeaderboardSendAlert.new(fund_ldbr).perform
    end
  end
end
class LeaderboardSendAlert < LeaderboardBase
  def initialize(fund_ldbr)
    @fund_ldbr = fund_ldbr
    super()
  end
  def perform
    all_members = @ldbr.all_members_from(@fund_ldbr.id, members_only: true)
      .map(&:values).flatten
    # loop through all rank_history zsets associated with the leaderboard
    all_members.each do |member|
      key = ['rank_history', member].join(':')
      zset = Redis::SortedSet.new(key)
      # => loop through members of each rank_history changes zset
      rank_history = zset.members(with_scores: true).reverse
      rank_alert = compare_rank_history(rank_history)
      send_alert(rank_alert, member) if rank_alert
    end
  end
private
  def compare_rank_history rank_history
    return if rank_history.size == 1
    # => grab first record and remove it from recordset
    recent_rank = rank_history.first
    rank_history.shift
    rank_history.each do |rh|
      # => compare rank drop to leaderboard config
      if recent_rank[0].to_i - rh[0].to_i >= @fun_ldbr.rank_drop_alert
        # => compare the time difference
        if recent_rank[1] - rh[1] > @fun_ldbr.rank_drop_alert_interval * 60 # in seconds
          return rh
        end
      end
    end
  end
  def send_alert rank_alert, member
    rank_drop_position = rank_alert[0]
    rank_drop_time = rank_alert[1]
    # => find donors who have gifts to this fundraiser since the time
    fund = Fundraiser.find(member)
    donor_ids = fund.gifts.gte(created_at: rank_drop_time).pluck(:id)
    # send alert
  end
end
{% endhighlight %}

#### Scalability

Time complexity of many [Redis Sorted Set](https://redis.io/commands#sorted_set) operations is usually `O(log(N))` so they get slower with more and more members.  One easy way to scale things is to create a simple background to use as a wrapper and call it from `Gift` model callback.  

{% highlight ruby %}
class UpdateLeaderboardJob < ApplicationJob
  def perform(fundraiser)
    LeaderboardSet.new(fundraiser: fundraiser).perform
  end
end
class Gift
  def update_leaderboard
    if fundraiser.fund_leaderboard_ids.count > 0
      UpdateLeaderboardJob.perform_later(fundraiser)
    end
  end  
end
{% endhighlight %}


On record change in callback do the leaderboard update via background job.  But we don't want to get into situation where multiple background jobs are queued up.  

Create separate Redis key in callback.  Run job every X minutes via cron and check if that key exists so the data needs to be recalculated.  

When job runs via cron first thing create separate Redis key and remove it when job completes.  This will ensure that job execution won't overlap if it takes longer to

When job runs via callback create Redis key with TTL of X minutes on completion.  Check for key's exists on job start.  This will ensure that job does not run too frequently.


{% highlight ruby %}

{% endhighlight %}



#### Namespacing keys



https://redis.io/topics/distlock



http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WHAK0fErLCJ



https://ruby-doc.org/stdlib-2.3.3/libdoc/set/rdoc/SortedSet.html
https://github.com/agoragames/leaderboard
https://github.com/nateware/redis-objects
https://github.com/redis/redis-rb
https://github.com/resque/redis-namespace

{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}
