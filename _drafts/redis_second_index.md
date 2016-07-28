---
title: "Redis secondary indexes"
date: 2016-07-27
categories: redis
---

When I first started using Redis I was blown away by the speed and the flexiblity of data structure.  I was able to use for a lot of data analysis tasks and did not need to create my own hashes or counters.  But when I tried using Redis as my primary DB I hit a few stumbled.  Not being able to query by value was very painful.  On one project I kept Redis for cache but swtiched to Mongo for the main DB.

I knew I needed to build my own secondary indexes but it was not easy.  Here is the summary of my lessons learned.