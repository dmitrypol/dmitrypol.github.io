---
title: "1000 node Redis Cluster"
date: 2019-02-25
categories: redis
---

In this article we will expore how to launch 1000 (one thousand) node Redis Cluster running on bare metal servers in the cloud.  We will then run 2000 thousand workers (with Kubernetes pods) to create load.  It will perform 1 **billion** writes in about an hour generating over 300GB of data.  

This article assumes that the reader is familiar with Redis plus has experience with Terraform, Ansible and Kubernetes or similar tools.

Full confession - I have ran smaller installations of Redis Cluster but nowhere near this scale.  This is meant to be a proof of concept to see what is possible.  

* TOC
{:toc}

## Introduction

Why should we run Redis Cluster in the first place?  Redis is an in-memory data store and it requires enough RAM store the entire dataset.  That could be mitigated by sclaing up (getting servers with more RAM).  Another issue is that Redis is mostly single-threaded so it leave unused CPU capacity.  We will expore how to use Redis Cluster to take advantage of RAM and CPU across many cores and servers.  

Redis Cluster shards data between nodes by dividing keys into 16,384 slots.  Each node in the cluster is responsible for a portion of the slots.  To determine hash slot for a specific key we simply take the CRC16 of the key mod 16384.  If we had 3 nodes than first node would hold slots from 0 to 5500, second node from 5501 to 11000 and third node from 11001 to 16383.  Separately we can implement replication for data redunancy.  

Multi-key operations can be done on Redis cluster but all keys must be on the same node.  To ensure that we can force  keys to be part of the same slot by using hash tags.  For that we create substring within {} in a key.  Only that substring will be used to determine the slot.  

Nodes can be added to or removed from cluster and Redis will move data between nodes without downtime.  Some of the limitations are that we cannot shard data within one large key (List, Set, ...).  Also Redis Cluster allows only 1 database.  

## Launch bare metal servers with Terraform

First we need to create the actual infrastructure.  We will use Terraform with Oracle Clould `BM.Standard2.52` shapes to launch 10 bare metal servers.  Each server will give us 104 cores and almost 800 GB of RAM.  Alternatively we could create these via UI or CLI.  

We have to specify appropriate clould credentials and other parameters such as ID of the base image.  We can use any Linux distrubtion for this.  

{% highlight terraform %}
provider "oci" {
  version          = ">= 3.14.0"
  tenancy_ocid     = "ocid1.tenancy.oc1..."
  user_ocid        = "ocid1.user.oc1...."
  fingerprint      = "..."
  private_key_path = "~/.oci/oci_api_key.pem"
  region           = "us-ashburn-1"
}
resource "oci_core_instance" "default" {
  count               =  10
  availability_domain = "zzzz:US-ASHBURN-AD-1"
  compartment_id      = "ocid1.compartment.oc1..."
  display_name        = "redis${count.index}"
  shape               = "BM.Standard2.52"
  subnet_id           = "ocid1.subnet.oc1..."
  source_details {
    source_type = "image"
    source_id   = "ocid1.image.oc1...."
  }
  freeform_tags = 
    {"name"= "redis"}
  metadata {
    ssh_authorized_keys = "${file('~/.ssh/id_rsa.pub')}"
  }
}
output "ip_output" {
  value = "${oci_core_instance.default.*.public_ip}"
}
{% endhighlight %}

When we run `terraform apply` the output will be the public IPs of the servers created.  

## Provision Redis Cluser with Ansible 

The next step is to properly provision Redis Cluster nodes on top of Linux.  We will be using Ansible but it could be done with other tools or even bash scripts.  When we run `ansible-playbook redis_playbook.yml -i hosts.yml` this playbook (script) will be executed on all 10 bare metal servers.  
It will install OS dependencies, clone the Redis repo and compile the code.  It will then create 100 subfolders, copy `redis-server` executable and config file specifying different ports.  Each physical server will be running 100 instances of Redis on ports 6379-6478.  

