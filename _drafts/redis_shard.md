---
title: "Redis data sharding"
date: 2016-09-20
categories:
---

One of the downdsides of Redis is that all data is stored in RAM.  So if you cannot scale up you need to scale out and shard your data.  

### My first experience with sharding

I was not directly invovled in the project

The system was tracking phone calls so we sharded on the last integer in the number dialed.  This gave us very uniform 10 shards.  

### Other sharding approaches


### Reballancing data after adding / removing nodes
