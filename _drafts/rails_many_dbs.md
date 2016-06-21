---
title: "Using Rails with many different databases"
date: 2016-05-11
categories:
---

It is easy to find articles online debating pros and cons of different databases.  Often they have catching titles like "Why you should never use X DB".  And yes, different databases have different strengths and weaknesses.  Choosing a DB that does not fit your long term needs can be a costly decision.  

The question I'd like to ask is why should we choose?  Why can't we use different databases w/in the same application for different purposes?  Obviously it introduces additonal complexity into your code and ops infrastructure but it can be a tremendous benefit too.  We can use MySQL as the main relational database but use Redis as caching solution and Mongo for advanced data aggregation for reporting.  

Here are several examples that I can think of.  Disclaimer - I have used these technologies before but never actually combined ALL of them in the same application.  

Let's imagine we are building an online advertising platform.  We will have UI where users can manage their accounts, create ads, set budgets, etc.  We also need a separate Ad Server that can server many millions of ads.  And we need a service to run various background proceses, generate reports, proces clicks, etc.  

### SQL
SQL gives you a very rich ecosystem of various other gems that work with it.  Ability to use Joins and Transactions is crucial for many applications.  Plus 
I have been using Mongo extensively and while it's ecosystem is broad, I sometimes encounter useful gems that unfortunately only work with ActiveRecord. 

In our UI we need to have basic things like authentication, authoriziation, admin CRUD, reporting, etc.  

### Redis
As your application scales you often need a caching solution.  This is essential with ad server.  

We can use background jobs to process clicks.  When Ad Server receives a click request all it neeeds to do is throw it into Redis as background job (vis Sidekiq or Resque gem) and forward user to the destination URL.  

You can use Redis to temporarily store the granular data (keywords, impressions, clicks, IPs).  

### Mongo 
Ability to have flexible schema and aggregate data in one document is very nice.  You also can query by values (unlike Redis).  

You can aggregate data on which keywords are driving your traffic, which IPs users are coming from.  You can create different collections in Mongo for aggregating this data by different time periods (daily vs monthly) and then use Mongo TTL indexes to clean out your DB.  This can be simpler than writing jobs to remove the data.  

Here is possible document structure:


### Neo4j
I have least expereince with this technology so examples are fairly simple.  
