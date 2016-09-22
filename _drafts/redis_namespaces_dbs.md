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
