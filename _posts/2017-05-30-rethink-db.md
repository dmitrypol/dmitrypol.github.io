---
title: "Trying out Rethink DB"
date: 2017-05-30
categories: 
---

Sometimes there is a technology which we love right away until we really use it in depth and then we start encountering it's limitations.  When I first used [MongoDB](https://www.mongodb.com/) with [Mongoid ORM](https://github.com/mongodb/mongoid) I loved the flexible schema and ability to declare fields right in my model classes (no need for schema migrations).  But now after using Mongo for a number of years on different projects I really miss some traditional SQL things (like JOINs and transactions).

I recently used [RethinkDB](https://www.rethinkdb.com/) on several small projects.  I feel that with RethinkDB the experience was the opposite.  I have not used it enough to see the benefits (compare to MongoDB) but I already hit a number of limitations.  Not in the DB itself but in the ecosystem around it.  

* TOC
{:toc}

### Installation

Installation via Docker was very easy and RethinkDB has a nice web GUI to manage the DB.  

{% highlight ruby %}
sudo docker pull rethinkdb
sudo docker run -d -P rethinkdb
{% endhighlight %}

### Switch from Mongo

I used [NoBrainer](http://nobrainer.io/) ORM which has syntax very similar to Mongoid.  

{% highlight ruby %}
class User
  include NoBrainer::Document
  include NoBrainer::Document::Timestamps
  #include Mongoid::Document
  #include Mongoid::Timestamps::Short  
end
{% endhighlight %}

Field declarations, validations and relationships are very similar.  I was able to switch an existing Mongoid project to Nobrainer in less than an hour.  

### Ecosystem limitations

But then I tried building slightly more complex features and discovered a limited ecosystem.  I was unable to find robust Ruby libraries for genearing slugs (equivalent of [mongoid-slug](https://github.com/mongoid/mongoid-slug)), soft deleting records ([mongoid_paranoia](https://github.com/simi/mongoid_paranoia)), data migrations ([mongoid_rails_migrations](https://github.com/adacosta/mongoid_rails_migrations)), encyption ([mongoid-encrypted-fields](https://github.com/KoanHealth/mongoid-encrypted-fields)) or full text search ([mongoid_search](https://github.com/mongoid/mongoid_search)).  

Some of my favorite libraries for file uploads ([carrierwave](https://github.com/carrierwaveuploader/carrierwave)) or pagination ([kaminari](https://github.com/amatsuda/kaminari)) had [integrations](http://nobrainer.io/docs/3rd_party_integration/) but others did not.  I was unable to make [rails_admin](https://github.com/sferik/rails_admin) work.  

When I tried [redis-search](https://github.com/huacnlee/redis-search) I got errors:

{% highlight ruby %}
rake redis_search:index:all
Redis-Search index data to Redis from [app/models]
[User]
skiped, not support this ORM in current.
Indexed 0 rows  |  Time spend: 0.048981236s
Rebuild Index done.
{% endhighlight %}

Yes, I could roll-up my sleeves and build these features myself (perhaps even open source them to give back to community).  But I admit, I do not have time to invest in becoming an expert with RethinkDB.  Perhaps languages other than Ruby have richer ecosystems.  

### Hosting

Running DB in production (with features such as point in time backup data recovery and easy scaling) is no simple task.  Short of running our own EC2 instances or physical hardware there seems to be only one PAAS for RethinkDB from [IBM Compose](https://www.compose.com/rethinkdb).  Their service is not cheap and there is free tier to try things.  

In conclusion I think it would be very interesting if RethinkDB develops as an open source project after the company had to shutdown.  But right now it feels like "chicken and egg" problem.  Untill there is bigger community, adoption will be slow.  And until RethinkDB is used more widely there will be fewer libraies and other support options.  
