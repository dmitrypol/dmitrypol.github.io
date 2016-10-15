---
title: "Mongo Atlas"
date: 2016-08-23
categories: mongo
---

We have been running MongoDB as the primary database for our Rails app for close to two years.  And gradualy the amount of data has increased so we started having scalability issues.  Problems were primarily in disk IO as we did not do a good job optimizing the drives in our EC2 instances.

We evaluated various services such as [Scalegrid](https://scalegrid.io/) and [mLab](https://mlab.com/) but were hesitant to rely on them.  But then Mongo announced [Mongo Atlas](https://www.mongodb.com/cloud).

* TOC
{:toc}

### Pre-migration process

* We modified mongoid.yml config settings with new credentials. Also we had to change `auth_source: admin` and `ssl: true`
* Moved recent production DB backup to Atlas `mongodump --host yourdb.com:27017 --out dump > /dev/null`
* Deployed code with new mongoid.yml file to staging server
* Ran perf test loading various pages against prod and staging.  Results were very similar.  

We had to troubleshoot several issues with Mongoid connection configuration.  Mongo support is great, we filed several tickets and they respond very quickly.  Hopefully Mongo will document these issues on their site soon.  

We also had to configure proper security settings.  In Atlas GUI once you create the cluster you need to go to Clusters / Security and **Add New User**.  Then you go to **IP Whitelist** tab and add your server IPs or CIDR ranges.  

### Production cutover

The whole process took only a few minutes so were able to do a short maintenance window (obviously not an option for many applications).  

* activated maintenance page
* mongodump
* mongorestore
* took down maintenance page

Mongorestore command syntax is a little different `mongorestore -h Cluster0-shard-0/cluster0-shard-00-00-XXXXX.mongodb.net:27017,cluster0-shard-00-01-XXXXX.mongodb.net:27017,cluster0-shard-00-02-XXXXX.mongodb.net:27017 --ssl --username your_username --authenticationDatabase admin --drop`

### Pros

Mongo Atlast web GUI is great.  It allows to scale the instances up or down.  We actually decided to use M20 cluster (which is saving us money) but we can scale it up anytime.  We went through several upgrade and downgrade exercises and it worked beautifully.

### Cons

Even though we are using Mongo Cloud Manager backup service Mongo was not able to use our backup.  Instead we had do mongodump/mongorestore.  It was not a big deal for us but if you have to move 100GB+ of data this can be a problem.  

The best solution would have been to add the new Atlas DB servers as replicas to our existnig cluster and move data that way.  That would have avoided any system downtime but that was not supported.

### DevOps

Connecting to the Mongo Cluster is different via command line client.  `mongo mongodb://cluster0-shard-00-00-XXXXX.mongodb.net:27017,cluster0-shard-00-01-XXXXX.mongodb.net:27017,cluster0-shard-00-02-XXXXX.mongodb.net:27017/admin?replicaSet=Cluster0-shard-0 --ssl --username your_username --password`

To connect via GUI client we use [MongoChef](http://3t.io/mongochef/) (with SSL support) and URI string.

Atlas GUI has nice options for monitoring and alerts.  We mostly use default alerts but also created "Connections Above X for Y minutes"

### Conclusion

We have been now running with Mongo Atlas for over a month and very happy with the service.  Not only is Atlas cheaper than other services we looked at but knowing that MongoDB company is behind it makes us sleep better at night.  Here are the [docs](https://docs.atlas.mongodb.com/) and an interesting [article](http://blog.cloud.mongodb.com/post/146993789415/atlas-on-day-one-importing-data) on Mongo blog.
