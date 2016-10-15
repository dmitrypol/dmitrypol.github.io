---
title: "Rails scopes inside other scopes"
date: 2016-10-14
categories:
redirect_from:
  - /2016/10/14/rails_scope_inside_scope.html
---

[Rails scopes](http://guides.rubyonrails.org/active_record_querying.html#scopes) are a useful feature.  We can define biz logic in the scopes and use them from controller actions or other model methods.  We can also pass parameters into scopes and chain scopes together.  I am not going to go into all the options but instead share how I recently started using scopes inside other scopes in the models.  

Let's imagine a system where we have Accounts that can be `active` or `pending`.  We also created several special `demo` accounts in our production DB and listed their IDs in a config file (applying special biz logic to them).  We want to automaticaly exclude these `demo` accounts from our `active` and `pending` business workflows.  

{% highlight ruby %}
# config/application.rb
config.demo_accounts = [id, id2]
# app/models/account.rb
field :status,          type: String
extend Enumerize
enumerize :status, in: [:active, :pending]
scope :demo,       ->{ where(:_id.in  => Rails.application.config.demo_accounts) }
scope :not_demo,   ->{ where(:_id.nin => Rails.application.config.demo_accounts) }
scope :active,     ->{ where(status: :active)  }
scope :pending,    ->{ where(status: :inactive) }
{% endhighlight %}

One option is to chain scopes `active.not_demo` but we might forget.  Or we can modify [default_scope](http://api.rubyonrails.org/classes/ActiveRecord/Scoping/Default/ClassMethods.html) to exclude `demo` but that is usually not recommended.  Instead we can simply chain scopes inside the scope.  Now whenever we call `.active` or `.pending` in our code the demo accounts will be excluded.  

{% highlight ruby %}
# app/models/account.rb
scope :active,     ->{ where(status: :active).not_demo  }
scope :pending,    ->{ where(status: :inactive).not_demo }
{% endhighlight %}

We also can chaing other scopes inside `->{ ... }` to create new scopes.  

{% highlight ruby %}
# app/models/account.rb
field :important,        type: Boolean
scope :important,        ->{ where(important: :true) }
scope :active,           ->{ where(status: :active)  }
scope :important_active, ->{ important.active }
{% endhighlight %}

So that's it.  Short post but I thought it was interesting.  