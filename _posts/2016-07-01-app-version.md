---
title: "What app version are you running?"
date: 2016-07-01
categories:
---

How do you know which specific version of your code is running on each server?  Even with automated deployment tools ([chef](https://www.chef.io/), [capistrano](http://capistranorb.com/), [puppet](https://puppet.com/)) it's easy to make a mistake and deploy the wrong code.  And then you are wondering why the new feature is not working.

Sometimes you might need to deploy different versions of your code to different servers (perfromance or A/B testing).  In larger enterprises you often have dedicated deployment systems where each deploy gets recorded.  But I want to browse to a webpage w/in my app and see the git revision / commit message.  Here is one simple way do that for Rails apps.

With [capistrano workflow](http://capistranorb.com/documentation/getting-started/flow/) you can create a hook

{% highlight ruby %}
# config/deploy.rb
namespace :deploy do
  before :starting, :before_deploy
  ...
  desc 'stuff to do before deploy, clear logs and tmp'
  task :before_deploy do
    run_locally do
      with rails_env: :production do
        ...
        # => write to file git branch and commit info
        execute "git rev-parse --abbrev-ref HEAD > revision.txt"
        execute "git log --oneline -1 >> revision.txt"
      end
    end
  end
{% endhighlight %}

This will create/update this file on every deploy.  Then you simply need to display the file contents:

{% highlight ruby %}
# internal admin page:
<h3>App Git Branch and Commit</h3>
<%= File.read("#{Rails.root}/revision.txt") %>
{% endhighlight %}

Don't forget to add `revision.txt` to `.gitignore`.