---
title: "Bulk_edit"
date: 2016-04-03
categories:
---

At work we use Rails Admin as an internal CRUD record editing tool.  Most of the time it's simple to implement and gives us quick capability to change data if needed while we figure out what the external customer facing UI should be like.  

We added a few custom pages to RA to show some basic reports.  We can filter records and Export them.  And even import with https://github.com/stephskardal/rails_admin_import gem.  

What we really need however is ability to filter records and them bulk edit them.  Frankly speaking I am tired of writing custom scripts (rake tasks) to do that.  