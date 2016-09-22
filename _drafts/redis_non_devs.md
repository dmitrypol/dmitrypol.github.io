---
title: "Redis for non developers"
date: 2016-07-20
categories: redis
---

Lots of software developers love Redis.  But developers are not the only technical users.  There are also lots of technical analysts.


### DBAs / SysAdmins

tools to backup/restore.  mongodump, mongorestore, mongoimport, mongoexport.

If Redis more than just cache store people need point in time data recovery, GUI to manage backup schedule and retention policy.


### Production Support Teams
Need tools to see what data is stored in Redis DB and potentially change this data outside of the main application.  I have had to write lots of UPDATE SQL scripts.  I am NOT advocating this style of softwware development but it's a reality in many organizations.


### Data Analysts

When I first started using Redis almost 5 years ago I loved the speed.  However the first question I encountered from our Data Analytics team was "how do I query this DB"?

read-only access to data


### Test / QA


### GUI Tools

https://github.com/ServiceStackApps/RedisReact

https://redisdesktop.com/

https://github.com/monterail/redis-browser

http://fastoredis.com/

https://github.com/steelThread/redmon

### Extract data into CSV

Redis data structures are very powerful but often people are accustomed to working with data in more Excel like format.


### Lua scripts

SQL stored procedures
