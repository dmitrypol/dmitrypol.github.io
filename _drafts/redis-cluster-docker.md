---
title: "Running Redis Cluster locally in Docker containers"
date: 2020-11-24
categories: redis
---

In the previous [article]({% post_url 2019-02-25-1000-node-redis-cluster %}) we expored how to setup a very large (1000 node) Redis Cluster.  That required a lot of effort and computing resources.  To make it easier to get started we will setup a basic 6 node cluster (3 primary and 3 replicas) locally running in Docker containers.  To make Docker work with Redis Cluster we will use Docker host networking mode.

* TOC
{:toc}

# Docker-compose

We will use  `docker-compose` to start / stop the environment.   Save this as `docker-compose.yml`.

{% highlight yml %}
version: '3.7'
services:    
  redis7000:
    image: redis:6.0.8-alpine
    container_name: redis7000
    network_mode: host
    command: "redis-server --port 7000 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7000:/data
  redis7001:
    image: redis:6.0.8-alpine
    container_name: redis7001
    network_mode: host
    command: "redis-server --port 7001 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7001:/data
  redis7002:
    image: redis:6.0.8-alpine
    container_name: redis7002
    network_mode: host
    command: "redis-server --port 7002 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7002:/data
  redis7003:
    image: redis:6.0.8-alpine
    container_name: redis7003
    network_mode: host
    command: "redis-server --port 7003 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7003:/data
  redis7004:
    image: redis:6.0.8-alpine
    container_name: redis7004
    network_mode: host
    command: "redis-server --port 7004 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7004:/data
  redis7005:
    image: redis:6.0.8-alpine
    container_name: redis7005
    network_mode: host
    command: "redis-server --port 7005 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
      - ./volumes/7005:/data
{% endhighlight %}

# Start the environment

Run `docker-compose up --build -d` and then get inside one of the container with `docker exec -it redis7000 sh`.  Now we can setup Redis Cluster.  

{% highlight bash %}
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 --cluster-replicas 1
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 127.0.0.1:7004 to 127.0.0.1:7000
Adding replica 127.0.0.1:7005 to 127.0.0.1:7001
Adding replica 127.0.0.1:7003 to 127.0.0.1:7002
>>> Trying to optimize slaves allocation for anti-affinity
[WARNING] Some slaves are in the same host as their master
M: 4560300849962c9a4f78a50e81835759c5a6f0e6 127.0.0.1:7000
   slots:[0-5460] (5461 slots) master
M: dc9ef52638d076688d63bf777c087242b9b4f950 127.0.0.1:7001
   slots:[5461-10922] (5462 slots) master
M: d869a465f1d2ca67cf5427ba041b2426d3d5520e 127.0.0.1:7002
   slots:[10923-16383] (5461 slots) master
S: c63906d5fbc5ffbd3c617e91babec0da68840135 127.0.0.1:7003
   replicates 4560300849962c9a4f78a50e81835759c5a6f0e6
S: a2b4ade0df9488edd1bd4dda6d9c7c428731ff3d 127.0.0.1:7004
   replicates dc9ef52638d076688d63bf777c087242b9b4f950
S: ab7173e4dc59ee42edfb91136a19ab191b756a84 127.0.0.1:7005
   replicates d869a465f1d2ca67cf5427ba041b2426d3d5520e
Can I set the above configuration? (type 'yes' to accept): yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
..
>>> Performing Cluster Check (using node 127.0.0.1:7000)
M: 4560300849962c9a4f78a50e81835759c5a6f0e6 127.0.0.1:7000
   slots:[0-5460] (5461 slots) master
   1 additional replica(s)
S: a2b4ade0df9488edd1bd4dda6d9c7c428731ff3d 127.0.0.1:7004
   slots: (0 slots) slave
   replicates dc9ef52638d076688d63bf777c087242b9b4f950
S: ab7173e4dc59ee42edfb91136a19ab191b756a84 127.0.0.1:7005
   slots: (0 slots) slave
   replicates d869a465f1d2ca67cf5427ba041b2426d3d5520e
M: dc9ef52638d076688d63bf777c087242b9b4f950 127.0.0.1:7001
   slots:[5461-10922] (5462 slots) master
   1 additional replica(s)
M: d869a465f1d2ca67cf5427ba041b2426d3d5520e 127.0.0.1:7002
   slots:[10923-16383] (5461 slots) master
   1 additional replica(s)
S: c63906d5fbc5ffbd3c617e91babec0da68840135 127.0.0.1:7003
   slots: (0 slots) slave
   replicates 4560300849962c9a4f78a50e81835759c5a6f0e6
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
/data #
{% endhighlight %}

# nodes.conf files

We can go into `volumes` folder and see that each container subfolder has a `nodes.conf` file.  Before running `redis-cli --cluster create` each file contained only the information about that node.  

