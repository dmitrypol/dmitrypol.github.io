---
title: "Redis microservices"
date: 2016-07-28
categories:
---

Previously wrote about creating [Microservices with Sidekiq]({% post_url 2016-02-02-microservices %}).  This artcile is an expansion on that concept.  I want to describe my experience working on several advertising platforms and how I would build an ad platform today borrowing on different ideas.

### Main app
Rails 5

### Ad server
Rails API but could be built in different technology

### Pushing data from main DB to Redis cache

Transforming data

### Processing clicks

Used to write to log files and rotate them every five minutes.  Often spent money too fast.

#### PubSub

#### Sidekiq jobs