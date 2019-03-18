---
title: "Envoy Proxy with Redis"
date: 2019-03-18
categories: redis
---

In a previous [article]({% post_url 2019-02-25-1000-node-redis-cluster %}) we explored using Redis Cluster.  Now we will discuss using Envoy Proxy to scale our Redis infrastructure.  This article assumes that the reader is familiar with Redis and Docker Compose.  

* TOC
{:toc}

## Introduction

Redis can be leveraged for many purposes to help scale our applications.  It can help with caching, background job queuing, access throttling, features flags, and so on.  Some of the challenges with Redis are that it is mostly single-threaded and all data has to fit into RAM.  We could use replicas for reads or setup multiple Redis servers for different purposes (one for cache, another for job queue, ...) and use different connection strings.  

But what if we needed a VERY large cache to store rapidly changing data?  For example, a game like Pokémon where we keep track of user's physical lon/lat locations.  We need a lot of RAM to store the individual Redis keys.  Using TTL to purge stale keys can tax our CPU.  

Envoy Proxy allows us to setup multiple Redis instances but talk to them as a single endpoint.  The proxy will shard the data appropriately.  To run it locally we will use Docker Compose.  

## Envoy Proxy

We will start with Dockerfile for the proxy.  It will be based on the alpine image provided on Dockerhub.  

### Dockerfile 

{% highlight bash %}
FROM envoyproxy/envoy-alpine:latest
RUN rm /etc/envoy/envoy.yaml
COPY envoy.yaml /etc/envoy/envoy.yaml
{% endhighlight %}

### envoy.yaml

This config file will be copied into our container.  It sets the admin interface at `http://localhost:8001/`.  And it specifies the listener for downstream clients to connect to on port 6379.  

{% highlight yaml %}
{% raw %}
admin:
  access_log_path: "/dev/null"
  address:
    socket_address:
      protocol: TCP
      address: 0.0.0.0
      port_value: 8001
static_resources:
  listeners:
  - name: redis_listener
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 6379
    filter_chains:
    - filters:
      - name: envoy.redis_proxy
        typed_config:
          "@type": type.googleapis.com/envoy.config.filter.network.redis_proxy.v2.RedisProxy
          stat_prefix: egress_redis
          cluster: redis_cluster
          settings:
            op_timeout: 5s
  clusters:
  - name: redis_cluster
    connect_timeout: 1s
    type: strict_dns # static
    lb_policy: MAGLEV
    load_assignment:
      cluster_name: redis_cluster
      endpoints:
      endpoints:
      - lb_endpoints:
        {% for i in range(1, num_redis_hosts+1) %}
        - endpoint:
            address:
              socket_address:
                address: envoy_redis_{{ i }}
                port_value: 6379
        {% endfor %}            
{% endraw %}
{% endhighlight %}

We will save it as  `envoy.yaml.j2`.  At end of the file we configure the upstream cluster of multiple Redis endpoints using Jinja2 template syntax.  We then create a `envoy.py` wraper Python script.  

{% highlight python %}
import jinja2
template = open('envoy.yaml.j2').read()
config = jinja2.Template(template).render(num_redis_hosts = 3)
envoy_yaml = open('envoy.yaml', 'w')
envoy_yaml.write(config)
{% endhighlight %}

The output of running the `envoy.py` script will be `envoy.yaml` file with 3 `endpoint` sections referencing `envoy_redis_1`, `envoy_redis_2` and `envoy_redis_3`.  

## Worker

To generate data we will use this `worker.py` that will connnect to the Redis servers (via the proxy) and perform multiple writes.  

{% highlight python %}
#!/usr/bin/env python3
import os
import uuid
from random import uniform
import redis

if __name__ == '__main__':
    r = redis.Redis(host=os.environ['REDIS_HOST'], port=os.environ['REDIS_PORT'])
    pipe = r.pipeline(transaction=False)
    while True:
        unique_user_id = uuid.uuid4()
        coordinates = {'lon':uniform(-180,180), 'lat':uniform(-90,90)}
        pipe.hmset(unique_user_id, coordinates)
        pipe.expire(unique_user_id, 60)
        pipe.execute()
{% endhighlight %}