{% highlight bash %}
4560300849962c9a4f78a50e81835759c5a6f0e6 :0@0 myself,master - 0 0 0 connected
vars currentEpoch 0 lastVoteEpoch 0
{% endhighlight %}

After running `redis-cli --cluster create` each file contains info on ALL nodes in the cluster.  

{% highlight bash %}
a2b4ade0df9488edd1bd4dda6d9c7c428731ff3d 127.0.0.1:7004@17004 slave dc9ef52638d076688d63bf777c087242b9b4f950 0 1606259924000 2 connected
ab7173e4dc59ee42edfb91136a19ab191b756a84 127.0.0.1:7005@17005 slave d869a465f1d2ca67cf5427ba041b2426d3d5520e 0 1606259925544 3 connected
dc9ef52638d076688d63bf777c087242b9b4f950 127.0.0.1:7001@17001 master - 0 1606259924000 2 connected 5461-10922
d869a465f1d2ca67cf5427ba041b2426d3d5520e 127.0.0.1:7002@17002 master - 0 1606259925000 3 connected 10923-16383
c63906d5fbc5ffbd3c617e91babec0da68840135 127.0.0.1:7003@17003 slave 4560300849962c9a4f78a50e81835759c5a6f0e6 0 1606259924926 1 connected
4560300849962c9a4f78a50e81835759c5a6f0e6 127.0.0.1:7000@17000 myself,master - 0 1606259923000 1 connected 0-5460
vars currentEpoch 6 lastVoteEpoch 0
{% endhighlight %}

# Running commands

Get inside one of the containers `docker exec -it redis7000 sh` and try commands.  It is important to specify `-c` flag for `redis-cli` to enable cluster mode (follow -ASK and -MOVED redirections).  

{% highlight bash %}

/data # redis-cli -c -p 7000
127.0.0.1:7000> set foo bar
-> Redirected to slot [12182] located at 127.0.0.1:7002
OK
# Notice that we were automatically redirected to Redis node running on port 7002.  
127.0.0.1:7002> set bar foo
-> Redirected to slot [5061] located at 127.0.0.1:7000
OK
127.0.0.1:7000>
# now we are back on 7000 because key bar maps to the slot that currently resides on that node.  
127.0.0.1:7000> get foo
-> Redirected to slot [12182] located at 127.0.0.1:7002
"bar"
# and we switched 7002
{% endhighlight %}

We can also connect to specific Redis node by specifying port `redis-cli -c -p 7002`.  And we can run other commands.  

{% highlight bash %}
redis-cli -c -p 7000 cluster info
redis-cli -c -p 7000 cluster nodes
redis-cli -c -p 7000 debug segfault
redis-cli --cluster check 127.0.0.1:7000
{% endhighlight %}

# Monitoring / failover

Redis Cluster does not rely on Sentinel for failover.  In case one node fails the cluster will promote a replica on its own.  To check the status we can use `cluster info` command and build separate process that will periodically do this check and take appropriate action if necessary.  


{% highlight bash %}
redis-cli -c -p 7000 cluster failover
(error) ERR You should send CLUSTER FAILOVER to a replica
redis-cli -c -p 7003 cluster failover
OK
{% endhighlight %}


# Increase the cluster size

Add containers to `docker-compose.yml` file.

{% highlight yml %}
  redis7006:
    image: redis:6.0.8-alpine
    container_name: redis7006
    network_mode: host
    command: "redis-server --port 7006 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
        - ./volumes/7006:/data
  redis7007:
    image: redis:6.0.8-alpine
    container_name: redis7007
    network_mode: host
    command: "redis-server --port 7007 --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --appendonly yes"
    volumes:
        - ./volumes/7007:/data
{% endhighlight %}

Now run these commands:

{% highlight bash %}
docker-compose up --build -d
redis-cli --cluster add-node 127.0.0.1:7006 127.0.0.1:7000
redis-cli --cluster add-node 127.0.0.1:7007 127.0.0.1:7000 --cluster-slave --cluster-master-id node-id
redis-cli --cluster reshard 127.0.0.1:7000
redis-cli --cluster del-node 127.0.0.1:7000 node-id
{% endhighlight %}

# Decrease the cluster size

First we need to move data from `redis7006` to the others nodes.  

{% highlight bash %}
{% endhighlight %}

Run `docker stop redis7006 redis7007`

# Teardown environment

{% highlight bash %}
docker-compose down
# this part is important to remove volumes with nodes.conf and dump.rdb files
rm -rf volumes/*
{% endhighlight %}


# Links
* https://redis.io/topics/cluster-tutorial
* https://redis.io/topics/cluster-spec
* https://docs.docker.com/compose/compose-file/#network_mode
* 
