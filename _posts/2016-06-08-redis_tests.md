---
title: "Redis and testing your code"
date: 2016-06-08
categories: redis test
---

In previous posts I blogged about using Redis to store data.  The question is how to test the code that leverages this data?

When your Rails tests use records from the main DB (MySQL, PG, Mongo) you can use gems like [FactoryGirl](https://github.com/thoughtbot/factory_girl) and [DatabaseCleaner](https://github.com/DatabaseCleaner/database_cleaner) to get data into the right state for your tests.  How do you do the same with Redis?

I am using [mock_redis](https://github.com/brigade/mock_redis) gem which helps avoid having Redis instance up just to run tests (makes it easier to run tests via [Travis CI](https://travis-ci.com/) or [CodeShip](https://codeship.com/)).

Configure Redis connection in config/initializers/redis.rb
{% highlight ruby %}
unless Rails.env.test?
  REDIS = Redis::Namespace.new(:my_namespace,
  redis: Redis.new(host: Rails.application.config.redis_host, port: 6379, db: 0) )
else
  REDIS = Redis::Namespace.new(:my_namespace, redis: MockRedis.new )
end
{% endhighlight %}

In spec/rails_helper.rb
{% highlight ruby %}
# add this at the top
require 'mock_redis'
  ...
  config.before(:each) do
    # data is not saved into real Redis but you still need to clear it
    REDIS.flushdb
  end
  ...
{% endhighlight %}

Here we have app/services/redis_service_object.rb that returns values of all keys in Redis.
{% highlight ruby %}
class RedisServiceObject
  def perform
    output = []
    REDIS.keys.each do |key|
      # assumes you are only storing strings
      output << REDIS.get key
    end
    return output
  end
end
{% endhighlight %}

In spec/services/redis_service_object_spec.rb
{% highlight ruby %}
require 'rails_helper'
describe RedisServiceObject, type: :service do
  before(:each) do
    # setup your data here
    REDIS.set 'key1', 'value1'
    REDIS.set 'key2', 'value2'
  end
  it 'valid test' do
    # use contain_exactly instead of eq because keys can be returned in different order
    expect(RedisServiceObject.perform).to contain_exactly('value1', 'value2')
  end
end
{% endhighlight %}
This solution works well when you have a few objects accessing data in Redis and you can just create the data in your tests.  This approach is not very DRY if you have lots of code that needs to be tested.  In that case you could create separate class(es) somewhere in spec/factories and call them from your test like any other Ruby class.

With mock_redis test data is never actually persisted into Redis.  If that is not sufficient then instead of configuring MockReids in initializer you can use the real Redis connection (and have Redis server running).  You could separate environment specific data by using different Redis DBs and/or namespaces.

There is also [fakeredis](https://github.com/guilleiguaran/fakeredis) gem but I could not make it work with latest Rspec, Rails and Redis.  If someone knows how to use it, please leave a comment.