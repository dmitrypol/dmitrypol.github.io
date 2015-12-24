---
title:  "Lessons learned upgrading MongoDB from 2.6 to 3.0 and WiredTiger Engine"
date:   2015-12-11
categories: mongo
---

We have been using MongoDB for a while and overall it served as well.  Our system has been growing and we began expereincing some pain with our DB writes.  CPU would spike to over 60% and were unable perform some background jobs as fast as we wanted.  Part of the problem is that we need to do better job optimizing our hard drives but that's another story.  

As a first step in our scalability process we decided to upgrade Mongo to 3.0 to try this new WiredTiger engine.  With document level locking it claimed 7-10 times speed for writes.  We were running Mongo 2.6.5 in prod so we first gradually upgraded to 2.6.11.  [Mongo Cloud Manager](https://cloud.mongodb.com) was great.  I simply selected the server (click the little wrench icon), choose Mongo version and Automation agent did the rest.  As precaution I upgraded one server at a time (we have a standard cluster of 3).  You first might need to enable specific version in Version Manager.  And obviously I first did this on our test/dev systems.

I let it run in prod for a few days and then began move to 3.0.  I first had to upgrade numerous gems.  I had to switch from Mongoid 4.0.2 (with Moped driver) to Mongoid 5.0.1 (officially supported by Mongo).  I also had to upgrade other gem (as mongoid-slug, mongoid_paranoia and mongoid-encrypted-fields).  It was a rinse and repeat process, solving one incompatibility issue after another.  Then as precaution I reverted Mongoid gem back to 4.0.2 and deployed to prod.  Only then did I upgrade to Mongoid 5 and then to Mongo 3.0 (again, using Mongo Cloud Manager).

The trickiest gem to upgrade was [Database Cleaner](https://github.com/DatabaseCleaner/database_cleaner).  The latest version did support Mongo 3.0 but failed when I switched to WiredTiger.  I had to patch the gem and currently have a [PR](https://github.com/DatabaseCleaner/database_cleaner/pull/411) so hopefully it will get merged soon.

One interesting issue I encounted on our Ubuntu 14.04 is this warning when starting Mongo:
{% highlight ruby %}
WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.   We suggest setting it to 'never'
{% endhighlight %}
To sovle it I had to follow these [instructions](https://docs.mongodb.org/v3.0/tutorial/transparent-huge-pages/) to Disable Transparent Huge Pages.

The final step was switching the DB engine.  Mongo 3.0 has mmapv1 engine by default.  First I enabled Engine under Server / Modify / Advanced Options / Add Options / Storage / Engine.  I set it to mmapv1 just to test the process for each server and only then selected wiredTiger.

One issue we hit is that when you have Mongo files in one storage engine format then you cannot start Mongo with a different engine.  You have to mongodump, shutdown Mongo, move the data files elsewhere, start Mongo with new engine and then mongorestore.  Otherwise you get this error:
{% highlight ruby %}
2015-12-08T16:02:23.644-0800 I STORAGE  [initandlisten] exception in initAndListen: 28574 Cannot start server. Detected data files in /var/lib/mongodb created by storage engine 'mmapv1'. The configured storage engine is 'wiredTiger'., terminating
{% endhighlight %}
In production it just resyncs the data from the other servers in the cluster.

Overall the upgrade seems to have helped but we are still evaluating the impact.  We are not sure what steps we will take next.  We might setup new servers based on AWS AMI specifically designed for MongoDB.  Or we might go wtih a dedicated MongoDB hosting provider (like MongoLab or MongoDirector).

#### Useful links
* [https://docs.mongodb.org/v3.0/release-notes/3.0-upgrade/](https://docs.mongodb.org/v3.0/release-notes/3.0-upgrade/)
* [https://docs.cloud.mongodb.com/tutorial/change-mongodb-version/](https://docs.cloud.mongodb.com/tutorial/change-mongodb-version/)