{% highlight yaml %}
{% raw %}
# redis_playbook.yml
- hosts: redis
  remote_user: ubuntu
  vars:
    redis_src_dir: ~/redis_src
    redis_server: "{{ redis_src_dir }}/src/redis-server"
    redis_cluster_dir: ~/redis_cluster
    redis_port_start: 6379
    redis_count: 100
  tasks:
  - name: install os packages
    become: yes
    apt:
      name: [make, gcc]
      update_cache: yes
  - name: clone redis git repo
    git:
      repo: https://github.com/antirez/redis.git
      dest: "{{ redis_src_dir }}"
      version: 5.0.3
  - name: compile redis
    command: make
    args:
      chdir: "{{ redis_src_dir }}"
  - name: create cluster dirs
    file:
      path: "{{ redis_cluster_dir }}/{{ item }}"
      state: directory
    with_sequence: start={{ redis_port_start }} count={{ redis_count }}
  - name: copy redis-server to cluster dirs
    copy:
      remote_src: true
      src: "{{ redis_server }}"
      dest: "{{ redis_cluster_dir }}/{{ item }}/"
      mode: u+x
    with_sequence: start={{ redis_port_start }} count={{ redis_count }}
  - name: copy redis.conf to cluster dirs
    template:
      src: redis.conf.j2
      dest: "{{ redis_cluster_dir }}/{{ item }}/redis.conf"
    with_sequence: start={{ redis_port_start }} count={{ redis_count }}
  - name: create redis-cli symlink
    file:
      src: "{{ redis_src_dir }}/src/redis-cli"
      dest: ~/redis-cli
      state: link
  - name: stop iptables
    become: yes
    shell: "systemctl stop netfilter-persistent && /usr/sbin/netfilter-persistent flush"
  - name: start redis-server
    command: ./redis-server redis.conf
    args:
      chdir: "{{ redis_cluster_dir }}/{{ item }}"
    with_sequence: start={{ redis_port_start }} count={{ redis_count }}
{% endraw %}
{% endhighlight %}

After completion each Linux server will have the following folder structure:

{% highlight bash %}
redis_cluster/
├── 6379
│   ├── redis-server
│   └── redis.conf
│   └── redis.log
├── 6380
│   ├── redis-server
│   └── redis.conf
│   └── redis.log
...
{% endhighlight %}

### hosts.yml

Ansible is ran from our local computer but it needs to know which remote IPs to connect to.  We will copy the IPs from the terrafrom output into `hosts.yml` file.  

{% highlight yaml %}
redis:
  hosts:
    1.2.3.4:
    5.6.7.8:
    ...
{% endhighlight %}

### redis.conf.j2

This is the Jinja `redis.conf` template that will be copied to all servers / directories telling Redis nodes that they will be part of the cluster.  It will specify appropriate port (ranging from 6379-6478) in each file.  It will also do other customization.  For example, we are disabling saving data to optimize for speed.  

{% highlight bash %}
{% raw %}
port {{ item }}
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
daemonize yes
logfile redis.log
appendonly no
protected-mode no
save ""
{% endraw %}
{% endhighlight %}

## Networking

We need to ensure that all Redis nodes can talk to each other.  We are running Redis on ports 6379-6478.  Separately Redis Cluster uses a second port for node-to-node communication.  That port is generated by adding 10000 to the data port so it wil be 16379-17478.  In our security list we need to allow access for both sets of ports.  

For simplicity's sake we also stopped `iptables` but in real system we would need to be more security conscious.  

## Create cluster

Next step is to execute a command to create cluster specifying all server IPs and ports.  We can use either private or public IPs.  To simplify the creation of this very long bash command we will use a Python script. 

{% highlight python %}
if __name__ == '__main__':
    redis_port_start = 6379
    redis_count      = 100
    redis_hosts_ips  = ['10.0.64.1', ... '10.0.64.15']
    output = '~/redis-cli --cluster create '
    for ip in redis_hosts_ips:
        for port in range(redis_count):
            tmp = ('{}:{} '.format(ip, redis_port_start+port))
            output += tmp
    print(output + '--cluster-replicas 0')
{% endhighlight %}

SSH to any of the 10 Linux servers and execute the bash command.  We will see that each Redis node has either 16 or 17 slots assigned to it.  

