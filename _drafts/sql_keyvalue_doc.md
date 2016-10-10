---
title: "Does SQL plus Key Value equals document?"
date: 2016-10-09
categories: redis mongo
---

When we store records in SQL DB we have a fixed set of columns.  Our users have first name, last name, email, etc.  

You can have optional fields.  

You can do different things.  JSON fields in PG SQL.  

Preset number of columns for custom fields.  

Custom tables per client

One nice feature of [MongoDB](https://www.mongodb.com) and [mongoid Dynamic attributes](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Attributes/Dynamic) is ability to define these custom fields that are only present in some of the records.  

How can we accompilsh that by combining SQL DB with a key value store?  Or key / data structure like Redis.  