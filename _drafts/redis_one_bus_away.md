---
title: "Redis_one_bus_away"
date: 2016-09-23
categories: redis
---

Here in Seattle we have a great app called One Bus Away.  It certainly saved me time waiting for bus.  

### Data structures

Bus number
Bus stop number
Minutes till arrival

### Geo proximity

Another useful feature of this app is telling you which bus stops are nearby.  This where the Redis 3.2 geo functionality can help us.  