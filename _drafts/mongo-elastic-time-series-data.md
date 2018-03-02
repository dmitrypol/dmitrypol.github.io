---
title: "Mongo vs ElasticSearch for time series data"
date: 2018-03-01
categories: mongo elastic
---

Both MongoDB and ElasticSearch support storing unstructured documents.  

MongoDB
Can be used as primary DB.  Lots of ORMs that simplify integration with applications and map to models.  
Mongo Atlas supports point in time recovery.  


ElasticSearch
Kibana and Logstash simplify getting data into ElasticSearch, visualizing and doing ad hoc analysis.  
Data lifecycle management for doing rollups and snapshots to S3.  
Not so suited for being a primary data store for application.  
