* TOC
{:toc}

### Strings

Redis supports numerous data types but we will start with Strings.  Follow instructions on http://redis.io to install Redis on dev computer and run `redis-cli`

```
127.0.0.1:6379[0]> set my_string my_value
OK
127.0.0.1:6379[0]> get my_string
"my_value"
127.0.0.1:6379[0]> keys *
1) "my_string"
127.0.0.1:6379[0]> del my_string
(integer) 1
127.0.0.1:6379[0]> get my_string
(nil)
127.0.0.1:6379[0]>
```

Here we used `set` and `get` commands to write and read value to and from string.  Then we used `keys *` to view all keys in Redis DB.  Then we used `del` command to delete the key.  Running `get` on a non-existent key returns nil.  

To use Redis from application code we will need to install appropriate client library (full list can be found on https://redis.io/clients).  In this code sample we will use Ruby and `redis-rb` client.  Run `gem install redis`.  Create my_file.rb, place the following snippet in it and run it via command line.  

```
require 'redis'
redis_client = Redis.new
redis_client.set 'my_string', 'my_value'
p redis_client.get 'my_string'
redis_client.del 'my_string'
```

This code assumes that Redis is installed locally and does not have authentication enabled.  Alternatively we could have specified `Redis.new host: 'localhost', port: 6379, db:1`.  Redis by default comes with 16 databases (0-15) but that can be changed in redis.conf file.  We can either specify DB in the client connection string or use `select 1` command in redis-cli.  

#### Counters

Strings can also be used as counters with `incr` command.  Let's look at more complex use case.  We will have a simple class and we want to keep counters in Redis of how often a specific method is executed by date.  This could be used to track how often application users perform a specific task.  

```
require 'redis'
class MyClass
  REDIS_CLIENT = Redis.new host: 'localhost', port: 6379
  def my_method
    # code here
    date = Time.now.strftime("%Y:%m:%d")
    REDIS_CLIENT.incr "#{my_method}:#{date}"
  end
end
```

We are using `my_method` as a namespace for our counter keys.  Data in Redis will look like this:

```
{"db":0,"key":"my_method:2018:06:03","ttl":-1,"type":"string","value":"125","size":1}
{"db":0,"key":"my_method:2018:06:04","ttl":-1,"type":"string","value":"648","size":1}
{"db":0,"key":"my_method:2018:06:05","ttl":-1,"type":"string","value":"276","size":1}
...
```

Now we can write another piece of code to grab all the keys that follow `my_method*` pattern and generate a report.  

```
data = Hash.new
keys = REDIS_CLIENT.keys('my_method*')
keys.each do |key|
  data[key] = REDIS_CLIENT.get key
end
```

Data is stored in Hash `{"my_method:2018:06:04"=>"1", "my_method:2018:06:05"=>"1", "my_method:2018:06:03"=>"1"}` and we format it for appropriate display.  This does require multiple calls from application to Redis but fortunately Redis is very fast.  

#### TTL

We might only want to keep a certain


#### Multi / transactions


### Lists


Data in Redis will look like this:

```

```


#### Capped Lists


### Hashes
