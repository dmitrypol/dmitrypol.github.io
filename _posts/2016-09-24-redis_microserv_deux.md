---
title: "Redis and async microservices - part deux"
date: 2016-09-24
categories: redis sidekiq
---

I previously wrote about [Microservices with Sidekiq]({% post_url 2016-02-02-microservices %}) and [Redis and async microservices]({% post_url 2016-09-07-redis_microserv %}).  In this post I will continue expanding on those ideas.  

I spent a number of years working in internet advertising and will use relevant examples from my past experience (appropriately abstracted into more general use cases).  A large scale ad platform can serve billions of ads and process millions of clicks per day.  You need to be able to quickly cap accounts as they run out of budget.  When end user clicks on the ad the request goes to the click server which records the click and forwards end user to the destination.  

You also need UI to manage ads.  Typical ad will contain the following attributes: CPC (cost per click), budget, title, body and link to the destination site.  For each click you usually track IP, User Agent, URL of the page where click took place and when it happened.  

Separately you track impressions but you can aggregate data by hour to see how often the ad was shown in that period of time.  Recoding each impression will put significant load on your DB.  It also can be useful to aggregate which keywords you are getting ad requests for.  All this information helps you analyze ad performance.  To demo these concepts I built a [sample app](https://github.com/dmitrypol/redis_adsystem).  

* TOC
{:toc}

### UI

It is build on top of [Rails 5](http://weblog.rubyonrails.org/2016/6/30/Rails-5-0-final/) with SQL DB and [RailsAdmin](https://github.com/sferik/rails_admin) CRUD dashboard so you can view the `Ads`, `Clicks` and `Impressions` tables at `http://localhost:3000/admin`.  After cloning the repo you need to `cd ui && bundle && rake db:seed && rails s -p 3001`.  You can then login with `admin@email.com / password`.  

The basic models are:
{% highlight ruby %}
class Ad < ApplicationRecord
  has_many :clicks
  has_many :impressions
end
class Click < ApplicationRecord
  # records every click
  belongs_to :ad
  validates :ad, presence: true
end
class Impression < ApplicationRecord
  # records impressions counter for ad, date and hour
  belongs_to :ad
  validates :ad, presence: true
end
{% endhighlight %}

### Ad Server

It is built using [Rails 5 API](http://edgeguides.rubyonrails.org/api_app.html) and only talks to Redis (not SQL DB).  After cloning the repo you need to `cd adserver && bundle && rails s`.  To keep controller light we move the logic into `GetAds` service object.

{% highlight ruby %}
# app/controllers/ad_controller.rb
class AdController < ApplicationController
  def index
    ad_params = request.params.except(:controller, :action)
    ads = GetAds.new(keyword: ad_params[:kw]).perform
    render json: ads
  end
end
# config/initializers/redis.rb
redis_conn = Redis.new(host: Rails.application.config.redis_host, port: 6379, db: 0, driver: :hiredis)
# I prefer using namespaces to separate Redis keys
REDIS_ADS =  Redis::Namespace.new('ads', redis: redis_conn)
# app/services/get_ads.rb
class GetAds
  # you will see later why @keyword and @ads are instance variables
  def initialize(keyword:)
    @keyword = keyword
  end
  def perform
    @ads = REDIS_ADS.smembers @keyword
    return @ads
  end
end
{% endhighlight %}

Ads are stored in [Redis SET](http://redis.io/commands/smembers) with `keyword` as key and various ads as SET members.  When you browse to `http://localhost:3000/?kw=keyword1` Ad controller will respond with JSON:

{% highlight ruby %}
[
"{"ad_id":11,"title":"title 1","body":"body 1","cpc":4,
"link":"http://localhost:3000/click?ad_id=11&url=aHR0cDovL3dlYnNpdGU3LmNvbQ}",
...
]
{% endhighlight %}
`url` param in `link` is a simple Base64 encoding of the destination URL for that ad.  

### Ads Cache

Redis is a great cache for storing ads.  To populate it we utilize a callback in UI app Ad model.  

{% highlight ruby %}
class Ad < ApplicationRecord
  after_save :update_ads_cache
private
  def update_ads_cache
    # => check if any important attributes changed
    if keywords_changed? or cpc_changed? or budget_changed?
      or title_changed? or body_changed? or link_changed?  
      # keywords are comma separated strings
      keywords.split(',').each do |kw|
        REDIS_ADS.pipelined do
          REDIS_ADS.srem  kw, ad_content  # => remove ad
          # => insert ad if there is budget
          REDIS_ADS.sadd  kw, ad_content if budget > 0
        end
      end
    end
  end
  def ad_content
    # => encode link into redirect URL
    {ad_id: id, title: title, body: body, cpc: cpc, link: redirect_url}.to_json
  end
  def redirect_url
    query = { ad_id: id, url: Base64.encode64(link) }.to_query
    "http://localhost:3000/click?#{query}"
  end
end
{% endhighlight %}

`REDIS_ADS.sadd` and `REDIS_ADS.srem` will add / remove appropriate ads.  SETS allow us to have max 4294967295 ads per keyword and time complexity for SADD is O(N).

### Click Processing

When end user clicks the link `http://localhost:3000/click?ad_id=88&url=aHR0cDovL3dlYnNpdGU3LmNvbQ` the request is routed to Click controller (part of Adserver but could be inside UI or a separate app).

{% highlight ruby %}
class ClickController < ApplicationController
  def index
    ProcessClickJob.perform_later({ad_id: request.params[:ad_id]})
    redirect_url = Base64.decode64(request.params[:url])
    redirect_to redirect_url
  end
end
class ProcessClickJob < ApplicationJob
  queue_as :click
  def perform(ad_id:)
    # simply queue the job
  end
end
{% endhighlight %}

Notice the special `click` queue which you can set to high priority in [Sidekiq](https://github.com/mperham/sidekiq).  Queueing the job with Redis/Sidekiq is very fast.  To actually process the click we have `ProcessClickJob` in UI app  In true microservice architecture it could be a separate application.  This records the click and decrements ad budget (which triggers `update_ads_cache`).

{% highlight ruby %}
class ProcessClickJob < ApplicationJob
  queue_as :click
  def perform(*args)
    ad_id = args.first[:ad_id].to_i
    ad = Ad.find(ad_id)
    # decrement ad budget
    ad.update(budget: ad.budget - ad.cpc)
    # record the click
    ad.clicks.create
  end
end
{% endhighlight %}

### Data storage in Redis

So now we have seen how data flows between UI and Ad Server via Redis.  From UI there is a direct access to Redis API via model callback.  From Ad Server a Sidekiq background job is queued.  But we also want to aggregate stats on how many impressions we served and which keywords are getting requests.  How can Redis help us with that?  

#### Temporary data storage

We add a method to `GetAds` class in AdServer.  It loops through `@ads` and increments Redis counters that look like this `AD_ID:20160922:HOUR`.  Redis helps us count impressions with minimum impact to ad serving.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_IMPR = Redis::Namespace.new('impr', redis: redis_conn)
# app/services/get_ads.rb
class GetAds
  def perform
    @ads = REDIS_ADS.smembers @keyword
    record_impressions
    return @ads
  end
private
  # keep track of number of impressions for each by hour.  Data gets moved into main DB
  def record_impressions
    # => current date and hour
    date_hour = Time.now.strftime("%Y%m%d:%H")
    @ads.each do |ad|
      # => grab ad_id from each JSON
      ad2 = JSON.parse(ad)
      ad_id = ad2['ad_id']
      key = [ad_id, date_hour].join(':')
      REDIS_IMPR.incr key
    end
  end
end
{% endhighlight %}

Inside UI app we create an hourly job.  It will move data from temporary Redis storage into permanent SQL DB Impressions table.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_IMPR = Redis::Namespace.new('impr', redis: redis_conn)
# app/jobs/process_impression_job.rb
class ProcessImpressionJob < ApplicationJob
  queue_as :low
  def perform
    REDIS_IMPR.keys.each do |key|
      counter = REDIS_IMPR.get(key)
      # split 459:20160922:17  ad_id:date:hour
      key2 = key.split(':')
      ad_id = key2[0]
      date = key2[1]
      hour = key2[2]
      ad = Ad.find(ad_id)
      # => create impression record in main DB
      ad.impressions.create(date: date, hour: hour, counter: counter)
      REDIS_IMPR.del(key) # => delete the key
    end
  end
end
{% endhighlight %}

#### Permanent data storage

But we also want to track which keywords are getting requested at least once an hour.  We add another method to `GetAds`.  This time the key is keyword and value is the counter.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_KW = Redis::Namespace.new('kw', redis: redis_conn)
# app/services/get_ads.rb
class GetAds
  def perform
    @ads = REDIS_ADS.smembers @keyword
    record_impressions
    record_keyword
    return @ads  
  end
private
  # keep track which keywords get requested at least once a week, data remains in Redis
  def record_keyword
    REDIS_KW.pipelined do
      REDIS_KW.incr @keyword
      REDIS_KW.expire @keyword, 1.week.to_i
    end
  end
end
{% endhighlight %}

By re-setting TTL on every request Redis will automatically purge keywords that get requested infrequently or seasonally.  To display this data in our UI we built a simple page with you can see at `http://localhost:3001/admin/keywords` (ui\app\views\rails_admin\main\keywords.html.erb)

{% highlight ruby %}
<% REDIS_KW.keys.each do |keyword| %>
  <tr>
    <td><%= keyword %></td>
    <td><%= REDIS_KW.get keyword %></td>
  </tr>
<% end %>
{% endhighlight %}

But there is an obvious downside is that you cannot sort these records by value so we cannot see which keywords are requested more often.  For that we need to build a Redis secondary index.  I will cover that in a different blog post.  

### Testing

Previously I have written about [testing your code with Redis]({% post_url 2016-06-08-redis_tests %}).  You can either setup real Redis instance or use [mock_redis](https://github.com/brigade/mock_redis) gem.  

{% highlight ruby %}
# config/initializers/redis.rb
if Rails.env.test?
  REDIS_ADS =  Redis::Namespace.new('ads', redis: MockRedis.new )
  ...
else
  # real Redis connections here
end
# spec/rails_helper.rb
require 'mock_redis'
...
config.before(:each) do
  # data is not saved into real Redis but you still need to clear it
  REDIS_ADS.flushdb
end
{% endhighlight %}

Then in your tests for `ProcessImpressionJob` you can setup data with `REDIS_IMPR.incrby(keyword, 10)` and in tests for `GetAds` check `expect(REDIS_IMPR.keys).to eq ...`

Since there are no live HTTP calls between your microservices you do not need to use gems like [webmock](https://github.com/bblimke/webmock), [VCR](https://github.com/vcr/vcr) or [discoball](https://github.com/thoughtbot/capybara_discoball).  For real production system I would still recommend a good overall integration test pass.  But as long as you define message format for how data flows between your applications via Redis you can stub and test components separately.  


{% highlight ruby %}

{% endhighlight %}
