---
title: "Redis leaderboards"
date: 2017-01-06
categories: redis
---

In a previous http://dmitrypol.github.io/rails/redis/2016/12/08/rails-leaderboard.html post I touched on using Redis for Leaderboard.  I want to expand on it.  


https://github.com/agoragames/leaderboard



#### Rank change history

Separate rank_history sorted set where member is current rank and score is Time
Store last_rank_change in member_data hash.  
TTL of 1 week on every change.  

Use score changes to send notifications to users when their team changes X positions in rank.


#### Background job

All these calculations can be slow even with Redis's speed.  Time complexity of Sorted Set operations.  

On record change in callback do the leaderboard update via background job.  But we don't want to get into situation where multiple background jobs are queued up.  

Create separate Redis key in callback.  Run job every X minutes via cron and check if that key exists so the data needs to be recalculated.  

When job runs via cron first thing create separate Redis key and remove it when job completes.  This will ensure that job execution won't overlap if it takes longer to

When job runs via callback create Redis key with TTL of X minutes on completion.  Check for key's exists on job start.  This will ensure that job does not run too frequently.



#### Namespacing keys



https://redis.io/topics/distlock



http://www.nateware.com/real-time-leaderboards-with-elasticache-and-redis-objects.html#.WHAK0fErLCJ
