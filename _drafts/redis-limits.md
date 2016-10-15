---
title: "Pushing Redis beyond its limits"
date: 2016-07-26
categories: redis
---

Redis is an extremely reliable technology.  But all technologies can fail.  I am going to outline several examples of how to deliberately crash your Redis and how to recover from such situation.

Exceed RAM

Max number of values in lists / sets / sorted sets / hashes

Too long key / values

Max integer for count and score on sorted set.  Use incrby

Max number of DBs (default is 16)