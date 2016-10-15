---
title: "Redis and Rails Admin"
date: 2016-10-15
categories: redis
---

[Redis](http://redis.io/) can be a great DB for caching and temp data storage.  [rails_admin](https://github.com/sferik/rails_admin) is a useful gem for generating CRUD admin interfaces.  It works very well with [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) and [Mongoid](https://github.com/mongodb/mongoid).  But what if we need to do CRUD operations on data in Redis?  

[Redis-browser](https://github.com/humante/redis-browser) allows us to view and delete records in Redis but it's a separate [Sinatra](http://www.sinatrarb.com/) app.  I have blogged about configuring [redis-browser]({% post_url 2015-10-15-redis-rails-tips %}) and creating [custom pages]({% post_url 2015-09-10-rails-admin %}) in RailsAdmin.

Let's explore how can we build a real CRUD dashboard for Redis data in RailsAdmin.  

https://github.com/soveran/ohm
