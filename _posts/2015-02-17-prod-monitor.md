---
title:  "My ideal production monitoring solution"
date: 	2015-02-17
categories:
---

It's not fun getting woken up in the middle of the night when your system crashes but it's even worse sleeping through it and waking up to much bigger mess in the morning.  But heck, it's a strong incentive to write quality code that will perform in the real world (not just on your laptop).

Nevertheless we all understand the need for good monitoring approach that will check our production every few minutes and alert you when something is wrong.  Yet despite trying a variety of monitoring services I can't say I love any of them.  Here is what I really want:

#### Exernal monitoring

I have a mywebsite.com/health endpoint.  Inside there are some basic checks for connectivity to DB and caching system.  There are also certain business logic checks (are there are too many jobs in the error state?).  Based on these checks this endpoints responds with one of these strings:

* **healthy** - everything is good, nothing to do.
* **sick** - minor issue, does not require immediate attention.  System is running but perhaps a few background jobs are in error state.  It also contains appropriate message providing general description of the problem. Something that makes sense to you but does not reveal to much info about inner workings of your application.
* **critical** - major issue, needs immediate response (perhaps too many jobs are backed up in the queue now).  Also contains brief message.

I've seen people build this process into the application itself where it would send you an alert.  But what if your OS crashes or you loose network connectivity?  I want the external check to be done by separate monitoring service.  This monitoring service would ping this endpoint and do one of the following:

* **healthy** - do nothing
* **sick** - just send an email to the email alias specified.  No need to wake me up.
* **critical** or no response - call me no matter what time it is.  Ideally there is a feature to setup on call rotation and escalation process.

Services like [Site24x7](https://www.site24x7.com/), [UptimeRobot](https://uptimerobot.com/), [Pingdom](https://www.pingdom.com/) and [Updown.io](http://updown.io/) can do some of these things but they seems to only do binary checks.  Either system is good or it's in error where they will alert you.  I believe there need to be intermediate states depending on severity of the problem and time of day.

#### Internal monitoring

Separately I want an "internal probe".  Some kind of software package I install with my application that sends detailed data to the "mothership".  I can login to their console and see if particular types of request are taking too long.  This is also great for ongoing performance analysis.  Services such as [NewRelic](https://newrelic.com/) and [Skylight](https://www.skylight.io/) fall into this category.  It would be great to get alerts if parts of my application have been running too slow for too long.

The problem is none of the tools I tried seem to offer end to end functionality like this.  [PageDuty](https://www.pagerduty.com/) is really good at escalating requests but they can't do outbound checks.  They can receive inbound messages so you have to combine it with another services like UptimeRobot which will send emails to PagerDuty.  Kind of a pain.

So if someone knows of a one stop shop solution please feel free to comment below.
