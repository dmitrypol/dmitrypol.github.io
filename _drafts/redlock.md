---
title: "Distributed Lock Management with Redlock"
date: 2020-02-29
categories: redis
---

In a previous [article]({% post_url 2020-02-29-redis-data-eng %}) we explored how to use Redis to scale ETL pipelines.  One issue we did not address is creating redundant scheduler that will ensure that our jobs are executed on time.  In this article we will explore Distributed Lock Management and Redlock algorithm.  Code can be found [here](https://github.com/dmitrypol/dlm).

* TOC
{:toc}

First we need to discuss separating job scheduling (deciding when something needs to be done) from job execution (actually doing it).  

# docker-compose.yml

We will start our environment with `docker-compose up --build -d --scale worker=2` command. 

{% highlight yaml %}
version: '3.7'
services:
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./:/opt/dlm
    environment:
      REDIS_HOST: dlm_redis_1
  redis:
    image: redis:5.0.7-alpine
    ports:
      - target: 6379
        published: 6379
    expose:
      - 6379
{% endhighlight %}

# Dockerfile

{% highlight bash %}
FROM python:3.6.8
END app_name=dlm
ENV home_dir=/opt/${home_dir}/
RUN mkdir -p ${home_dir}
WORKDIR ${home_dir}
COPY Pipfile* ./
RUN pip install --upgrade pip && pip install pipenv 
RUN pipenv install --system --dev
COPY ./ ./
ENTRYPOINT ["./entrypoint.sh"]
{% endhighlight %}

## entrypoint.sh

This file starts both scheduler and worker processes in each container.  

{% highlight bash %}
#!/bin/bash
# https://docs.docker.com/config/containers/multi-service_container/
set -m
python scheduler.py &
rq worker -c rq_config &
fg %1
{% endhighlight %}

# pipfile

{% highlight python %}
[[source]]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true
[packages]
flask = "*"
apscheduler = "*"
redlock-py = "*"
flask-rq2 = "*"
...
[requires]
python_version = "3.6.8"
{% endhighlight %}

# app/__init__.py

{% highlight bash %}
from flask import Flask
from flask_rq2 import RQ

APP = Flask(__name__)
APP.config.from_pyfile('config.py')
RQ_CLIENT = RQ(APP)
{% endhighlight %}

# app/config.py

{% highlight python %}
import os
REDIS_HOST = os.environ.get('REDIS_HOST')
REDLOCK_CONN = [
    {'host': REDIS_HOST, 'port': 6379, 'db': 2},
    {'host': REDIS_HOST, 'port': 6379, 'db': 3},
    {'host': REDIS_HOST, 'port': 6379, 'db': 4},
    ]
RQ_REDIS_URL = f'redis://{REDIS_HOST}:6379/1'
{% endhighlight %}

# app/scheduler.py

{% highlight python %}
from apscheduler.jobstores.redis import RedisJobStore
from apscheduler.schedulers.blocking import BlockingScheduler
import redlock
from . import jobs
jobstores = {'default': RedisJobStore(host=os.environ.get('REDIS_HOST'))}
SCHED = BlockingScheduler(jobstores=jobstores)

REDLOCK_CONN = [
    {'host': os.environ.get('REDIS_HOST'), 'port': 6379, 'db': 2},
    {'host': os.environ.get('REDIS_HOST'), 'port': 6379, 'db': 3},
    {'host': os.environ.get('REDIS_HOST'), 'port': 6379, 'db': 4},
    ]
DLM = redlock.Redlock(REDLOCK_CONN)

#@SCHED.scheduled_job('interval', seconds=60)
def schedule_jobs():
    try:
        my_lock = DLM.lock('schedule_jobs', 10000)
        if my_lock:
            jobs.import_data.queue()
            time.sleep(1)
            DLM.unlock(my_lock)
    except redlock.MultipleRedlockException as exc:
        logging.error(exc)
SCHED.add_job(schedule_jobs, 'interval', seconds=60)

SCHED.start()
{% endhighlight %}


# app/jobs.py

{% highlight python %}
from . import RQ_CLIENT

@RQ_CLIENT.job()
def import_data():
    #   do actual import
{% endhighlight %}


# Links
* https://redis.io/topics/distlock
* https://github.com/SPSCommerce/redlock-py
* https://github.com/agronholm/apscheduler
* http://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html
* http://antirez.com/news/101
* https://en.wikipedia.org/wiki/Distributed_lock_manager
* http://code.activestate.com/recipes/578194-distributed-lock-manager-for-python/
* https://developpaper.com/talking-about-several-ways-of-using-distributed-locks-redis-zookeeper-database/
* https://dzone.com/articles/everything-i-know-about-distributed-locks

{% highlight bash %}

{% endhighlight %}
