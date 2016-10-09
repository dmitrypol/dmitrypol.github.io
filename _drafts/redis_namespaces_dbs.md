---
title: "Redis namespaces vs separate DBs"
date: 2016-09-22
categories: redis
---

When you store keys in Redis you often need to group them into various categories.  Perhaps some of the keys are used by your application cache (which might need to be flushed).  Other keys store can be used to store data on more permanent basis.  


### Separate DBs

By default Redis comes with 16 DBs that can be easily changed in redis.conf by modifying `databases 16` key.  

`flushdb` will quickly and safely remove all keys in that DB.  


### Namespaces w/in the same DB

This approach increases the length of your key by prepending namespace to it.  So it does consume more RAM.  

users:1
accounts:2


When you have multiple applications using the same Redis server I personally prefer NOT to share Redis DBs between application.  The reason is I might decide to setup dedicated Redis server for one of the applications.  It's easier to just move data from one specific Redis DB to the new Redis server.  Plus scanning through keys (even separated by namespaces) costs time.  If one application has a HUGE number of keys (even in its own namespace) it can impact the other applications.  

Also, when I have data that I might need to get rid of (think cache) I prefer to use separate Redis DB so I can `flushdb`.  