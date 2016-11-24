---
title: "Rails rspec mock"
date: 2016-11-23
categories:
---


#### POROs

In our applications we often have one class call another.  While it's important to test the integration it is very useful to test our objects in isolation.  


{% highlight ruby %}

{% endhighlight %}


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
    bar = double(bar, perform: 'good bye world')
    expect(Bar).to receive(:new).and_return(bar)
    expect(Foo.new.perform).to eq 'good bye world'
  end
end
{% endhighlight %}

What `expect(Bar).to receive(:new).and_return(bar)` does it is allows `Foo.new.perform` to execute but instead of calling real `Bar` class it uses double.  


#### Controllers and form objects

[Form objects](https://robots.thoughtbot.com/activemodel-form-objects) can be a useful technical for hanling complex user input.  


{% highlight ruby %}

{% endhighlight %}



#### Useful links

https://semaphoreci.com/community/tutorials/mocking-with-rspec-doubles-and-expectations
https://www.relishapp.com/rspec/rspec-mocks/docs
https://github.com/rspec/rspec-mocks
