---
title: "Ruby and complex data structures"
date: 2016-10-31
categories:
---

Ruby has built in support for a number of [data structures](https://www.sitepoint.com/guide-ruby-collections-part-arrays/) such  Arrays, Hashes, Sets and Ranges.  But what if we needed something else like [linked list](https://www.tutorialspoint.com/data_structures_algorithms/linked_list_algorithms.htm) [tree](https://www.tutorialspoint.com/data_structures_algorithms/tree_data_structure.htm), or  [graph](https://www.tutorialspoint.com/data_structures_algorithms/graph_data_structure.htm)?


### Linked List

{% highlight ruby %}

{% endhighlight %}



### Stack / Queue


{% highlight ruby %}

{% endhighlight %}



### Tree

Let's imagine we have this DB / model setup for company employees:

{% highlight ruby %}
# app/models/employee.rb
class User
  field :name
  belongs_to :manager, class_name: 'User'
  has_many   :reports, class_name: 'User'
  #
  def org_structure_down
    reports.map do |rep|
      [rep] + rep.reports
    end
  end
  #
  def org_structure_up
    if manager.present?
      [manager] + manager.org_structure_up
    else
      self
    end
  end
  #
  def ceo
    org_structure_up.last
  end
end
{% endhighlight %}

It would be logical to use tree to store the company hierarchy.  [Rubytree](https://rubygems.org/gems/rubytree/) is a very mature gem that suits this purpose.  



### Graph


{% highlight ruby %}

{% endhighlight %}


https://www.sitepoint.com/ruby-interview-questions-linked-lists-and-hash-tables/


{% highlight ruby %}

{% endhighlight %}
