---
title: "Mongo Atlas"
date: 2016-08-23
categories: mongo
---

We have been running MongoDB as the primary database for our Rails app for close to two years.  And gradualy the amount of data has increased so we started having scalability issues.  Problems were primary in disk IO as we did not do a good job optimizing the drives in our EC2 instances.

### Switching process:

Modify mongoid.yml config settings with new credentials.
Move recent production DB to Atlas
Deploy code with new mongoid.yml file to staging server
Run perf test loading various pages against prod and staging.

### Production cutover:

activated maintenance page
mongodump
mongorestore
took down maintenance page


### Pros
Mongo Atlast web GUI is great

I love the ability to scale the instance up or down.  We actually decided to use only M20 (which is saving us money) but we can scale it anytime.  I went through several upgrade and downgrade exercises and it worked beautifully.


### Cons

Even though we are using Mongo Cloud Manager backup service Mongo was not able to use our backup.  Instead we had to put up maintenance page, do mongodump from current DBs and then mongorestore to the new Atlast cluster.


### DevOps

Connecting to the Mongo Cluster is different via client.  Had to use MongoChef and URI string

Monitoring - mostly use default alerts but also created "Connections Above X for Y minutes"


Mongo support is great, just file a ticket and they respond very quickly.

Overall very happy.  Previously evaluated other services like https://scalegrid.io/ and https://mlab.com/.  Not only is Atlast cheaper but also knowing that MongoDB company is behind it makes me sleep better at night.

