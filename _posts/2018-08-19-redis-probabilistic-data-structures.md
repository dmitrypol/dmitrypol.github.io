---
title: "Using Redis probabilistic data structures to track unique events"
date: 2018-08-19
categories: redis
---

On a recent project we had to develop a process to  de-dupe events from our web log files as we were processing them through a data pipeline.  We decided to use a hash of IP & UserAgent combination to "uniquely" identify users responsible for the events and temporarily stored data in Redis.  

* TOC
{:toc}

### Storing hash of IP & UserAgent as separate Redis keys

Here is a sample Python code implementing this logic.  It generates "random" IPs and UserAgents, hashes the combination and checks if it exists in Redis as a separate key.  If the key exits, it returns False (dupe).  Otherwise it creates a key (with 900 seconds TTL per our time window requirements), increments a **new_event** counter and returns True (new event).  To force "dupe" events this code uses a small array of UserAgents and limited IP ranges.

{% highlight python %}
import redis
import random
import hashlib
counter = 'new_event'
user_agents = ['Firefox', 'Chrome', 'IE', 'Edge', 'Safari', 'Opera']
ttl = 900
size = 10000
r_many_keys = redis.Redis(db=0)
def many_keys(uniq_hash):
    if r_many_keys.exists(uniq_hash):
        return False
    else:
        pipe = r_many_keys.pipeline()
        pipe.setex(uniq_hash, '', ttl).incr(counter).execute()
        return True
def main():
    for _ in range(size):
        user_agent = random.choice(user_agents)
        ip = str(random.randint(0,10)) + '.' + str(random.randint(0,10)) +
          '.' + str(random.randint(0,10)) + '.' + str(random.randint(0,10))
        uniq_req = user_agent + '-' + ip
        uniq_hash = hashlib.md5(uniq_req.encode()).hexdigest()
        many_keys(uniq_hash)
main()
{% endhighlight %}

This solution worked but the more data we were processing the more RAM it required.  We wanted a more memory efficient alternative.  

### HyperLogLog

Redis HyperLogLog is probabilistic data structure which gives approximate number of unique values using a fraction of memory with a standard error rate of 0.81% (99%+ accurate).  

Redis HyperLogLog can count up to 2^64 items and in honor of Philippe Flajolet the commands begin with PF.

To determine if this was a new event or not we checked the count of HLL data structure, added the event and checked the count again.  Notice that we are using a separate Redis connection client (**r_hll**) pointed at different Redis DB (1 vs 0).  

{% highlight python %}
import redis
import random
import hashlib
counter = 'new_event'
user_agents = ['Firefox', 'Chrome', 'IE', 'Edge', 'Safari', 'Opera']
ttl = 900
size = 10000
r_hll = redis.Redis(db=1)
def hll(uniq_hash):
    before = r_hll.pfcount(counter)
    r_hll.pfadd(counter, uniq_hash)
    after = r_hll.pfcount(counter)
    if before == after:
        return False
    else:
        return True
def main():
    for _ in range(size):
        user_agent = random.choice(user_agents)
        ip = str(random.randint(0,10)) + '.' + str(random.randint(0,10)) +
          '.' + str(random.randint(0,10)) + '.' + str(random.randint(0,10))
        uniq_req = user_agent + '-' + ip
        uniq_hash = hashlib.md5(uniq_req.encode()).hexdigest()
        hll(uniq_hash)
main()
{% endhighlight %}

The problem with this approach is that in a multi-threaded environment there is very high likelihood of another thread (or process) added a different item to our HLL and therefore changing the count.  We needed to guarantee that nothing will happen between the three operations (pfcount, pfadd, pfcount).  And we could not use `MULTI/EXEC` because we need to store the count somewhere.  

#### Lua script

Redis will execute Lua script atomically (everything else will be blocked while the script is running so it must be fast).  This approach also makes only one Redis API call per event (vs three) which will be faster.

Lua script will accept counter and uniq_hash as params (in a real world applications counters are likely to be time-series, such as daily).  The script will encapsulate pfcount / pfadd / pfcount logic and return true or false.  

{% highlight lua %}
local counter = ARGV[1]
local uniq_hash = ARGV[2]
local before = redis.call('pfcount', counter)
redis.call('pfadd', counter, uniq_hash)
local after = redis.call('pfcount', counter)
if before == after then
  return false
else
  return true
end
{% endhighlight %}

We will load Lua script from our Python code with `script_load` command and then execute `evalsha` passing in the arguments.  

{% highlight python %}
import redis
import random
import hashlib
counter = 'new_event'
user_agents = ['Firefox', 'Chrome', 'IE', 'Edge', 'Safari', 'Opera']
ttl = 900
size = 10000
r_hll_lua = redis.Redis(db=2)
lua_script = open('/path/to/new_event.lua', 'r').read()
lua_sha = r_hll_lua.script_load(lua_script)
def hll_lua(uniq_hash):
    r_hll_lua.evalsha(lua_sha, 0, counter, uniq_hash)
def main():
    for _ in range(size):
        user_agent = random.choice(user_agents)
        ip = str(random.randint(0,10)) + '.' + str(random.randint(0,10)) +
          '.' + str(random.randint(0,10)) + '.' + str(random.randint(0,10))
        uniq_req = user_agent + '-' + ip
        uniq_hash = hashlib.md5(uniq_req.encode()).hexdigest()
        hll_lua(uniq_hash)
