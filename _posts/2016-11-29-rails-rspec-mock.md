---
title: "Rails Rspec mock tests"
date: 2016-11-29
categories:
---

In object oriented programming classes call methods on other classes.  While it's important to test the integration between classes it is very useful to test them in isolation, simulating valid and invalid responses from the dependent objects. 

### POROs

As applications grow we usually create smaller classes that call each other.  Let's imagine class `Foo` that calls class `Bar`.

{% highlight ruby %}
# app/services/foo.rb
class Foo
  def perform
    Bar.new.perform
  end
end
# app/services/bar.rb
class Bar
  def perform
    'hello world'
  end
end
{% endhighlight %}

We want to thoroughly test `Bar` class:

{% highlight ruby %}
# spec/services/bar_spec.rb
require 'rails_helper'
RSpec.describe Bar do
  it 'valid test' do
    expect(Bar.new.perform).to eq 'hello world'
  end
  it 'invalid test' do
    expect(Bar.new.perform).not_to eq 'good bye world'
  end
end
{% endhighlight %}

Separately we want to test `Foo` class and make sure it can handle different responses from `Bar`:

{% highlight ruby %}
# spec/services/foo_spec.rb
require 'rails_helper'
RSpec.describe Foo do
  it 'integration test' do
    expect(Foo.new.perform).to eq 'hello world'
  end
  it 'mocked test' do
    bar = double('bar', perform: 'good bye world')
    expect(Bar).to receive(:new).and_return(bar)
    expect(Foo.new.perform).to eq 'good bye world'
  end
end
{% endhighlight %}

What `expect(Bar).to receive(:new).and_return(bar)` does it is allows `Foo.new.perform` to execute but instead of calling real `Bar` class it uses double.  

### Controllers and form objects

For more realistic use case let's imagine a system where user can subscribe/unsubscribe from various newsletters.  Separately user can choose global unsubscribe.  Once the user unsubscribes from specific newsletter we want to keep that record so we do not accidentally re-subscribe user.  

{% highlight ruby %}
# app/models/user.rb
class User
  ...
  field :unsubscribed, type: Boolean
  has_many :user_newsletters
end
# app/models/newsletter.rb
class Newsletter
  field :name
  has_many :user_newsletters
end
# app/models/user_newsletter.rb
class UserNewsletter
  belongs_to :user
  belongs_to :newsletter
  field :unsubscribed, type: Boolean  
end
{% endhighlight %}

[Form objects](https://robots.thoughtbot.com/activemodel-form-objects) can be a useful design pattern for handling complex user input.  When user submits form via `http://localhost:3000/unsubscribe/user_id` we need to create/update records in `UserNewsletter` and update `User.subscribed`.  

Here is the form object:

{% highlight ruby %}
# app/forms/unsubscribe.rb
class Unsubscribe
  include ActiveModel::Model
  attr_accessor :user
  def initialize(user:, global_unsubscribed: false)
    @user = user
    @global_unsubscribed = global_unsubscribed
  end
  def save
    @user.update!(unsubscribed: @global_unsubscribed)
    # update/create user_newsletter records
  end
end
{% endhighlight %}

Controller:

{% highlight ruby %}
# config/routes.rb
resources :unsubscribe, only: [:show, :update]
# app/controllers/unsubscribe_controller.rb
class UnsubscribeController < ApplicationController
  def show
    user = User.find(params[:id])
    @unsubscribe = Unsubscribe.new(user: user)
  end
  def update
    @user = User.find(params[:id])
    if Unsubscribe.new(user: @user,
        global_unsubscribed: params[:global_unsubscribed]).save
      render js: "$('.api_response').html('account updated')", status: 200
    else
      render js: "$('.api_response').html('account not updated')", status: 422
    end
  end
end
{% endhighlight %}

And basic UI:

{% highlight html %}
# app/views/unsubscribe/show.html.erb
<h2>Manage Email Subscriptions</h2>
<%= form_for(@unsubscribe, url: unsubscribe_path(@unsubscribe.user.id.to_s),
method: :put, remote: true) do |unsub| %>
  # list newsletters here and global_unsubscribed here
  <%= submit_tag 'Save', class: "btn btn-primary" %>
  <div class="api_response"></div>
<% end %>
{% endhighlight %}

We want to thoroughly test the form object by creating appropriate records and check that data is persisted in the DB.  

{% highlight ruby %}
# spec/forms/unsubscribe_spec.rb
require 'rails_helper'
RSpec.describe Unsubscribe do
  it 'global_unsubscribed' do
    user = create(:user)
    unsub = Unsubscribe.new(user: user, global_unsubscribed: true)
    unsub.save
    expect(user.reload.unsubscribed).to eq true
  end
  it 'newsletters' do
    ...
  end
end
{% endhighlight %}

In controller test we can mock `Unsubscribe` form responses and only check the HTTP status code.  

{% highlight ruby %}
# spec/controllers/unsubscribe_controller_spec.rb
require 'rails_helper'
RSpec.describe UnsubscribeController, type: :controller do
  context 'update' do
    context 'global_unsubscribed' do
      before(:each) do
        @user = User.new(email: 'foo@bar.com')
        @user.save(validate: false)        
      end
      it 'valid' do
        unsub = double('unsubscribe', save: true)
        expect(Unsubscribe).to receive(:new).and_return(unsub)
        put :update, params: {id: @user.id.to_s, global_unsubscribed: true }
        expect(response.status).to eq 200
      end
      it 'invalid' do
        unsub = double('unsubscribe', save: false)
        expect(Unsubscribe).to receive(:new).and_return(unsub)
        put :update, params: {id: @user.id.to_s, global_unsubscribed: true }
        expect(response.status).to eq 422
      end
    end
  end
end
{% endhighlight %}

#### Useful links

* [https://semaphoreci.com/community/tutorials/mocking-with-rspec-doubles-and-expectations](https://semaphoreci.com/community/tutorials/mocking-with-rspec-doubles-and-expectations)
* [https://www.relishapp.com/rspec/rspec-mocks/docs](https://www.relishapp.com/rspec/rspec-mocks/docs)
* [https://github.com/rspec/rspec-mocks](https://github.com/rspec/rspec-mocks)
