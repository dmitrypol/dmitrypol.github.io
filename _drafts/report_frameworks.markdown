---
title: "Reporting frameworks"
date: 2016-06-03
categories:
---

As the amount of data we deal with grows it is important to effectively present it.  Users need to see high level summary and then drill in on specific details.

In the past when I was using .NET technologies I really liked [SQL Reporting Services](https://msdn.microsoft.com/en-us/library/ms159106.aspx).  While the reports had fairly standard look they were easy to build with WYSIwIG tols and wizards.  They also gave you features such as exporting and emailing reports right out of the box.

Unfortunately I have not been able to find such an integrated framework in Ruby world but there are lots of gems that allow you to build something much more customizable to your needs.

{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}




### Charts
This enables users to easily visualize data.

https://github.com/ankane/chartkick


### Sorting
https://github.com/bogdan/datagrid


### Filtering


### Pagination
https://github.com/amatsuda/kaminari


### Export
Even when we build highly visual and interactive dashboards users often need to dump data into Excel.

https://github.com/randym/axlsx
https://github.com/straydogstudio/axlsx_rails


#### Rake
When all you need to do is create one or few report that you run yourself and dumps data into XLSX it can be done via simple Rake tasks.  In lib/tasks/reports.rake

{% highlight ruby %}
namespace :reports do
  desc 'users joined last week'
  task users: :environment do
    # => query data
    users = User.where("created_at > ?", Time.now - 1.week)
    # => prepare output file
    output_file = "tmp/users_joined_last_week_#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.xlsx"
    package = Axlsx::Package.new
    sheet = package.workbook.add_worksheet(name: 'data')
    sheet.add_row ['First Name', 'Last Name', 'Email', 'Joined On']
    users.each do |u|
      sheet.add_row [u.first_name, u.last_name, u.email, u.created_at]
    end
    # => save and email report
    package.serialize (output_file)
  end
  desc 'another report'
  task report2: :environment do
    # code here
  end
end
{% endhighlight %}

I am using [axlsx](https://github.com/randym/axlsx) gem.  You can run this task by hand or via crontab with [whenever](https://github.com/javan/whenever) gem.  Obviously this approach is not very scalable and hard to test.  But it's great for prototyping things.

#### Service Objects

For more robust solution I like to use Service Objects for report generators.  I created folder app/services/reports (and spec/services/reports).

{% highlight ruby %}
class UserReport
  def perform
    users = User.where("created_at > ?", Time.now - 1.week)
    # same code as in the rake task above
    package.serialize (output_file)
  end
end
# add this to application.rb to load new class
config.autoload_paths += Dir[Rails.root.join('app', 'services', '{**}')]
{% endhighlight %}

But then you need to create more reports.  Let's assume you have Articles (belongs_to user) and Comments (belongs_to user and article) models.  You need reports to see which articles were published last week, articles with most comments, users sorted by the number of articles they published, etc.  There will be lots common code when it comes to saving data to file and emailing but the business logic of each query will differ.


You also want to give you users ability to execute these reports via UI so you dont't have to run bash scripts.  To do that I created ReportsController with index and create actions.

{% highlight ruby %}
# config/application.rb
config.report_types = ['users', 'articles', ...]
# routes.rb
resources :reports, only: [:index, :create]
# app/views/reports.html.erb
<% Rails.application.config.report_types.each do |rep_type| %>
  <%= link_to rep_type, "#{reports_path}?rep_type=#{rep_type}", method: 'post' %>
<% end %>
# app/controllers/
class ReportsController < ApplicationController
  def create
    result = ("#{params[:rep_type].capitalize}Report").constantize.new.perform
    redirect_to reports_path, notice: result
  end
end
{% endhighlight %}

Using [duck typing](https://en.wikipedia.org/wiki/Duck_typing) I am calling the appropriate report.  So if I add new report type I just include it in application.rb and create new service object following the naming convention.

#### Background Jobs

Some reports can take a long time to execute so will run them via background job using Sidekiq (you also can use Resque and DelayedJob).

{% highlight ruby %}
class ReportsController < ApplicationController
  def create
    # just throw it into queue and give feedback to the user
    ReportJob.perform_later(params[:rep_type], current_user.email)
    redirect_to reports_path, notice: 'you will receive your report shortly'
  end
end
# the jow now contains the logic of which report generator servic object to use
class ReportJob < ActiveJob::Base
  queue_as :default
  def perform(rep_type, user_email)
    ("#{params[:rep_type].capitalize}Report").constantize.new.perform(user_email)
  end
end
# same code as before only now you need to email results
class UserReport
  def perform(user_email)
    ...
  end
end
{% endhighlight %}


### Email notifications


#### Frequency


#### Format


### Reporting API
Often users need to extract data from your application and load it into another system.  While Excell can be viable alternative at small scale you


### Access permissions
Different users might need to be restricted from seeing sensitive reports (financial data).

### Ad hoc reports


### Data archiving

