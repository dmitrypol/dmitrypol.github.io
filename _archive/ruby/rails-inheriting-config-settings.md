---
title: "Rails Inheriting Config Settings"
date: 2016-11-21
categories: rails
---

Let's imagine an online mall that has many Shops.  Each shop has many Deparments and each Deparment sells many Items.  We want create a default receipt subject line.  And we want to enable each shop owner to manually specify receipt subject line for the Shop and for each Deparment.  

{% highlight ruby %}
class Shop
  has_many :departments
  field :receipt_subject
end
class Deparment
  belongs_to :shop
  field :receipt_subject
end
class Item
  belongs_to :department
  has_many :purchases
end
class Purchase
  belongs_to :user
  belongs_to :item
end
{% endhighlight %}

Since it is related to presentation logic we do not want to put the methods into core models and instead use a decorator like [draper](https://github.com/drapergem/draper).  

{% highlight ruby %}
# config/application.rb
class Application < Rails::Application
  config.receipt_subject = "Thank you for your purchase"
  ...
end
# app/decorators/shop_decorator.rb
class ShopDecorator < Draper::Decorator
  delegate_all
  def get_receipt_subject
    receipt_subject || Rails.application.config.receipt_subject
  end
end
# app/decorators/department_decorator.rb
class DeparmentDecorator < Draper::Decorator
  delegate_all
  def get_receipt_subject
    receipt_subject || shop.decorate.get_receipt_subject
  end
end
{% endhighlight %}

Now we create an [ActionMailer](http://guides.rubyonrails.org/action_mailer_basics.html).  To access decorator in mailer code we can't just do `department.decorate`

{% highlight ruby %}
# app/mailers/my_mailer.rb
class MyMailer < ApplicationMailer
  def receipt(purchase: )
    @purchase = purchase
    @department = DepartmentDecorator.decorate(purchase.item.department)
    subject = @department.get_receipt_subject
    mail(
      subject: subject,
      from: ...
      to: ...
    )
  end
end
{% endhighlight %}
