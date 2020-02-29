---
title: "Redis for Data Engineering and Data Science"
date: 2020-02-29
categories: redis
---

Recently I spoke at [RedisDay Seattle](https://connect.redislabs.com/redisdayseattle/mktg) about using Redis for Data Engineering and Data Science.  In this article I want to revisit these ideas.  

* TOC
{:toc}

# Python Pandas

Python Pandas is a popular library for data science tasks such as importing data from various sources and analyzying it.  

{% highlight python %}
import pandas as pd
df1 = pd.read_csv('file.csv')
df2 = pd.read_json('http://.../something.json')
df3 = pd.read_sql_query('select * from …', connection)
df1.aggregate(...)
{% endhighlight %}

The challenge is that often our data acquisition is much more complex that simply reading it from one file or a single DB query.  We often have to pull data from different sources.  If one of our queries or API requests fails we do not want to repeat the entire process from the beginning.  

In this article we will explore how to use Redis for two purposes to build a simple yet more scalable system:
* As a job queue to run multiple data acquisition tasks in parallel.
* As a DB to temporarily store our datasets.

We will be using Docker and Docker Compose to manage our environment.  

# docker-compose.yml

We will start our environment with `docker-compose up --build -d --scale worker=2` command.  This will bring up 1 Redis, 1 Web and 2 Worker containers.  

{% highlight yaml %}
version: '3.7'
services:
  redis:
    image: redis:5.0.7-alpine
    ports:
      - target: 6379
        published: 6379
    expose:
      - 6379
  web:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./:/opt/redis_data
    ports:
      - target: 5000
        published: 5000
      - target: 8888
        published: 8888
    env_file:
      - common.env            
      - secrets.env            
    environment:
      CONTAINER_TYPE: web
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    volumes:
      - ./:/opt/redis_data
    env_file:
      - common.env
      - secrets.env
    environment:
      CONTAINER_TYPE: worker
{% endhighlight %}

## Environment files

### common.env

This file will contain common environment variables to be shared across containers.

{% highlight bash %}
REDIS_HOST=redis_data_redis_1
FLASK_ENV=development
FLASK_DEBUG=1
APP_ENV=dev
{% endhighlight %}

### secrets.env

This file will NOT be commited to the repo but this is where we will store token necessary to access the Github APIs.  More info is available [here](https://github.com/settings/tokens)

{% highlight bash %}
GITHUB_TOKEN=...
{% endhighlight %}

# Dockerfile

{% highlight bash %}
FROM python:3.6.8
END app_name=redis_data
ENV home_dir=/opt/${home_dir}/
RUN mkdir -p ${home_dir}
WORKDIR ${home_dir}
COPY Pipfile* ./
RUN pip install --upgrade pip && pip install pipenv 
RUN pipenv install --system --dev
COPY ./ ./
EXPOSE 5000
EXPOSE 8888
ENTRYPOINT ["./entrypoint.sh"]
{% endhighlight %}

## entrypoint.sh

This file contains the logic that depending on `CONTAINER_TYPE` env variable starts either Flask web server and Jupyter Notebook OR background job worker using `RQ` library.  

{% highlight bash %}
#!/bin/bash
# https://docs.docker.com/config/containers/multi-service_container/
set -m
if [ $CONTAINER_TYPE = 'web' ]
then
    flask run -h 0.0.0.0 -p 5000 &
    jupyter notebook --ip=0.0.0.0 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' &
elif [ $CONTAINER_TYPE = 'worker' ]
then
    rq worker -c rq_config &
fi
fg %1
{% endhighlight %}

To make sure RQ worker runs properly we need to create `rq_config.py` file:

{% highlight python %}
import os
REDIS_URL = f"redis://{os.environ.get('REDIS_HOST')}:6379/1"
{% endhighlight %}

## pipfile

We will install various dependcies with `pipenv` and `Pipfile`:

{% highlight python %}
[[source]]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true
[packages]
jupyter = "*"
pandas = "*"
requests = "*"
redis = "*"
flask = "*"
rq-dashboard = "*"
flask-rq2 = "*"
...
[requires]
python_version = "3.6.8"
{% endhighlight %}

# Worker containers

We will jump into Python shell and start running our background jobs with `jobs.github_users.queue()`.  First the code will query `https://api.github.com/users?since=0` endpoint and then it will loop through the users and hit each user URL (like this https://api.github.com/users/mojombo).  

We use `?since` parameter to paginate through the `users` endpoint and queue subsequent requests.  We use `counter` to stop after 10 `users` requests.  Overall we make 310 HTTP requests so we do not want to start from the beginning in case one of them fails.  

{% highlight python %}
@RQ_CLIENT.job()
def github_users(since=0, counter=0):
    ''' get users data from github api '''
    req = requests.get(f'https://api.github.com/users?since={since}', headers=GH_HEADERS)
    df = pd.DataFrame(req.json())
    for _, v in df.iterrows():
        github_each_user.queue(v['login'])
        since = v['id']
    #  queue next job request
    if counter+1 < 10:
        github_users.queue(since=since, counter=counter+1)

@RQ_CLIENT.job()
def github_each_user(login):
    ''' get data for specific user '''
    req = requests.get(f'https://api.github.com/users/{login}', headers=GH_HEADERS)
    ds = pd.Series(req.json()).to_dict()
    keys = ['public_repos', 'public_gists', 'followers', 'following']
    ds2 = {key: ds[key] for key in keys}
    logging.info(ds2)
    REDIS_CLIENT.hmset(login, ds2)
{% endhighlight %}

Each job will be sent via Redis queue thanks to `.queue(...)` method and picked up by one of the worker containers.  As the jobs complete they massage the data to extract `['public_repos', 'public_gists', 'followers', 'following']` and store them in Redis Hashes.  Data in Redis will look this like:

{% highlight bash %}
127.0.0.1:6379> hgetall mojombo
1) "public_repos"
2) "61"
3) "public_gists"
4) "62"
...
{% endhighlight %}

# Web container for Jupyter Notebook

This is where we transition from data engineering to data science.  We can browse to `http://localhost:8888` and user the Notebooks to do data analysis.  

One limitation of Redis is that we cannot query by value so we will use Panda DataFrame to pull data out of Redis and store it in Python memory.  Then we can do regular Pandas aggregations.  

{% highlight python %}
import os
import pandas as pd
import redis
RC = redis.Redis(host=os.environ.get('REDIS_HOST'), charset='utf-8', decode_responses=True)
{% endhighlight %}

{% highlight python %}
df = pd.DataFrame()
for key in RC.keys():
    value = RC.hgetall(key)
    value['login'] = key
    df = df.append(value, ignore_index=True)
    for k in ['public_repos', 'public_gists', 'followers', 'following']:
        df[k] = df[k].astype(int)
{% endhighlight %}

Overall this approach can be a good option for medium data scale.  Job processing can stopped and restarted later.  This solution does require a lot of memory so it is probably not a good choice when we need to store large amounts of data for extended periods of time.  But it could be very useful as a place to temporarily store data as we are processing it and once the aggregations are done we can flush Redis.  


# Links
* Video of my presenation https://www.youtube.com/watch?v=Koh6piVaYh0
* Slides from my presentation http://bit.ly/36mQ8H2 
* Code samples from my presentation https://github.com/dmitrypol/redis_data
* https://pandas.pydata.org/
* https://palletsprojects.com/p/flask/
* https://python-rq.org/
