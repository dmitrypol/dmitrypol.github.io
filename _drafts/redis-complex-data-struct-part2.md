---
title: "Redis complex data structures - part 2"
date: 2018-05-10
categories: redis
---

In previous [post]({% post_url 2017-06-21-redis-complex-data-struct %}) I wrote about using Redis to store complex data structures.  This much delayed article is the next iteration in the series.  Code examples will be in Ruby.

* TOC
{:toc}

### Sorted Sets

We can work with [Sorted Sets](http://redis.io/commands#sorted_set) since Redis already supports them.  
One caveat is that in Redis each member has a separate score while in Ruby the member element itself is used to determine ranking.  We need to loop through our Ruby Sorted Set and specify scores based on member value.  

{% highlight ruby %}
zset1 = SortedSet.new([2, 1, 5, 6, 4, 5, 3, 3, 3])
=> #<SortedSet: {1, 2, 3, 4, 5, 6}>
zset2 = zset1.map{|z| [z, z]}
=> [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5], [6, 6]]
REDIS.zadd('zset', zset2)
# data in Redis
{"key":"zset","ttl":-1,"type":"zset","value":[["1",1.0],["2",2.0],["3",3.0],
  ["4",4.0],["5",5.0],["6",6.0]],...}
{% endhighlight %}

To do this for non-numeric members we need to determine their numeric values to use in ranking process.  

{% highlight ruby %}
zset1 = SortedSet.new(['a', 'c', 'a', 'b'])
=> #<SortedSet: {"a", "b", "c"}>
#
TODO
{% endhighlight %}

### Bitmap

Redis supports bitmap type data structuring using String



{% highlight ruby %}

{% endhighlight %}



### Ranges

One option is to convert range to an array and then save it to Redis List.  But that will require more memory.

{% highlight ruby %}
range1 = (1..10)
REDIS.lpush 'range1', range1.to_a
# data in Redis
{"key":"range1","ttl":-1,"type":"list","value":["10","9","8","7","6",
  "5","4","3","2","1"],...}
{% endhighlight %}

Another choice is to store the first and last element of the Range in a Redis Hash and let application convert it back to a Range.  

{% highlight ruby %}
r_first = range1.first
r_last = range1.last
REDIS.hmset 'range1', 'first', r_first, 'last', r_last
# data in Redis
{"key":"range1","ttl":-1,"type":"hash","value":{"first":"1","last":"10"},...}
#
range_hash = REDIS.hgetall 'range1'
=> {"first"=>"1", "last"=>"10"}
range2 = (range_hash['first'].to_i..range_hash['last'].to_i)
{% endhighlight %}


### Linked lists

We can use [Redis Lists](http://redis.io/topics/data-types#lists).  Since Lists can be implemented using Arrays in Ruby this is similar to the previous example.  

{% highlight ruby %}
linked_list1 = [1, 2, 3]
REDIS.rpush 'linked_list1', linked_list1
# data in Redis
{"key":"linked_list1","ttl":-1,"type":"list","value":["1","2","3"],...}
#
REDIS.rpush 'linked_list', 4
REDIS.lpush 'linked_list', 0
# data in Redis
{"key":"linked_list","ttl":-1,"type":"list","value":["0","1","2","3","4"],...}
{% endhighlight %}

What we cannot do is easily add items to a middle of LinkedList stored in Redis.  We would need to get ALL list items out of Redis into application memory, modify the array, remove the previous key and resave it back to Redis.  

{% highlight ruby %}
linked_list2 = REDIS.lrange('linked_list1', 0, -1)
=> ["0","1","2","3","4"]
linked_list2.insert(3, 'foo')
=> ["0","1","foo","2","3","4"]
REDIS.del 'linked_list1'
REDIS.rpush 'linked_list1', linked_list2
{% endhighlight %}

### Binary trees


https://www.tutorialspoint.com/data_structures_algorithms/binary_search_tree.htm


http://rubyalgorithms.com/binary_search_tree.html



### Graphs

https://www.tutorialspoint.com/data_structures_algorithms/graph_data_structure.htm

https://github.com/agoragames/amico





{% highlight ruby %}

{% endhighlight %}




https://www.sitepoint.com/ruby-interview-questions-linked-lists-and-hash-tables/
https://rob-bell.net/2009/06/a-beginners-guide-to-big-o-notation/

https://github.com/nateware/redis-objects

http://jimneath.org/2011/03/24/using-redis-with-ruby-on-rails.html#redis_data_types



### Links
* https://ruby-doc.org/stdlib-2.4.1/libdoc/set/rdoc/SortedSet.html
* https://www.tutorialspoint.com/ruby/ruby_ranges.htm
* https://www.sitepoint.com/rubys-missing-data-structure/
* https://www.tutorialspoint.com/data_structures_algorithms/linked_list_algorithms.htm
