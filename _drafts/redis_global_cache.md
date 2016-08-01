---
title: "Redis_global_cache"
date: 2016-07-31
categories: redis
---

I was recently speaking to a friend who is a CTO of tech startup.  He was describing an interesting problem.  His application and DB servers are based in AWS us-east-1 region.  But he has a large team of business users in Eastern Europe.  The latency across Atlantic is significantly slowing down his UI.  

Most of the operations are read-only so if he could setup a read-only DB closer to his users it would be OK to do write operations to East Coast.  But his DB hosting provider does not offer such option.  

The solution we were discussing is using Redis as a cache and proactively push data to Redis instance located in AWS Frankfurt or Ireland region.  His application would get data for the user dashboards from there.  



Several years ago I worked at advertising company where we setup ad servers on both East and West coasts of US.  The main application would proactively push data to ad servers (which had internal cache).  That system did not use Redis but here is how I would build such solution today if I could use Redis.  
