---
title: "Rails concerns"
date: 2016-10-29
categories: rails
---

By default Rails 4 and higher applications come with [concerns](http://api.rubyonrails.org/classes/ActiveSupport/Concern.html) in `app/models/concerns/*` and `app/controllers/concerns/*`.  It can be a useful place to put code that needs to be shared across classes.  It is also a way to implement [multiple inheritance](https://learnrubythehardway.org/book/ex44.html).

Here is one example:

{% highlight ruby %}
# app/models/concerns/user_team.rb
module UserTeam
  extend ActiveSupport::Concern
  included do
    field :name, type: String
    validates :name, presence: true
    validate :user_team_common_validator
  end
  def some_method
  end
private
  def user_team_common_validator
  end
end
# app/models/user.b
class User
  include UserTeam
end
# app/models/team.rb
class Team
  include UserTeam
end
{% endhighlight %}

There is no reason we need to limit this approach to only models and controllers.  Perhaps there is common logic that we want to include in several jobs.  We could place it in `ApplicationJob` from which other Job classes inherit.  Or we could put it in `app/jobs/concerns/shared_job.job` and include that module in the specific jobs as needed.

{% highlight ruby %}
# app/jobs/concerns/shared_job.rb
module SharedJob
  def method2
  end
end
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  def method1
  end
end
# app/jobs/first_job.rb
class FirstJob < ApplicationJob
  # call method1
end
# app/jobs/second_job.rb
class SecondJob < ApplicationJob
  include SharedJob
  # call method1 and method2
end
{% endhighlight %}

Same can be done with other Ruby classes such as PORO service objects.  

{% highlight ruby %}
# app/services/concerns/shared_service.rb
module SharedService
  def method1
  end
end
# app/services/service1.rb
class Service1
  include SharedService
  def perform
    # call method1
  end
end
{% endhighlight %}
