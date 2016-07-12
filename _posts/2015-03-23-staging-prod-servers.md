---
title:  "One way to setup staging servers for final verification before going live"
date: 2015-03-23
categories: aws
---

Once we are done coding and testing software on our dev machines it's often important to check it in environment similar to production (at least do basic visual verification).  I worked in a lot of places where we had separate staging/demo environments with dedicated databases.  Code would be deployed there and verified by biz users as the last step before launch.

The problem is that despite best efforts these staging environments were NEVER the same as real production.  Either the hardware was underpowered or DB data was out of date (often the case) or some other configuration differed.  If you had to do manual setup via UI as part of your deploy that had to be done twice (and often forgotten).

Here is how I solved this problem on a few recent projects.  Warning - this will not work for all situations as it does introduce certain risks.

* Each server has DNS records for app1.yourdomain.com and stg1.yourdomain.com pointed to the same server IP.  We also have separate DNS records pointed at our load balancer which is how regular users access the site.
* On each of our production servers we have /opt/app_name/app and /opt/app_name/stg folders.
* Nginx server configuration block loads code from stg folder when you are browsing via stg1.yourdomain.com (or stg2, stg3, etc).  When you browse via app1.yourdomain.com or via the load balancer Nginx will load the code from app folder.
* We do NOT have separate config files so applcations in stg folders point to shared prod DB.

#### Benefits
* The advantage of this approach is we can check how new code will work with real data (how long it will take to generate report).  We can deploy very 'beta quality' code to stg w/o worrying about impacting regular users.
* We can check how site runs when data center is hundreds of miles away and how CSS/JS will work once they have been minified for prod.
* Using the same serves allows us to make sure that all code dependencies (gems, Node and Linux packages, etc) work correctly on our production OS (handy when you are upgrading something).
* Also sometimes we need to do specific data modifications which are usually not allowed in our internal admin UI.  We can make small change to allow it, deploy to stg server, modify the data and rollback the change.
* And this saves $ and time not having to manage separate stg servers.

#### Risks and workarounds
* Most obvious is you can mess up data in production DB.  Your biz user thinks he/she is on "staging server" and accidentally deletes something.
* If you are using stored procedures this will not work as well because those need to be loaded into the shared DB.
* Another challenge is if your deploy requires backwards incompatible schema or data migrations.  Your staging code will not work without the migration yet your production will break once you run the migration.
* If you cannot have shared database you can setup separate DB server and create a separate config file with this DB connection string.  During stg deploy that file would be used to create different DB connection.  You could automate a process where data is periodically moved from prod to stg DB.
* It's unlikely but regular users could accidentally stumble on your stg1.yourdomain.com URL and login.  You could whitelist your office IP address in the firewall for accessing stg URLs.
* This approach also does not work for environments like [Heroku](https://www.heroku.com/) or [AWS Elastic Beanstalk](https://aws.amazon.com/elasticbeanstalk/).

Overall this approach has served as well but we have to be careful.  If your dev team is small each developer can deploy to specific stg server frequently and do appropriate verification there.
