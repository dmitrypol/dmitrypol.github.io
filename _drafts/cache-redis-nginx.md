---
title: "Caching:  Redis vs Nginx"
date: 2020-09-12
categories: redis nginx
---

In previous articles in this blog we expored various options for using Redis for caching.  This time we will compare Redis to Nginx as a caching technology.  Code is avaiable at https://github.com/dmitrypol/cache_nginx_redis


* TOC
{:toc}

# Local environment

We can bring up our environment with `docker-compose`.  It conists of two APIs (api1 and api2), Redis and Nginx.  Nginx will be used to route request to and between APIs and to cache their responses.  

{% highlight yml %}
version: '3.7'
services:
  nginx:
    container_name: nginx
    build: ./devops/nginx/
    ports:
      - target: 80
        published: 80
    ...
  api1:
    container_name: api1
    build:
      context: api1
      dockerfile: Dockerfile
    ports:
      - target: 5001
        published: 5001
    ...
  api2:
    container_name: api2
    build:
      context: api2
      dockerfile: Dockerfile
    ports:
      - target: 5002
        published: 5002
    ...
  redis:
    container_name: redis
    image: redis:6.0.8-alpine
    ports:
      - target: 6379
        published: 6379
    expose:
      - 6379
{% endhighlight %}


# APIs

Our APIs will be simple Python `Flask` apps with `flask-caching` library.  

{% highlight python %}
...
CACHE_TYPE = 'redis'
CACHE_REDIS_HOST = 'redis'
CACHE_DEFAULT_TIMEOUT = 60
APP = Flask(__name__)
CACHE = Cache(APP)

@APP.route('/')
@CACHE.cached()
def root():
    ...
{% endhighlight %}

Requests to `http://localhost:5001/` for api1 and `http://localhost:5002/` for api2 will be cached in Redis for 60 seconds.  

# Redis

Data in Redis will be stored as strings.  On the first request Flask will check if data exists in Redis.  It will then generate the data, store it in Redis and return response to the browser.  Subsequent requests will get data from Redis until 60 seconds later Redis deletes the key.  Then data will need to be generated again in Python.  

{% highlight bash %}
127.0.0.1:6379[1]> keys *
1) "flask_cache_view//"
127.0.0.1:6379[1]> get flask_cache_view//
"!\x80\x03X\x04\x00\x00\x00api1q\x00."
127.0.0.1:6379[1]>
{% endhighlight %}

## Pros:  

The benefit of this approach is that we have a great deal of control of which data we cache and for how long.  Redis will respond quickly from RAM and cache can be shared between servers running the same code.  

## Cons

The downside of this approach is that each of our APIs needs to integrate separately with Redis.  The request will have to pass through Nginx to our Python code and then to Redis.  As we will see in the perf test results even with caching this can slow things down.  

# Nginx

We will be using Nginx `proxy_pass` and `proxy_cache` modules.  It will also cache data for 60 seconds but Nginx will use filesystem (/tmp/cache/ path) to store cache results.  

{% highlight bash %}
proxy_cache_path /tmp/cache/api1 levels=1:2 keys_zone=api1_cache:10m max_size=100m inactive=600s use_temp_path=off;
proxy_cache_path /tmp/cache/api2 levels=1:2 keys_zone=api2_cache:10m max_size=100m inactive=600s use_temp_path=off;
proxy_cache_valid any 60s;
add_header X-Cache-Status $upstream_cache_status;
server {
    listen 80;
    location /api1/ {
        proxy_pass http://api1:5001/;
        proxy_cache api1_cache;
    }
    location /api2/ {
        proxy_pass http://api2:5002/;
        proxy_cache api2_cache;
    }
}
{% endhighlight %}

To avoid confusion and not mix caching technologies we can disable Redis caching by commenting out `@CACHE.cached()` in Python.  If we browse to `http://localhost/api1/` for api1 and `http://localhost/api2/` for api2 these request will first pass through Nginx proxy.  

If we look in `tmp/cache/api1/.../.../...` we will see files with contents like this:

{% highlight bash %}
KEY: http://api1:5001/
HTTP/1.0 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 4
Server: Werkzeug/1.0.1 Python/3.6.8
Date: Sat, 13 Sep 2020 23:51:48 GMT

api1
{% endhighlight %}

## Nginx as cache proxy between APIs

Now we want to integrate api1 with api2.  We will create new route in api1 code that requests data from api2.  It can be accessed either by hitting api1 directly at `http://localhost:5001/getapi2` or via `http://localhost/api1/getapi2`.  Server side our request can be routed directly to `http://api2:5002` or via Nginx proxy with `http://nginx/api2/`.  

{% highlight python %}
@APP.route('/getapi2')
def getapi2():
    #api2_url = 'http://api2:5002'
    api2_url = 'http://nginx/api2/'
    resp = requests.get(api2_url)
    return resp.text
{% endhighlight %}

## Pros

Nginx allows us to create a shared proxy cache that can be used by many different services regardless of their software stack.  Our API could be completely down and Nginx will still respond with cached content.  

## Cons

The downside is that we loose flexibility in how and for how long we cache data.  Real APIs are much more complex and could use combination of cached and real-time data sources.  We can only apply caching logic on the URL pattern.

With Redis we can use replication to create additional caches.  While we could store cache files in a shared folder Nginx stores the cache keys in memory so this makes it difficult to scale out our caching solution.  We could put individual cache proxy in front of each API instance but that can lead to different content cached in different proxies.  

With Redis we could delete individual keys to purge specific cache.  Free Nginx does not give us such granularity but the premium Nginx Plus has support.  

# Performance test

We will use WRK https://github.com/wg/wrk.  First we need to clone the repo and compile the source code.  Note of caution, your mileage may vary depending on numerous factors, this perf test is meant to be a very high level estimate.  

## Redis cache

We will make requests directly against Flask API running on port 5001.  

{% highlight bash %}
./wrk http://localhost:5001/
Running 10s test @ http://localhost:5001/
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    65.27ms   51.33ms 472.13ms   96.54%
    Req/Sec    87.61     14.73   131.00     83.94%
  1704 requests in 10.04s, 259.61KB read
Requests/sec:    169.76
Transfer/sec:     25.86KB
{% endhighlight %}

## Nginx cache

Now we will make requests against the Nginx proxy.

{% highlight bash %}
./wrk http://localhost/api1
Running 10s test @ http://localhost/api1
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    23.38ms   12.61ms  71.50ms   61.52%
    Req/Sec   215.34     67.65   383.00     64.00%
  4293 requests in 10.01s, 779.60KB read
Requests/sec:    428.75
Transfer/sec:     77.86KB
{% endhighlight %}

We can see that Nginx cache proxy is MUCH faster.  Nginx code is very optimized and we are saving significant time on not having requests go to our Python API.  

# Links
* https://www.nginx.com/blog/nginx-caching-guide/
* https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/
* https://www.nginx.com/products/nginx/caching/
* https://flask-caching.readthedocs.io/en/latest/
* https://redis.io/