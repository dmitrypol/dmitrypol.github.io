---
title: "Monitoring and Scaling Background Jobs"
date: 2017-04-03
categories: redis
---

Common way to scale applications is to take some of the tasks that turn them into background process.  For example, when user registers we can queue a job to send welcome email.  This way the browser can complete the request w/o waiting for email service API to respond.  Other examples of such processes can include report generation, data import, etc.  

* TOC
{:toc}

I have written about background jobs for handling [traffic spikes]({% post_url 2017-03-16-sendgrid-webhooks-background-jobs %}), [callbacks]({% post_url 2017-03-26-callbacks-background-jobs %}) and [API integrations]({% post_url 2017-03-31-api-integration-background-jobs %}).  But as we shift tasks to the background we can't just assume that they will successfully complete 100% in timely manner.  


### Background jobs backlog

Often we will have a certain backlog of these jobs and that might be OK.  However, having too many jobs backed up is a likely indicator of some kind of problem.  How can we build an intelligent monitoring system that will alert us in advance?  

### Error and retry (or not)

idempotent

### Monitoring

Too many jobs in specific queue
Jobs have been there for too long
Specific job has NOT run in a long time

Redis keys and TTL

before_perform callbacks

### Priority queues

Generally jobs can be grouped into queues of different priority.  We might have really important jobs where even a small backup needs an alert.  Or we can can less important jobs (and sometimes we run lots of them) where it is OK to have thousands of jobs in the queue.  

When it comes to alerting I usually want to know "how important are the jobs", "how many of them are in the queue" and "how long have they been there".  


### Dedicated processes per queue



### Delayed Job vs Sidekiq vs AWS SQS


### Links
