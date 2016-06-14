---
title: "Combining MongoDB and Redis"
date: 2014-10-12
categories: mongo redis
---

Much has been written about NoSQL databases such as [Mongo](https://www.mongodb.com) and [Redis](http://redis.io/).  I wanted to share some of my recent experience how I used them together but for very different purposes.  This is NOT an in-depth guide to either as there are plenty of other resources for that online.

At a previous job I built a keyword advertising platform.  A publisher would hit URL **http://ads.mywebsite.com?keyword=dentist** and I would respond with ads containing text, URL, cost per click, etc.  When enduser clicked the ad on it would go to my server **http://clicks.mywebsite.com?url=encoded_advertiser_url_here**.  I would record the click and redirect the user.  There was also a UI (**http://mywebsite.com**) where account managers could configure the accounts (budgets, keywords, etc).

UI and ad server are very different applications.  UI would be accessed a few hundred times a day vs the ad server would serve tens of million of ads.  I created separate URLs so I could put them on separate servers if needed.  I used Ruby [Padrino](http://padrinorb.com/) framework for both but if I were building it again I would use [Rails](http://rubyonrails.org/) for UI and [Sinatra](http://www.sinatrarb.com/) for ad server.

For the primary database I chose Mongo.  Using array fields enabled me to store keywords with each account w/o creating separate tables.  But ad server needed to have a local RAM cache of data.  At first on ad server startup I simply connected to Mongo and read data into memory.  But I like having local **persistent** cache for each ad server (at another job we a master DB crash and when ad servers tried to refresh cache they died too).

Redis can be configured to snapshot data to local RDB file and read from it on restart.  I setup ad server to work with local Redis using [Redis-rb](https://github.com/redis/redis-rb).  I stored the ads in Redis DB 0.  Keyword (dentist) was a key and list of account_ids was a [Redis Set](http://redis.io/topics/data-types#sets).  Separately I stored account_ids as key and [Redis Hash](http://redis.io/topics/data-types#hashes) with title, body, etc.

To keep the data in sync between Mongo and Redis I created a daemon with [daemons](http://daemons.rubyforge.org/).  It would check Mongo if something changed (keywords, account budgets, etc).  It would then start reading and transforming the data into Redis DB 1.  Once compelte it would use [Redis Pipelining](http://redis.io/topics/pipelining) to flush DB 0 and transfer data from DB 1 to DB 0.  This decreased any potential downtimes to fractions of a second.  I wanted to make the process smarter so it only transfered the data that changed but did not get a chance to.

When click occurred I recorded it in Redis and quickly redirected the user.  Then the daemon would update approppriate Mongo record.  I also recorded how often which keywords were requested and aggregated reports in Mongo.  Redis speed is great but having Mongo rich document structure enabled me to build better UI and reporting capabilities.

This design allowed each ad server to function independently enabling us to scale out.  The most obvious bottleneck was amount of RAM for Redis.  I could have used shared [AWS ElasticCache](https://aws.amazon.com/elasticache/) for Redis but I wanted to have local copies for speed and reliability.  And constantly running daemon drastically reduced chances that we would serve stale ads and not get paid.  This also gave us option to shutdown master DB for maintenance and continue serving ads.

I also implemented other features such as [keyword stemming](https://en.wikipedia.org/wiki/Stemming), created custom list of [stop words](https://en.wikipedia.org/wiki/Stop_words), etc.  And I had other ideas such as setting servers on separate US coasts (fairly straightfowrard with [AWS Route 53](https://aws.amazon.com/route53/)).

The above post if not quite 100% what I build as I changed a few things to keep certain details confidential and make basic concepts easier to understand.

