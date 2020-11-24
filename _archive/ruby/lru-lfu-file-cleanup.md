---
title: "LRU vs LFU file cleanup"
date: 2018-04-09
categories: redis
---

Modern applications need to read and write to and from files.  There are various use cases so let's assume an app that regularly generates JSON files that are used for a period of time and then a new set is generated.  With time these older files become less important and simply use storage space.  

There are various ways to purge old files to decrease the storage costs.  Amazon S3 allows to do it by file age.  But what if we needed to purge only the files that have not been accessed in a long time?  How can we do that?  

* TOC
{:toc}

### Write files

We will generate a file and upload it to S3.  

{% highlight ruby %}
# config/initializers/aws.rb
S3_CLIENT = Aws::S3::Client.new( credentials: ..., region: ...)
S3_BUCKET = ...
class WriterClass
  def perform
    file = generate
    upload file
  end
private
  def generate
    # generate and return JSON file
  end
  def upload file
    file_id = SecureRandom.uuid
    S3_CLIENT.upload_file ...
  end
end
{% endhighlight %}

### SortedSets

#### LRU algorithm

##### Read files

Now in different parts of our application we will track access to each JSON file.  Since our app is likely to run on multiple servers we will use Redis as a shared data store.  First we will implement LRU algorithm using Sorted Sets.

{% highlight ruby %}
# config/initializers/redis.rb
REDIS_CLIENT = Redis.new host: ...
class ReaderClass
  def perform file_id
    ...
    REDIS_CLIENT.zadd 'file_access_sorted_set', Time.now.to_i, file_id
  end
end
# data in Redis
{"key":"file_access_sorted_set","ttl":-1,"type":"zset","value":[
  ["ad7ca8af-7e50-450d-8b6c-79f88ba32cfb",1523316755.0],
  ["dc698567-c19e-4f58-854f-4e5b6780b53a",1523316855.0]
  ],...}  
{% endhighlight %}


##### Purge files

For this we will create a nightly job that will delete S3 objects.  


{% highlight ruby %}

{% endhighlight %}


#### LFU algorithm

##### Read files

{% highlight ruby %}
class ReaderClass
  def perform file_id
    ...
    REDIS_CLIENT.zincrby 'file_access_sorted_set', 1, file_id
  end
end
# data in Redis
{"key":"file_access_sorted_set","ttl":-1,"type":"zset","value":[
  ["ad7ca8af-7e50-450d-8b6c-79f88ba32cfb",10.0],
  ["dc698567-c19e-4f58-854f-4e5b6780b53a",15.0]
  ],...}  
{% endhighlight %}


##### Purge files


### Double Linked Lists

The problem with using Sorted Sets is that they become slower to insert records into with increase in size.  


{% highlight ruby %}
class ReaderClass
  def perform file_id
    ...
    REDIS_CLIENT
  end
end

{% endhighlight %}



### Links
* https://docs.aws.amazon.com/AmazonS3/latest/dev/object-lifecycle-mgmt.html
* https://redis.io


{% highlight ruby %}

{% endhighlight %}