{% highlight bash %}
~/redis-cli --cluster create 10.0.64.1:6379 10.0.64.1:6380 ... 10.0.64.15:6478 --cluster-replicas 0
#   the output will be
Performing hash slots allocation on 1000 nodes...
[0mMaster[0] -> Slots 0 - 15
Master[1] -> Slots 16 - 32
Master[2] -> Slots 33 - 48
...
M: 2d5ec7794b654a479f6c833f41e0c3b82be2ace3 10.0.64.15:6476
   slots:[16040-16055] (16 slots) master
M: 0568ef38fc3fe37407f616c274d89773cedd4c42 10.0.64.15:6477
   slots:[16204-16219] (16 slots) master
M: 0fb3764a274e28df6b818e7bc051374939452c5a 10.0.64.15:6478
   slots:[16367-16383] (17 slots) master
Can I set the above configuration? (type 'yes' to accept):
#   type yes
>>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join
.....
M: 8fb0341c6f8b7c343ece32c07cf64ee3e431c291 10.0.64.15:6431
   slots:[8602-8617] (16 slots) master
M: 14d96c379da64f3138eb2aed4f62e8788bec7ab5 10.0.64.15:6444
   slots:[10797-10812] (16 slots) master
M: 27aee0f75d8ea788a075b4ed1ec1765c2b30caba 10.0.64.15:6429
   slots:[8192-8207] (16 slots) master
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
{% endhighlight %}

Now if we run `~/redis-cli -c` on any our Linux servers we will connect to the entire Redis Cluster via CLI.

{% highlight bash %}
set my_key my_value
-> Redirected to slot [13711] located at 10.0.1.15:6379
OK
{% endhighlight %}

If we do not specify `-c` flag and try set operation we may get a MOVED error message.  That means that this key does not belong to the slots currently assigned to the node we are connected to.

{% highlight bash %}
set my_key my_value
(error) MOVED 13711 10.0.1.15:6379
{% endhighlight %}

## Launch worker pods with Kubernetes

Now we will use containers and Kubernetes to generate load (we could have used a different approach).  Here is a basic `worker.py` that will create unique strings combining UUID and incrementing counter.  It will then perfrom Redis set operations using this string. 

{% highlight python %}
import os
import uuid
from rediscluster import StrictRedisCluster
if __name__ == '__main__':
    startup_nodes = [{"host": os.environ['REDIS_HOST'], 'port': '6379'}]
    r = StrictRedisCluster(startup_nodes=startup_nodes, decode_responses=True)   
    unique_id = uuid.uuid4()
    count = 0
    while True:
        tmp = "{}-{}".format(unique_id, count)
        r.set(tmp, tmp+tmp)
        count += 1
{% endhighlight %}

We will be using `redis-py-cluster` library which supports Redis Cluster.  When our app first connects to the Redis Cluster it will receive the mapping of slots to nodes.  It will use this mapping when performing read/write operation to determine which Redis node to communicate with.  We are not using pipelining as keys might be on different nodes. 

`redis-py-cluster` library will be specified in our Pipfile.  To create container we will run `docker build` with this Dockerfile.  Then we will need to push it to our Container Registry.  We are using `alpline` base image so the overall container size will be around 130 MB.  

{% highlight bash %}
FROM python:3.6.5-alpine
RUN mkdir /code
WORKDIR /code
COPY Pipfile* /code/
RUN pip install --upgrade pip && pip install pipenv && pipenv install --system --dev
COPY worker.py .
CMD python worker.py
{% endhighlight %}

To launch 2000 Kubernetes pods we will use this `worker.yml` file and run `kubectl apply -f worker.yml`.  

{% highlight yaml %}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-worker-deployment
spec:
  selector:
    matchLabels:
      app: redis-worker
  replicas: 2000
  template:
    metadata:
      labels:
        app: redis-worker
    spec:
      containers:
      - name: redis-worker
        image: CONTAINER_IMAGE_HERE
        env:
        - name: REDIS_HOST
          value: 10.0.64.1 # IP of any of the 10 bare metal servers
{% endhighlight %}

## Summary

Using the configuration above we are able to perform over 1 billion set operations in about an hour.   Ths is purely for our perf test and in the real world we have to deal with much more diverse data.  Some of the use cases can be caching, session management or high performance computing applications that can generate tremoundous amounts of data.  

There are alternatives to Redis Cluster.  In a previous [article]({% post_url 2017-05-29-redis-shard %}) we discussed ways to shard data in our application layer.  In a future article we will expore tools such as Envoy Proxy.  

## Links
* http://redis.io/topics/cluster-tutorial
* https://redis.io/commands/cluster-nodes
* https://docs.cloud.oracle.com/iaas/Content/Compute/References/computeshapes.htm
* https://www.terraform.io/docs/providers/oci/index.html
* https://github.com/Grokzen/redis-py-cluster
* https://www.envoyproxy.io/
