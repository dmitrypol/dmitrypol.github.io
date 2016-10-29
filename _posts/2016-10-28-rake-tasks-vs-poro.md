---
title: "Rake tasks vs. Ruby classes"
date: 2016-10-28
categories: rails
redirect_from:
  - /2016/10/28/rake-tasks-vs-poro.html
---

When several years ago I started working with [Ruby on Rails](http://rubyonrails.org/) I liked [Rake tasks](https://github.com/ruby/rake). To me they were a great step up from ad hoc bash and SQL scripts.  It was a way to build powerful CLIs to do basis sysadmin tasks, generate ad hoc reports, upload/download files, etc.  

### Rake tasks

With Rake we can create multiple `.rake` files and group tasks into different namespaces.  We also can use multiple namespaces w/in same `.rake` file but it feels cleaner to separate them.  We can even pass parameters and do exception handling.  Tasks can be executed via cron to run periodic processes and can call other tasks.  

{% highlight ruby %}
# lib/tasks/namespace1.rake
task default: 'namespace1:task1'
namespace :namespace1 do
  desc 'no need to load environment'
  task :task1 do
    # do stuff
  end
  desc 'load environment and pass arguments'
  task :task2, [:server] => [:environment] do |t, args|
    begin
      # do stuff
    rescue Exception => e
      puts e
    end  
  end
end
# lib/tasks/namespace2.rake
namespace :namespace2 do
  task task1: :environment do
    # do stuff
  end
end
{% endhighlight %}

### Ruby classes

But with more complex business logic it is harder to fit it into `.rake` files.  That's when it is usually better to use POROs.  They can be tested via  [rspec](http://rspec.info/) or [minitest](https://github.com/seattlerb/minitest).  They can be executed from UI via controllers or via [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html).  Or even called from Rake tasks.   And we can run Ruby classes them via `rails r MyClass.new(params).perform` when needed.  

{% highlight ruby %}
# app/services/my_class.rb
class MyClass
  def initialize
  end
  def perform
  end
end
{% endhighlight %}

Both approaches have their place.  I still use Rake for various server configuration and system maintenance tasks (for example, uploading config files to production servers).  But when it comes to complex business logic I put that in Ruby service objects.  

### Useful links
* [http://jasonseifer.com/2010/04/06/rake-tutorial](http://jasonseifer.com/2010/04/06/rake-tutorial)
* [https://www.sitepoint.com/rake-automate-things/](https://www.sitepoint.com/rake-automate-things/)
* [http://martinfowler.com/articles/rake.html](http://martinfowler.com/articles/rake.html)
* [https://robots.thoughtbot.com/test-rake-tasks-like-a-boss](https://robots.thoughtbot.com/test-rake-tasks-like-a-boss)
* [https://blog.pivotal.io/labs/labs/how-i-test-rake-tasks](https://blog.pivotal.io/labs/labs/how-i-test-rake-tasks)
* [http://carlosplusplus.github.io/blog/2014/02/01/testing-rake-tasks-with-rspec/](http://carlosplusplus.github.io/blog/2014/02/01/testing-rake-tasks-with-rspec/)
