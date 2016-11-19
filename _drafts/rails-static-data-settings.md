---
title: "Rails static data and system settings"
date: 2016-11-18
categories: rails redis
---

Usually application data is stored in the DB.  We use controllers and models to read and write it.  But sometimes that data is static (system settings, list of countries, etc) so it does not make sense to put it in DB.  Plus storing data in file(s) guarantees that when we deploy the application, the data will be there.  Otherwise we have enter it manually via UI or load via SQL script.

* TOC
{:toc}

### System settings

There are several gems our there such as [rails-settings](https://github.com/ledermann/rails-settings) and [config](https://github.com/railsconfig/config).  Usually I am big fan of using robust libraries instead of implementing complex functionality myself.  But when the need is simple it can be better to create few config files / POROs to do exactly what we need.  

Let's imagine a CMS where users belong to various roles (admin, editor, author).  We could create `Role` model/table and have `UserRole` mapping.  Or we can store config values in `application.rb` and have `User.roles` array.

{% highlight ruby %}
# config/application.rb
class Application < Rails::Application
  ...
  config.roles = [:admin, :editor, :author]
end
# app/models/user.rb
class User
  ...
  extend Enumerize
  field :roles, type: Array
  enumerize :roles, in: Rails.application.config.roles, multiple: true
end
{% endhighlight %}

But with time `application.rb` gets bigger and harder to manage.  Why not create a custom initializer?  

{% highlight ruby %}
# config/initializers/system_settings.rb
CMS_ROLES = [:admin, :editor, :author]
class User
  enumerize :roles, in: CMS_ROLES
end
{% endhighlight %}

`CMS_ROLES` is a [constant](http://guides.rubyonrails.org/autoloading_and_reloading_constants.html) so want to give it descriptive name or namespace it.

### Static data

What if the amount of data is much larger than a few strings?  We might need to store the list of US states, zipcodes, countries, etc.  Why not create `data` folder in application root?  We can put CSV, TXT, JSON, XML or YML files in appropriate subfolder structure.

{% highlight ruby %}
# data/us_states.txt
Alabama
Alaska
...
# config/initializers/system_settings.rb
STATES_PROVINCES = File.readlines('data/us_states.txt').map {|line| line.strip}
# app/models/user.rb
class User
  extend Enumerize
  field :region
  enumerize :region, in: STATES_PROVINCES
end
{% endhighlight %}

### Sharing data across multiple applications

Config values migth need to be shared by several applications running on separate servers.  But we do not want to store the same data files in multiple applications because they can get out of sync.  We want a canonical source that gets refreshed everytime we deploy the main app.  We could use [Redis](http://redis.io/) as a shared cache storage.  

{% highlight ruby %}
# config/initializers/redis.rb
redis = Redis.new(host: 'localhost', port: 6379, db: 0)
REDIS_SETTINGS = Redis::Namespace.new(:sys_set, redis: redis)
# config/initializers/system_settings.rb
sp_data = File.readlines('data/us_states.txt').map {|line| line.strip}
# remove current cache
REDIS_SETTINGS.del('states_provinces_data')
# cache new data in Redis SET with descriptive key
REDIS_SETTINGS.sadd('states_provinces_data', sp_data)
# read it into constant so app retains data if cache is lost
STATES_PROVINCES = REDIS_SETTINGS.smembers('states_provinces_data')
{% endhighlight %}

Now all we have do do in the other applications is connect to Redis and read data.  

{% highlight ruby %}
# config/initializers/redis.rb
redis = Redis.new(host: 'localhost', port: 6379, db: 0)
REDIS_SETTINGS = Redis::Namespace.new(:sys_set, redis: redis)
# config/initializers/system_settings.rb
STATES_PROVINCES = REDIS_SETTINGS.smembers('states_provinces_data')
{% endhighlight %}

Depending on the type of data that needs to be cached in Redis we might use different [data types](http://redis.io/topics/data-types).  To store array of US states we used [Redis SET](http://redis.io/topics/data-types#sets) with [SADD](http://redis.io/commands/sadd) and [SMEMBERS](http://redis.io/commands/smembers) commands.  Other data might be better stored in Redis hashes, lists or strings.  
