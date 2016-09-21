---
title: "Redis capped data structures"
date: 2016-09-21
categories: redis
---

MongoDB has a very interesting feature [Capped Collections](https://docs.mongodb.com/manual/core/capped-collections/)

You also can structure data where the 3 most recent comments are stored w/in `Article` model and separately there is a `Comments` Collection.  As each new comment is created it is added to `Comments` and also inserted into `Article[:recent_comments]`.  Older comments are deleted from `Article[:recent_comments]`.

Redis does not really support things like that out of the box but it's not too hard to build.  What we want is to use Redis data structures to store last X number of records.  

### Lists

### Sets

### Sortes Sets

### Useful links
