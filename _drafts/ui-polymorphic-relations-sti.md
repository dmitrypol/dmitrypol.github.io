---
title: "UI for Polymorphic Relations and Single Table Inheritance"
date: 2016-11-15
categories:
---

Previously I have wrtten about [polymorphic DB relations]({% post_url 2016-10-26-rails-nested-routes-polymorphic-associations %}) and [Single Table Inheritance]({% post_url 2016-02-12-single-table-inherit %}).  But how do you build UI to do CRUD operations on such records?  


#### Polymorphic relations

The current application I am working on is an online fundraising platform.  We send out lots of emails promoting either online fundraisers or physical events.  The attributes between Events and Fundraisers are slightly different so we decided to create separate models.  

{% highlight ruby %}
# app/models/event.rb
class Event
  has_many :notifications, as: :promotion  
end
# app/models/fundraiser.rb
class Fundraiser
  has_many :notifications, as: :promotion  
end
# app/models/email.rb
class Notification
  belongs_to :promotion, polymorphic: true
end
{% endhighlight %}

The the UI when users create a new Notification they need to associate it to either Event or Fundraiser.  




#### Single table inheritance


#### Links

* [https://launchschool.com/blog/understanding-polymorphic-associations-in-rails](https://launchschool.com/blog/understanding-polymorphic-associations-in-rails)
* [http://guides.rubyonrails.org/association_basics.html](http://guides.rubyonrails.org/association_basics.html)
