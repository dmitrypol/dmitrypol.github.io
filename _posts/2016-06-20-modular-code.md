---
title: "Modular code structure"
date: 2016-06-20
categories:
---

More thoughts on structuring code and running it via background jobs.  This post was inspired by me trying to wrap my head around [Sandi Metz' Rules For Developers](https://robots.thoughtbot.com/sandi-metz-rules-for-developers).

Let's imagine we need to import CSV file into our DB in a Rails application.  It's easy to write a simple class with a single method (or a Rake task).

{% highlight ruby %}
# app/services/user_import.rb
class UserImport
  def perform
    CSV.parse(File.read('...'), headers: true).each do |row|
      User.create! row.to_hash
    end
  end
end
{% endhighlight %}

You can run it via `rails r UserImport.new.perform`.  But it's hard to test this code.  You need to create different CSV files with valid and invalid data.  It is also harder to scale this.  Next step is to break up into reading the file and processing each row.

{% highlight ruby %}
# app/services/user_import.rb
class UserImport
  def perform
    CSV.parse(File.read('...'), headers: true).each do |row|
      process_row row.to_hash
    end
  end
private
  def process_row row
    User.create! row
  end
end
{% endhighlight %}

You can test private method process_row with `.send` and pass various params.  But it's still going to process the records one at a time which is slow.  And what if you restart server?  So let's break up code into separate classes.

{% highlight ruby %}
# app/services/user_import.rb
class UserImport
  def perform
    CSV.parse(File.read('...'), headers: true).each do |row|
      ProcessUser.new.perform row.to_hash
    end
  end
end
# app/services/process_user.rb
class ProcessUser
  def perform row
    User.create! row
  end
end
{% endhighlight %}

Now let's wrap each service object into [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html).  You want to use something like Resque / Sidekiq / SQS so job queueing is very fast.  This will allow you to quickly queue up the jobs and process them in background parallel to each other.  Even if you completely shutdown both webserver and background job process the jobs will still be persisted.

{% highlight ruby %}
# app/jobs/user_import_job.rb
class UserImportJob < ApplicationJob
  def perform
    UserImport.new.perform
  end
end
# app/services/user_import.rb
class UserImport
  def perform
    CSV.parse(File.read('...'), headers: true).each do |row|
      ProcessUserJob.perform_later row.to_hash
    end
  end
end
# app/jobs/process_user_job.rb
class ProcessUserJob < ApplicationJob
  def perform row
    ProcessUser.perform row
  end
end
# app/services/process_user.rb
class ProcessUser
  def perform row
    User.create! row
  end
end
{% endhighlight %}

As you can see the jobs are just very thin wrappers around service objects.  But what if you don't want to have separate classes?

{% highlight ruby %}
# app/jobs/user_import_job.rb
class UserImportJob < ApplicationJob
  def perform
    process_file
  end
private
  def process_file
    CSV.parse(File.read('...'), headers: true).each do |row|
      ProcessUserJob.perform_later row.to_hash
    end
  end
end
# app/jobs/process_user_job.rb
class ProcessUserJob < ApplicationJob
  def perform row
    process_user row
  end
private
  def process_user row
    User.create! row
  end
end
{% endhighlight %}

We are back to just 2 files but the actual business logic is encapsulated in private methods which can be eaisly tested like any Ruby methods.  Here is a great [blog post](https://blog.codeship.com/know-your-sidekiq-testing-rights/).

Overall the amount of code increased from 7 lines total in first snippet to 21 but most of that code is simple class declarations and method definitions.  In real applications your business logic will be much more complex and comprise much higher % of code.  So a little bit of overhead that comes with breaking the code apart will matter much less.  However the modularity and ease of understanding / testing your code will more thay pay off.
