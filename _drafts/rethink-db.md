---
title: "Trying out Rethink DB"
date: 2017-03-24
categories:
---

Sometimes there is a technology which we love right away until we really use it in depth and then we start encountering it's limitations.  When I first used Mongo (with Mongoid ODM) I loved the flexible schema and ability to declare fields right in my model classes (no need for schema migrations).  After using Mongo for a number of years on different projects I really miss some traditional SQL things (like JOINs)

I recently decided to try RethinkDB on several personal projects.  I feel that with RethinkDB the experience was the opposite.  I have not used it enough to see the benefits (compare to MongoDB) but I already hit a number of limitations.  Not in the DB itself but in the ecosystem around it.  

### Installation

Installation via Docker was very easy:

sudo docker pull rethinkdb

sudo docker run -d -P

It has a great web GUI to manage the DB.  

### Switch from Mongo

using http://nobrainer.io/

Very similar syntax.  

{% highlight ruby %}
class User
  include NoBrainer::Document
  include NoBrainer::Document::Timestamps
  #include Mongoid::Document
  #include Mongoid::Timestamps::Short  
end
{% endhighlight %}


### Ecosystem limitations

Very limited ecosystem.  No equivalent of Ruby gems for:  
slugs
soft delete
migrations


Other gems do not work with nobrainer:

rails_admin

https://github.com/huacnlee/redis-search

{% highlight ruby %}
rake redis_search:index:all
Redis-Search index data to Redis from [app/models]
[User]
skiped, not support this ORM in current.
Indexed 0 rows  |  Time spend: 0.048981236s
Rebuild Index done.
{% endhighlight %}


Yes, I could roll-up my sleeves and build these features myself (perhaps even open source them to give back to community).  

Perhaps other languages have richer ecosystems for RethinkDB

### Hosting

Short of running your own EC2 instances or physical hardware there seems to be only one PAAS for RethinkDB https://www.compose.com/rethinkdb.  They do not have a free tiet to try things and are not that cheap.  


{% highlight ruby %}

{% endhighlight %}
