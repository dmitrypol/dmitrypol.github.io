---
title: "Redis cache pre-generation"
date: 2016-07-28
categories: redis
---

It is very easy to use Redis as a cache store where the first request forces code to execute (query DB) and then store data in cache.  Subsequent requests use the cached data until it expires.  But what if you need / want to proactively push cached data into Redis?

Let's imagine we are building the backend system for an online banking app.  Users typically use their phones to check the latest transactions on their way to work.  As a result, you are likely to have a HUGE spike in DB load roughly between 7 and 9 am.  And if you are using a DB like SQL Server, DB2 or Oracle it will require an expensive license.

What if you could even out that load and proactively push data into cache during the earlier hours when load on the overall system is much less?  You probably don't need to push ALL transactions into cache as most people are likely to look at only first page (say 10 most recent transactions).


### Selecting which data to cache

Pre-generating cache could actually waste a lot of computer cycles as what if users never login?

Which users do you pre-generate cache for?

Which transactions to cache?


### Busting the cache

You will need to bust this cache if a new transaction occurs AFTER you pre-generated the data.

