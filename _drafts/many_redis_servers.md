---
title: "Many_redis_servers"
date: 2016-07-11
categories: redis
---

When you are just getting started with Redis you are probably going to setup one server (perhaps use the hosting service like RedisLabs and enable standby server for failover).

But as your data grows you might need to enable

Or you could have a situation where your background jobs are stored in Redis and also you cache is stored in Redis.  You don't care about loosing your cache but you want redundant servers for jobs.  Plus if you are caching lots of data that RAM will cost you.

So why not setup a singleton server for cache and redundant server for jobs and other important application data?