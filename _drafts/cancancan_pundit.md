---
title: "Switching from CanCanCan to Pundit"
date: 2016-08-13
categories:
---

Recently we switched our application from [CanCanCan](https://github.com/CanCanCommunity/cancancan) to [pundit](https://github.com/elabs/pundit).  CanCanCan is a great gem but we outgrew it.  Here are the various lessons learned.

CanCanCan is very easy to get started with.  All permissions are defined in ability.rb but with time that file gets very large.  Pundit separates permissions into separate policy classes which can inherit from each other.


### Grouping policies
Frequently you have lots of models that need to share the same permsisions.  So you might not want to create policy files to each and every model, especially if the code is duplicated.  Remember, your policy files are just Ruby classes.

{% highlight ruby %}
class ApplicationPolicy
  # define common permissions here
end
class Group1Policy < ApplicationPolicy
  def index?
    # customize permissions here, call super if needed
  end
end
class Group2Policy < ApplicationPolicy
  # different permissions here
end
class Model1Policy < Group1Policy
  # more customizations if needed
end
class Model1
  # will automatically use Model1Policy
end
class Model2
  def self.policy_class
    Group2Policy # specify policy
  end
end
{% endhighlight %}


### Require authorize in application controller for all actions
I personally prefer to require authorize for all controller actions even I put `def index?   true; end` to give everyone access.


### Field level permissions
Sometimes you need to define permissiosn on specific field w/in record.  Sales reps should able to see their own commissions on each sale but NOT be able to change them no be able to see other reps commissions.  A manager should be able to see all reps commissions in his/her team and Admin might need to be able to change the commissions.
I even posted question http://stackoverflow.com/questions/34822084/field-level-permissions-using-cancancan-or-pundit


### Headless policies

Make sure your policy file only contains the basic permission check.  When you run `rails g pundit:policy dashboard` it will in clude placeholder for `class Scope < Scope`

{% highlight ruby %}
class DashboardPolicy < Struct.new(:user, :dashboard)
  def index?
    true
  end
end
{% endhighlight %}

Otherwise you get

{% highlight ruby %}
Pundit::NotDefinedError at /dashboard
unable to find policy `DashboardPolicy` for `:dashboard`
{% endhighlight %}


https://github.com/elabs/pundit/issues/77



### More resources

http://blog.carbonfive.com/2013/10/21/migrating-to-pundit-from-cancan/
https://www.viget.com/articles/pundit-your-new-favorite-authorization-library
http://through-voidness.blogspot.com/2013/10/advanced-rails-4-authorization-with.html
https://www.sitepoint.com/straightforward-rails-authorization-with-pundit/
https://www.varvet.com/blog/simple-authorization-in-ruby-on-rails-apps/

{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


