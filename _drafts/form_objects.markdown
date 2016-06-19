---
title: "Experimenting with form objects"
date: 2016-06-03
categories:
---

I recently started using form objects and it took me a while to wrap my head around them.  Part of my reluctance was that [accepts_nested_attributes_for](http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html) is just so quick to implement.  Here is a good [tutorial](https://www.sitepoint.com/complex-rails-forms-with-nested-attributes/) on that.  

* TOC
{:toc}

But I have come to appreciate the flexibility and control you get with form objects.  Let's imagine backend models where User has many Addresses and Phones. 

{% highlight ruby %}
class User
  field :name
  field :email
  has_many :addresses
  has_many: phones
end
class Address
  belongs_to :user
  field :address1
  field :city
end
class Phone
  belongs_to :user
  field :number
end
{% endhighlight %}

It's simple to run commands like **rails g scaffold user name email** and **rails g scaffold address user:references ...** and Rails will generate models and CRUD interface with controllers and views.  You can create user record and then create address record selecting user from dropdown list.  

But that's not now people prefer to use websites.  People **register** or **create profile**.  They want to type all their info at once and do not think how our code will store it in different tables in the DB.  That's where Form Objects can provide nice separation between our models/tables and controllers/views.  

### PORO

{% highlight ruby %}
# routes.rb
resources :profile, only: [:new, :create]
# 
class ProfileController < ApplicationController
  def new
    @form = ProfileForm.new  
  end
  def create
    @form = ProfileForm.new(profile_params)
    if @form.save
      redirect_to profile_path, notice: 'thanks for submitting profile'
    else
      render :new
    end
  end
end
# app/forms/profile_form.rb
class ProfileForm
  include ActiveModel::Model
  attr_accessor :user_name, :user_email, :address_address1, :address_city, 
    :address_region, :address_zip, :phone_number
  validates :user_name, :user_email, presence: true
  def save
    if valid?
      user = User.where(name: user_name, email: user_email).first_or_create
      Address.create(user: user, address1: address_address1, city: 
        address_city, zip: address_zip) if address_address1.present?
      Phone.create(user: user, number: phone_number) if phone_number.present?
    end
  end
end
# app/views/profile/new.html.erb
<%= simple_form_for @form, url: profile_index_path do |f| %>
  <%= f.error_notification %>
  <div class="form-inputs">
    <%= f.input :user_name %>
    <%= f.input :user_email %>
    <%= f.input :address_address1 %>
    <%= f.input :address_city %>
    <%= f.input :address_region %>
    <%= f.input :address_zip %>
    <%= f.input :phone_number %>
  </div>
  <div class="form-actions">
    <%= f.button :submit %>
   </div>
<% end %>
{% endhighlight %}

You will notice that I pushed user name and email presence validation from model into form.  I can do that thanks to ActiveModel::Model.  Here is a [RailsCast](http://railscasts.com/episodes/416-form-objects) and [ThoughtBot blog post](https://robots.thoughtbot.com/activemodel-form-objects).  

There are also some interesting gems out there that help us with creation form objects.  

### SimpleFormObject

https://www.reinteractive.net/posts/158-form-objects-in-rails
https://github.com/reinteractive-open/simple_form_object

### Virtus

https://github.com/solnic/virtus

### Reform

https://github.com/apotonick/reform