### Dockerfile

We can run this code via a separate Docker container.  

{% highlight bash %}
FROM python:3.6.5-alpine
RUN mkdir /code
WORKDIR /code
RUN pip install redis
COPY worker.py .
ENTRYPOINT [ "python", "worker.py" ]
{% endhighlight %}

## docker-compose.yml

We will use Docker Compose to start Redis, Envoy and our worker.  In this `docker-compose.yml` we will create 3 sets of containers referencing Dockerfiles specified above.  Network name will be `envoy` hence the use of connection strings such as `envoy_proxy_1` and `envoy_redis_1`.

{% highlight yaml %}
version: '3.7'
services:
  redis:
    image: redis:5.0.3-alpine
    expose:
      - 6379
  proxy:
    build:
      context: proxy
      dockerfile: Dockerfile
    ports:
     - 6379:6379
     - 8001:8001
    expose:
      - 6379
    depends_on:
      - redis
  worker:
    build:
      context: worker
      dockerfile: Dockerfile
    environment:
     - REDIS_HOST=envoy_proxy_1
     - REDIS_PORT=6379
    depends_on:
      - proxy
{% endhighlight %}

We will run it with `docker-compose up --build -d --scale redis=3`.  It will bring up 5 containers (1 worker, 1 Envoy Proxy and 3 Redis).  

We can browse to `http://localhost:8001/stats?usedonly&filter=redis.egress_redis.command` to see useful stats on how much data is flowing through the proxy.  We can also see how any keys are stored in each Redis instance with `docker exec -it envoy_redis_1 redis-cli dbsize` command.  

## Pros / cons

Unlike Redis Cluster the nodes behind the proxy are completely unaware of each other.  If we need to increase or decrease their number there is no easy way to move the data around.  We can set `num_redis_hosts` in `envoy.py` to 4 and recreate `envoy.yaml` with 4 endpoints.  Running `docker-compose up --build -d --scale redis=4` will launch new `envoy_redis_4` and recreate `envoy_proxy_1` (as the `envoy.yaml` changed).  However if we check the number of keys on each Redis node we will see that the 4th node has a lot fewer.  In our case the keys will expire in 60 seconds but if we try to read them in the meantime we will not find some of them on the node that the proxy thinks they should be on.  

Currently Envoy Proxy recommends using MAGLEV lb_policy based on Google's load ballancer.  With fixed table size of 65537 and 3 Redis servers behind proxy each host will hold about 21,845 hashes.  If we scale out to 4 Redis servers then each host will have about 16384 hashes.  MAGLEV is faster than RING_HASH (ketama) but less stable (more keys are routed to new nodes when number of Redis servers changes).  We can set either policy by changing `envoy.yaml`.  

Sometimes we need to perform operations on muliple keys and we need to ensure that they are present on the same server.  For that Envoy supports same algorith of using hash tags as Redis Cluster.  If the key contains a substring between {} brackets than  only the part inside the {} is hashed.  We can still use pipelining but without transactions (hence `transaction=False` in the worker code).  Most Envoy commands are identical to their Redis counterparts but we can only execute Redis commands that can be reliably hashed to a server.  

Additionally Envoy provides lots of great features for monitoring and tracing but that is beyond the scope of this article.

## Links
* https://github.com/envoyproxy/envoy/tree/master/examples/redis
* https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/redis
* https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/load_balancing/load_balancers#arch-overview-load-balancing-types
* Maglev white paper https://ai.google/research/pubs/pub44824
* https://redis.io/topics/cluster-spec#keys-hash-tags
* http://jinja.pocoo.org/
* https://hub.docker.com/r/envoyproxy/envoy-alpine
* https://hub.docker.com/_/redis
* https://hub.docker.com/_/python