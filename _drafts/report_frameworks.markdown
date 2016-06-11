---
title: "Reporting frameworks"
date: 2016-06-03
categories:
---

As the amount of data we deal with grows it is important to effectively present it.  Users need to see high level summary and then drill in on specific details.  It might not be glamorous but it's essential to any business.

When I used .NET technologies in the past I really liked [SQL Reporting Services](https://msdn.microsoft.com/en-us/library/ms159106.aspx).  While the reports had fairly standard look they were easy to build with WYSIWIG tols and wizards.  They also gave you features such as exporting and emailing reports right out of the box.

Unfortunately I have not been able to find such an integrated framework in Ruby world but there are lots of gems that allow you to build something much more customizable to your needs.

Let's assume our application has Users (first_name, last_name, email), Articles (title, body, belongs_to user) and Comments (body, belongs_to user and article) models.  You might need reports such as articles published by day, articles with most comments, users sorted by the number of articles they published, etc.  

### Charts

Charts enable us to easily visualize data.  There are many libraries out there but I like the simplicity of [chartkick](https://github.com/ankane/chartkick) with [Google Charts API](https://developers.google.com/chart/).  

{% highlight ruby %}
# app/views/articles/index.html.erb
<%= line_chart Article.group_by_day(:created_at).count %>
{% endhighlight %}

This approach is simple but we are putting business logic in our View layer.  Instead I like to do this:

{% highlight ruby %}
# app/views/articles/index.html.erb
<%= line_chart(ChartData.new.get_artciles_by_day) %>
# app/services/chart_data.rb
class ChartData
  def get_artciles_by_day
    # chartkick allows you to pass data as Hash or Array
  end 
end
{% endhighlight %}
This allows you to build much more complex logic for gathering your data and test it w/in your Ruby classes.  If you don't like service objects you could put it in your models or decorators.  Chartkick and Google Charts support many other chart types and configuration options, read their docs for more details.  


### Sorting
https://github.com/bogdan/datagrid


### Filtering


### Pagination
https://github.com/amatsuda/kaminari


### Export
Even when we build highly visual and interactive dashboards users still need to export records into Excel.

#### Rake
When all you need is a basic report to run yourself and dump data into XLSX it can be done via simple Rake task.  Create lib/tasks/reports.rake

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
    # => save the file
    package.serialize (output_file)
  end
  desc 'another report'
  task report2: :environment do
    # code here
  end
end
{% endhighlight %}

I am using [axlsx](https://github.com/randym/axlsx) and [axlsx_rails](https://github.com/straydogstudio/axlsx_rails) gems.  You can run this task by hand or via crontab with [whenever](https://github.com/javan/whenever) gem.  Obviously this approach is not very scalable and hard to test.  But it's great for prototyping things.

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

But then you need to create more reports.  There will be lots common code when it comes to saving and emailing files but the business logic of each query will differ.  Object oriented programming to the rescue.  

{% highlight ruby %}
class BaseReport
  def create_file
    @output_file = "tmp/users_joined_last_week_#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}.xlsx"
   end
  def email_file
  end
  def archive_file_to_S3
  end
  ...
end
class UserReport < BaseReport
  def initialize
    create_file
  end
  def perform
    # report specific biz logic here
    email_file
    archive_file_to_S3
  end
end
{% endhighlight %}
You could group BaseReport methods into before and after and use [Active Model Callbacks](http://api.rubyonrails.org/classes/ActiveModel/Callbacks.html).  

You also want to give users ability to execute these reports via UI so you dont't have to run bash scripts.  To do that I created ReportsController with index and create actions.

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

[send_data or send_file](http://api.rubyonrails.org/classes/ActionController/DataStreaming.html) will download the file.  Using [duck typing](https://en.wikipedia.org/wiki/Duck_typing) I am calling the appropriate report.  So if I add new report type I just include it in application.rb and create new service object following the naming convention.  No need to change controller or UI.

#### Background Jobs

Some reports can take a long time to execute so we run them via background job using [Sidekiq](https://github.com/mperham/sidekiq) (you can use Resque or DelayedJob).

{% highlight ruby %}
class ReportsController < ApplicationController
  def create
    # just throw it into queue and give feedback to the user
    ReportJob.perform_later(params[:rep_type], current_user.email)
    redirect_to reports_path, notice: 'you will receive your report shortly'
  end
end
# the job now contains the logic of which report generator service object to use
class ReportJob < ActiveJob::Base
  queue_as :default
  def perform(rep_type, user_email)
    ("#{params[:rep_type].capitalize}Report").constantize.new.perform(user_email)
  end
end
# same code as before only now you email results
class UserReport
  def perform(user_email)
    ...
  end
end
# to keep things simple I use the same email template for all reports
# app/mailers/my_mailer.rb
class MyMailer < ApplicationMailer
  def report(user, subject, body, attachment)
    # standard ActionMailer code
  end
end
# create app/views/my_mailer/report.html.erb
{% endhighlight %}

### Email notifications
A nice feature is to enable users to receive reports by email on periodic basis.  

#### Frequency

I created a new model on top of which you can build standard Rails scaffold with CRUD operations for users/admins.  
{% highlight ruby %}
# config/application.rb
config.report_frequency = ['daily', 'weekly', 'monthly']
config.report_types = ['users', 'articles', ...]
# app/models/user_reports.rb
class UserReports
  # using Mongoid as ORM
  belongs_to :user,   index: true
  field :frequency,   type: String
  field :report_type, type: String  
  extend Enumerize
  enumerize :frequency,   in: Rails.application.config.report_frequency
  enumerize :report_type, in: Rails.application.config.report_types
end
{% endhighlight %}

Then we schedule a nightly job.  To keep things simple users receive daily reports for previous day's data, weekly reports on Monday (for previous week) and montly reports on the 1st (for previous month).

{% highlight ruby %}
# app/jobs/user_report_job.rb
class create UserReportJob < ActiveJob::Base/my_mailer/report.html.erb
  def perform()
    # query user_reports to determine reports need to be sent out to whom
    # pass appropriate date range filters to report service objects
  end
end
{% endhighlight %}
I like using [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron) to schedule the jobs but there are alternatives.  


#### Format
The most common format I had to export data to was Excell.  Sometimes you need PDF so you can use [prawn](https://github.com/prawnpdf/prawn).  Here is good [RailsCasts]*(http://railscasts.com/episodes/153-pdfs-with-prawn-revised) episode.  


### Reporting API
Often users need to extract data from your application and load it into another system.  While Excell can be viable alternative at small scale you


### Access permissions
Different users might need to be restricted from seeing sensitive reports (financial data).

### Ad hoc reports


### Data archiving






{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


