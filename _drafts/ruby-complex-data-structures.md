---
title: "Ruby and complex data structures"
date: 2017-06-21
categories:
---

Ruby has built in support for a number of [data structures](https://www.sitepoint.com/guide-ruby-collections-part-arrays/) such  Arrays, Hashes, Sets and Ranges.  But what if we needed something else like [linked list](https://www.tutorialspoint.com/data_structures_algorithms/linked_list_algorithms.htm) [tree](https://www.tutorialspoint.com/data_structures_algorithms/tree_data_structure.htm), or  [graph](https://www.tutorialspoint.com/data_structures_algorithms/graph_data_structure.htm)?


### Linked List

Single

Double

Circular

{% highlight ruby %}

{% endhighlight %}



### Stack / Queue

https://www.leighhalliday.com/stack-in-ruby-linked-lists
http://www.thelearningpoint.net/computer-science/basic-data-structures-in-ruby---the-queue
http://www.thelearningpoint.net/computer-science/basic-data-structures-in-ruby---stack
https://www.tutorialspoint.com/data_structures_algorithms/stack_algorithm.htm

Stack - undo revision histoiry

Queue - background jobs

{% highlight ruby %}

{% endhighlight %}



### Tree

Let's imagine we have this DB / model setup for company employees:

{% highlight ruby %}
# app/models/user.rb
class User
  field :name
  belongs_to :manager, class_name: 'User'
  has_many   :reports, class_name: 'User'
  def org_structure_down
    reports.map do |report|
      [report.name] << report.org_structure_down
    end.flatten
  end
  def org_structure_up
    if manager.present?
      [manager.name] << manager.org_structure_up
    else
      []
    end.flatten
  end
end
{% endhighlight %}

`org_structure_up` and `org_structure_down` use recursion to bring back arrays of names.  It would be better to use [tree](https://www.tutorialspoint.com/data_structures_algorithms/tree_data_structure.htm) to store the company hierarchy.  [Rubytree](https://rubygems.org/gems/rubytree/) is a very mature gem that can be used for this purpose.  

#### Binary tree

http://www.thelearningpoint.net/computer-science/basic-data-structures-in-ruby---binary-search-tre
https://www.tutorialspoint.com/data_structures_algorithms/binary_search_tree.htm
https://www.cs.auckland.ac.nz/software/AlgAnim/red_black.html
http://rubyalgorithms.com/binary_search_tree.html


### Graph


{% highlight ruby %}

{% endhighlight %}




{% highlight ruby %}

{% endhighlight %}


https://www.tutorialspoint.com/ruby/ruby_hashes.htm
http://rubylearning.com/satishtalim/ruby_arrays.html
https://www.sitepoint.com/ruby-interview-questions-linked-lists-and-hash-tables/
