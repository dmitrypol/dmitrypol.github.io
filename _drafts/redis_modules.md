---
title: "Redis modules"
date: 2016-07-14
categories: redis
---

A couple of months ago I had a chance to attend [redisconf](http://redisconf.com/) and present about using Rails with Redis.  You can read my post about it [here]({% post_url 2015-10-15-redis-rails-tips %}) or [watch the presentation](https://www.youtube.com/watch?v=p-XNGlUoPQg&index=20&list=PL83Wfqi-zYZHtHoGv3PcGQA3lvE9p1eRl).

At the conference [RedisLabs](https://redislabs.com/) announced new [Redis Modules](http://redismodules.com/) feature.  You can read the details at this [post by antirez](http://antirez.com/news/106).  The feature is still in beta but RedisLabs and antirez are working hard to improve it before official release.  What I wanted to share are my lessions learned from configuing Redis with modules.

To get modules to work you must use UNSTABLE branch.  If you are using a hosted service like RedisLabs or [AWS ElastiCache](https://aws.amazon.com/elasticache/) you are out of luck.  If you truly want to run this in prod you would need to setup your own server.  Now, that you have been warned here are the steps that I went through.

First you need to clone Redis repo.  I am assuming you have all necessary Linux libraries for compiling the code.
{% highlight ruby %}
git clone git@github.com:antirez/redis.git
cd redis
make
make test
src/redis-server redis.conf
{% endhighlight %}
You should see standard Redis log output.  Make you sure says `"Redis 999.999.999"` (that means you are on unstable branch).  Run `src/redis-cli` to make sure you can connect and do basic GET / SET commands.

Now let's get to modules.  You can see them listed [here](http://redismodules.com/).  The ones that looked interesting to me are rxkeys/hashes/sets.  They are all part of the same [GitHub repo](https://github.com/RedisLabsModules/redex).

{% highlight ruby %}
git clone git@github.com:RedisLabsModules/redex.git
cd redex
make
make test
{% endhighlight %}
You will now see rxstrings.so, rxsets.so, etc files in redex/src.

Open redis/redis.conf file and add these lines.  You can see basic instructions around line 40.
{% highlight ruby %}
loadmodule /path/to/rxkeys.so
loadmodule /path/to/rxgeo.so
# you can all or some of the modules from redex repo
{% endhighlight %}
Stop Redis with `src/redis-cli shutdown` and start it again with `src/redis-server redis.conf`.  You should see something like this in your log:  `* Module 'rxgeo' loaded from /path/to/redex/src/rxgeo.so`.

If you are not using unstable branch and you try to start Redis with `loadmodule /path/to/my_module.so` you will see this error in your log:
{% highlight ruby %}
*** FATAL CONFIG FILE ERROR ***
Reading the configuration file, at line X
>>> 'loadmodule /path/to/module.so'
Bad directive or wrong number of arguments
{% endhighlight %}

Now you can run commands like PKEYS.
{% highlight ruby %}
src/redis-cli
127.0.0.1:6379> set foo1 one
OK
127.0.0.1:6379> set foo2 two
OK
127.0.0.1:6379> pkeys foo
1) "foo2"
2) "foo1"
{% endhighlight %}
Read [redex repo](https://github.com/RedisLabsModules/redex) for more examples.  Modules are a very interesting feature and I am looking forward to learning more about them.