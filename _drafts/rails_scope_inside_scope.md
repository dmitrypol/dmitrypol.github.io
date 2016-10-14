---
title: "Rails scope inside other scopes"
date: 2016-10-14
categories:
---

[Rails scopes](http://guides.rubyonrails.org/active_record_querying.html#scopes) are a useful feature.  You can define biz logic in the scope.  Then you use the scope from controller actions or other methdos.  You also can pass parameters into scopes and daisy chain scopes together.  

{% highlight ruby %}
# app/models/account.rb
class Account
field :total_revenue,   type: Integer
field :status,          type: String
extend Enumerize
enumerize :status, in: [:active, :pending]
...
scope :active,  ->{ where(status: :active)  }
scope :pending, ->{ where(status: :pending) }
scope :high_revenue, ->{ gte(total_revenue: 10000) }
{% endhighlight %}

But you can also call a scope from w/in another scope

{% highlight ruby %}
# app/models/account.rb
class Account
  scope :active_high_revenue, ->{ where(status: :active).high_revenue  }
{% endhighlight %}
