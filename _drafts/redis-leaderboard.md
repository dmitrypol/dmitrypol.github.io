---
title: "Redis leaderboards"
date: 2017-01-10
categories: redis
---

In previous [post]({% post_url 2016-12-08-rails-leaderboard %}) I touched on using Redis for Leaderboard.  Let's expand on these ideas.  Recently at work we upgraded our fundraiser leaderboard and switched to use Redis as the data store with [Leaderboard](https://github.com/agoragames/leaderboard) gem.  

* TOC
{:toc}

Here are our requirements:

* Fundraiser can belong to one or more Leaderboards.
* Leaderboard has a `metric` which is used to calculate the fundraiser (member) score and that determines the rank.  
* Store the history of rank changes and display up/down arrows in the UI as part of fundraiser info.
* Send notifications to donors when fundraisers to which they gave donatiosn drop by more than X positions in Y minutes (X and Y need to be configurable per leaderboard).  

#### Core models

Basic models with [Mongoid](https://docs.mongodb.com/ruby-driver/master/mongoid/#ruby-mongoid-tutorial).

{% highlight ruby %}
# app/models/*
class Donation
  belongs_to :donor
  belongs_to :fundraiser
end
class Donor
  has_many :donations
end
class Fundraiser
  has_many :donations
  has_and_belongs_to_many :fund_leaderboards
end
class FundLeaderboard
  has_and_belongs_to_many :fundraisers
  field :metric, default: 'donations_sum'
  extend Enumerize
  enumerize :metric, in: ['donations_sum', 'donations_count']
end
{% endhighlight %}

When donation is saved we fire a callback

{% highlight ruby %}
class Donation
  after_save do update_leaderboard end
  after_destroy do update_leaderboard end
  def update_leaderboard
    LeaderboardSet.new(fundraiser: donation.fundraiser).perform
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
    when 'donations_sum'
      @fundraiser.donations.paid.sum(:amount)
     when 'donations_count'
      @fundraiser.donations.paid.count
     end
    end
end
# data in Redis
{"db":0,"key":"leaderboard_id1:","ttl":-1,"type":"zset","value":[["fund_id1",873.0],
  ["fund_id2",1305.0]]...}
{"db":0,"key":"leaderboard_id1:member_data","ttl":-1,"type":"hash","value":
  {"fund_id1":"{\"name\":\"fundraiser 1\"}","fund_id2":"{\"name\":\"fundraiser 2\"}"}...}
{% endhighlight %}

`LeaderboardGet` will format data for UI presentation.  It will expect a `FundLeaderboard` record.  It also supports pagination and search.  There is a very interesting [RedisSearch](https://github.com/RedisLabsModules/RediSearch) module but we used [mongoid_search](https://github.com/mongoid/mongoid_search) gem.  The downside of this approach is that we first need to query MongoDB to get fundraiser IDs and then hit Redis for leaderboard data.  

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
  def get_leaders
    options = {with_member_data: true, page_size: @page_size}
    data = @ldbr.leaders_in(, @page, options)
  end
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
  "score": "1449.00",
  "name": "fundraiser 1",
},
{% endhighlight %}

#### Rank history

So far we were using the common features present in [Leaderboard](https://github.com/agoragames/leaderboard) gem and we were able to meet the first two requirements of ranking members by different metric scores.  How can store the rank_history changes?  For that we wrote our own code using [RedisObjects](https://github.com/nateware/redis-objects) gem (we could have used Redis API with plain driver).  We created separate Sorted Sets where key = leaderboard member (fund_id), member = leaderboard rank and score = timestamp.  We also update the `member_data` hash with the new attribute `last_rank_change` and set TTL of 1 week for these separate Sorted Sets.  

{% highlight ruby %}
class LeaderboardSet < LeaderboardBase
  def perform
    member_data = {name: @fundraiser.name}.to_json
    @fundraiser.fund_leaderboards.each do |fund_ldbr|
      @ldbr.rank_member_in(fund_ldbr.id, @fundraiser.id,
        get_score(fund_ldbr.metric), member_data)
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

#### Sending notifications





#### Background job

All these calculations can be slow even with Redis's speed.  Time complexity of Sorted Set operations.  

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