main()
{% endhighlight %}

Now we are saving $ on memory and still achieving 99%+ accuracy.  

### ReBloom module

Bloom Filter is probabilistic data structure designed to tell us with reasonable degree of certainty whether this is a new event or not.  Redis does not support them natively but a there is a ReBloom module that enables that functionality.  

In this Python code we first reserve a Bloom Filter for 10,000 entries with error rate of 1 in 1000.  The more accurate we want this to be the more memory and CPU will be required.  When we execute `BF.ADD` the response comes back as 0 if it's not a new item and 1 if it is new.  

{% highlight python %}
import redis
import random
import hashlib
counter = 'new_event'
user_agents = ['Firefox', 'Chrome', 'IE', 'Edge', 'Safari', 'Opera']
ttl = 900
size = 10000
r_rebloom = redis.Redis(db=3)
r_rebloom.execute_command('BF.RESERVE', 'bf_' + counter, 0.001, size)
def rebloom(uniq_hash):
    check = r_rebloom.execute_command('BF.ADD', 'bf_' + counter, uniq_hash)
    if check == 0:
        return False
    else:
        r_rebloom.incr(counter)
        return True
def main():
    for _ in range(size):
        user_agent = random.choice(user_agents)
        ip = str(random.randint(0,10)) + '.' + str(random.randint(0,10)) +
          '.' + str(random.randint(0,10)) + '.' + str(random.randint(0,10))
        uniq_req = user_agent + '-' + ip
        uniq_hash = hashlib.md5(uniq_req.encode()).hexdigest()
        rebloom(uniq_hash)
main()
{% endhighlight %}

### Combined Pyton code

Now we create a `new_event.py` script combining the approaches.  

{% highlight python %}
import redis
import random
import hashlib

counter = 'new_event'
user_agents = ['Firefox', 'Chrome', 'IE', 'Edge', 'Safari', 'Opera']
ttl = 900
size = 10000

r_many_keys = redis.Redis(db=0)

r_hll = redis.Redis(db=1)

r_hll_lua = redis.Redis(db=2)
lua_script = open('/path/to/new_event.lua', 'r').read()
lua_sha = r_hll_lua.script_load(lua_script)

r_rebloom = redis.Redis(db=3)
r_rebloom.execute_command('BF.RESERVE', 'bf_' + counter, 0.001, size)

def many_keys(uniq_hash):
    if r_many_keys.exists(uniq_hash):
        return False
    else:
        pipe = r_many_keys.pipeline()
        pipe.setex(uniq_hash, '', ttl).incr(counter).execute()
        return True

def hll(uniq_hash):
    before = r_hll.pfcount(counter)
    r_hll.pfadd(counter, uniq_hash)
    after = r_hll.pfcount(counter)
    if before == after:
        return False
    else:
        return True

def hll_lua(uniq_hash):
    r_hll_lua.evalsha(lua_sha, 0, counter, uniq_hash)

def rebloom(uniq_hash):
    check = r_rebloom.execute_command('BF.ADD', 'bf_' + counter, uniq_hash)
    if check == 0:
        return False
    else:
        r_rebloom.incr(counter)
        return True

def main():
    for _ in range(size):
        user_agent = random.choice(user_agents)
        ip = str(random.randint(0,10)) + '.' + str(random.randint(0,10)) +
          '.' + str(random.randint(0,10)) + '.' + str(random.randint(0,10))
        uniq_req = user_agent + '-' + ip
        uniq_hash = hashlib.md5(uniq_req.encode()).hexdigest()
        many_keys(uniq_hash)
        hll(uniq_hash)
        hll_lua(uniq_hash)
        rebloom(uniq_hash)

main()
{% endhighlight %}

After running the code we can launch **redis-cli** and compare results.  Note - results may vary depending on how the random IPs and UserAgents are generated.  

{% highlight python %}
# db 0 has the unique keys, the baseline to compare against
127.0.0.1:6379> get new_visit
"9399"
# db 1 has HyperLogLog with Python
127.0.0.1:6379[1]> pfcount new_visit
(integer) 9420
# db 2 has HyperLogLog with Python and Lua
127.0.0.1:6379[2]> pfcount new_visit
(integer) 9420
# db 3 has Bloom Filter
127.0.0.1:6379[3]> get new_visit
"9398"
{% endhighlight %}

Memory usage varied widely.  Storing 1 million unique IP & UserAgent combinations took almost 100MB with separate keys vs ~ 1MB as HyperLogLog.  Bloom Filter provisioned for 1 million items used about 3MB.  

Which approach is best depends on the situation.  Leveraging ReBloom module requires either hosting provider that supports it or full control of the server where Redis is running.  Using separate keys gives the most granularity in expiring data after a time window but used the most RAM.  HyperLogLog can be done with a standard Redis but Lua scripts introduce slightly more complexity.  

### Links
* https://redis-py.readthedocs.io/en/latest/index.html
* HyperLogLog - http://antirez.com/news/75
* https://www.redisgreen.net/blog/intro-to-lua-for-redis-programmers/
* https://github.com/RedisLabsModules/rebloom
