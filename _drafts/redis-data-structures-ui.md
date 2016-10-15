---
title: "UI for Redis data structures"
date: 2016-07-30
categories: redis
---

I love powerful the data structures that Redis provides.  You can pre-aggregate data in hashes or lists and easily display stats in dashboards.  It's much faster than querying DB and generating data on demand.  

But what is there is a problem and you need to fix data?  Let's say you are counting page views by day.  In relational DB you would have a page_views table with `date` and `counter` columns.  You could easily build CRUD interface and have your internal users manually fix it (after you fix bugs in the code that caused it).  But what if data is stored in Redis Hash or Sorted Set.  How do you create, update or delete those records via GUI?  