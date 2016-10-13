---
title: "Redis and custom data structures"
date: 2016-10-13
categories: redis
---


### Data structures

We all have used various data structures (linked lists, arrays, hashes, sets, binary trees).  They are usually implemented in memory but what if you need persistence AND speed?  This is where in memory DB like [Redis](http://redis.io/) can be very useful.  

Redis already supports a number of data structures but what if you need something like binary tree?  How would you do that?  

### Sorting algorithms

What if you needed to do a sort but the data was stored in Redis?  

bubble sort
merge sort

### Hash tables

Redis is using Hash tables (or something like that) internally. Dive into it and access how Redis settings affect performance, considering internal implementation.
