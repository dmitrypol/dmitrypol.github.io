---
title: "Choosing a DB hosting service"
date: 2016-09-27
categories: redis mongo mysql aws
redirect_from:
  - redis/mongo/mysql/aws/2016/09/27/choose_db_host.html
---

Small tech startup often use cloud services like [AWS](https://aws.amazon.com/), [Azure](https://azure.microsoft.com/) or [Google Cloud](https://cloud.google.com/compute/).  When you are just getting started (perhaps paying for it yourself) you can get by with a single EC2 instance hosting both DB and application on the same server.  But with success come scalabilty problems.

Scaling application and DB servers usually present different challenges.  We can scale out applications by adding more servers (which also creates redundancy).  For DBs WRITES we usually have to scale UP (getting bigger instances) but for READS we could scale OUT (creating read only replicas).  But we also have to worry about proper drive sizing, IOPS, RAM / CPU ratio, etc.  Most of us are not experts in those areas.  We can choose a hosting service paying premium for time savings, convinience and piece of mind.

When you do choose such a service you will likely loose some flexiblity.  For example, if you are running Postgres you might not be able to install [Postgis](http://postgis.net/) unless the provider allows it.  

* TOC
{:toc}

### Reliablity

To me the most important thing in choose a hosting provider is realiability.  You want the hosting provider to have EXPERTS in this technology on staff.  You want their engineers to carry pagers and ensure that the service works 24/7/365 and has enough redundancy.  

When it comes to very common databases (MySQL, Postgres, MS SQL) major cloud providers offer solutions.  We use [AWS RDS](https://aws.amazon.com/rds/) to run MySQL for one of our applications.  But what if your application requires [Mongo](https://www.mongodb.com/), [Couch](http://www.couchbase.com/), [Neo4J](https://neo4j.com/) or [Riak](http://basho.com/products/)?  In those cases you can either setup your own EC2 instances or choose a 3rd party host that will run within AWS infrastructure.  

Recently we switch to use [MongoDB Atlas](https://www.mongodb.com/cloud).  We looked at providers like [ScaleGrid](https://scalegrid.io/) and [mLab](https://mlab.com/).  Their solutions looked interesting but part of me wondered if they have resources to support their service 24/7/365?

There are also some 3rd party companies that offer hosting services for variety of technologies.  For example, [Compose](https://www.compose.com/) (owned by IBM) can host Mongo, Redis, Postgres, ElasticSearch, [RethinkDB](https://www.rethinkdb.com/), [RabitMQ](https://www.rabbitmq.com/), [etcd](https://github.com/coreos/etcd) and [ScyllaDB](http://www.scylladb.com/).  And it is convinient to have one dashboard and one montly bill.  We have never used their services but part of me is cautious.  How they can be experts in such wide range of technologies?  

### Configurability

There is a fine ballance between hosting provider's experts creating optimum configurations and enabling you to tweak it as needed.  There are times when you have legitimate reasons for adjusting RAM, disk space, CPU or IOPS.  

Having used Mongo Atlas UI we really like how it allows us to upgrade the cluster, add nodes or change disk size.  One thing we wish it allowed us to do is to create smaller singleton instances.  That can be useful in small POC projects where it's hard to justify the budget.  Plus they only allow you to buy extra IOPS once you reach a certain instance size.  But overall it is a great service.  We tested the upgrade process serveral times and it worked w/o any issues.  

We also use [AWS ElastiCache Redis](https://aws.amazon.com/elasticache/redis/) but in VPC their smallest size is 1.3 GB (which is more than we need).  Other hosting providers (such as [RedisLabs](https://redislabs.com/)) allow you to have instances as small as 100MB which is a little more expensive per GB but cheaper overall.

You also want to be able to control which version of the DB software you are running so it matches your dev environment.  Sometimes those choices can be limited by the hosting provider.  For example, AWS ElastiCache Redis only supports Redis 2.8.x versions which was released in 2015.  Since then there have been a number of Redis releases with interesting new features but they are not available with ElastiCache.  

### Data migration

If you already have pre-existing application with real user data you will need to move those records to the new DB servers.  If the amount of data is not large and you can usually use standard dump and restore process.  You will often need to put up maintenance page for a few minutes during the process.  Or perhaps this only impacts portion of your application so you can disable only those pages.  

If you cannot afford any system downtime then you need a different solution.  Perhaps data can be cached and served from cache while the main DB is migrated.  This will prevent creating new records for the duration of migration.

With MongoDB you can add the new server to the replica set and let it copy the data.  Then you update your application to talk to only new DB servers and remove old ones.  You will likely need to work with the hosting provider's tech support to open the right ports and create necessary credentials.  

The most complex solution is where your application talks to both sets of servers and somehow moves data across while the system if running.  

### Scalability

Ideally our DB hosting provider would automatically scale up and down with increased traffic.  Unfortunately you can't quite do that with MySQL RDS or [Redis ElastiCache](https://aws.amazon.com/elasticache/redis/).  What you can do is manually upgrade your capacity before you have significant increase in traffic (think Black Friday).  Afterwards you just downgrade the servers.  But this does not allow you save money during daily fluctuations in traffic.

### Tech support and documentation

When you are an expert with a technology few things are more frustrating than trying to figure out the specific implementation details for hosting provider's configuration.  FAQs, code samples and migration guides save you valuable time.  But often you will have to reach their support with specific question.  Most issues can be solved with email or chat.  But for urgent production problems you MUST have ability to call someone.  That frequently costs extra and you might not need in early stages.  But it's an option you really want available if needed in the future.  

### Other important features

#### Backup and point in time recovery

Ability to restore DB to certain point in time is very important.  You can restore to main prod DB or put the snapshot on a separate server to extract the data that was lost after specific point in time.  Then you can move those records into the main production system.  

#### Data export

Separately from your production system you might have test or staging servers.  They might be located on different infrastructure.  Most hosting providers need to support standard processes.  You can run [mysqldump](http://dev.mysql.com/doc/refman/5.7/en/mysqldump.html) against RDS but be vary of extra load it will put on your system.  Nice thing about Mongo Atlas is that you can use their GUI to download backups.  

#### Command line access

DB hosting providers usually do not give you access to the underlying OS but you can use the DB shell to connect and run raw commands.  Make sure hosting provider you are considering allows that.  

### Cost

Obviously the features provided by 3rd party hosting service come at a price.  The provider has to pay AWS (or Azure) fees and on top of it charge for their services.  But they can save you money too.  For example, when we setup Mongo on our own EC2 instances we created fairly large hard drives not wanting to manually deal with resizing them later.  But that means we were paying for storage we did not need.  With Mongo Atlas we can increase disk size via GUI in matter of minutes and pay only for what we need now.

### Conclusion

There are many options out there are there are no easy answsers.  You need to consider your own needs and resources.  I hope the ideas above were helpful to you in making these decisions.  
