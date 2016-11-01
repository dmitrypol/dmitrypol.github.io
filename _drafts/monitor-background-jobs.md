---
title: "Monitoring background jobs"
date: 2016-10-31
categories:
---

One way to scale applications is to take some of the tasks that turn them into background process.  For example, when user registers we can queue a job to send welcome email.  Other examples of such processes can include report generation, data import, etc.  

Often we will have a certain backlog of these jobs and that might be OK.  However, having too many jobs backed up is a likely indicator of some kind of problem.  How can we build an intelligent monitoring system that will alert us in advance?  

Generally jobs can be grouped into queues of different priority.  We might have really important jobs where even a small backup needs an alert.  Or we can can less important jobs (and sometimes we run lots of them) where it is OK to have thousands of jobs in the queue.  

When it comes to alerting I usually want to know "how important are the jobs", "how many of them are in the queue" and "how long have they been there".  


### Delayed Job

### Sidekiq
