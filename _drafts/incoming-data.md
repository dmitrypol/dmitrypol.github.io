---
title: "Incoming data"
date: 2018-02-24
categories: aws elastic
---

Modern software systems collect LOTS of data.  It could be an analytics platform tracking user interactions or it could be IoT system collecting measurements from sensors.  

Design 1

API - queue - processor - data store

RailsAPI
ElasticBeanstalk
terraform
shoryuken


Design 2

ELB logs - S3 - logstash - data store

The challenge is that we often have to do complex validations / transformations on our data.  

https://www.elastic.co/guide/en/logstash/current/plugins-filters-ruby.html and placing Ruby code in an external file.  

Create classes, use 3rd party gems (https://github.com/chef/mixlib-cli) and write automates tests.  Logstash will simply run the code, it's our responsibility to make it's correct.  
