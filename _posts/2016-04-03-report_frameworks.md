---
title: "Reporting frameworks"
date: 2016-04-03
categories:
---

As the amount of data we deal with grows it is important to effectively present it.  Users need to see high level summary and then drill in on specific details.  It might not be glamorous but it's essential for any organization.

* TOC
{:toc}

When I used .NET technologies in the past I really liked [SQL Reporting Services](https://msdn.microsoft.com/en-us/library/ms159106.aspx).  While the reports had fairly standard look they were easy to build with WYSIWIG tols and wizards.  They also gave you features such as exporting and emailing reports right out of the box.

Unfortunately I have not been able to find such an integrated framework in Ruby world but there are lots of gems that allow you to build something much more customizable to your needs.

Let's assume our application has Users (first_name, last_name, email), Articles (title, body, belongs_to user) and Comments (body, belongs_to user and article) models.  All models have created_at and updated_at.  You might need reports such as articles published by day, articles with most comments, users sorted by the number of articles they published, etc.

### Charts

Charts help us to easily visualize data.  There are many libraries out there but I like the simplicity of [chartkick](https://github.com/ankane/chartkick) with [Google Charts API](https://developers.google.com/chart/).

{% highlight ruby %}
# app/views/articles/index.html.erb
<%= line_chart Article.group_by_day(:created_at).count %>
{% endhighlight %}

Instead of putting business logic in our View layer I perfer to do this:

{% highlight ruby %}
# app/views/articles/index.html.erb
<%= line_chart(ChartData.new.get_artciles_by_day) %>
# app/services/chart_data.rb
class ChartData
  def get_artciles_by_day
    # chartkick can pass data as Hash or Array
  end
end
{% endhighlight %}
This allows you to build much more complex logic for gathering your data and test it w/in your Ruby classes.  If you don't like service objects you could put it in your models or decorators.  Chartkick and Google Charts support many other chart types and configuration options, read their docs for more details.

### Sorting / Filtering / Pagination

If you are not too particular about how the page looks, [Jquery DataTables](https://github.com/DataTables/DataTables) gives you a lot right of the box.  Here is a [RailsCast episode](http://railscasts.com/episodes/340-datatables).

If you need more control over the presentation then you could build a custom form with `form_tag` and modify index action to accept additional parameters.

{% highlight ruby %}
# app/views/users/index.html.erb
<%= form_tag(users_path, method: :get) %>
  <%= date_field_tag 'created_at', required: 'required' %>
  <%= submit_tag %>
<% end %>
class UsersController < ApplicationController
  def index
    # check for additonal filtering parameters
    if params[:created_at].present?
      @users = User.where("created_at > ?", params[:created_at])
    else
      @users = User.all
    end
  end
end
{% endhighlight %}

Another interesting gem is [datagrid](https://github.com/bogdan/datagrid) but I haven't done much with it.  For pagination I usually use [kaminari](https://github.com/amatsuda/kaminari).  It works with many ORMs and is highly configurable.

### Export
Even when we build highly visual and interactive dashboards users still need to export records into Excel.

#### Rake
When all you need is a basic report to dump data into XLSX it can be done via simple Rake task.  Create lib/tasks/reports.rake

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

I am using [axlsx](https://github.com/randym/axlsx) and [axlsx_rails](https://github.com/straydogstudio/axlsx_rails) gems.  You can run this task on demand or via crontab with [whenever](https://github.com/javan/whenever) gem.  Obviously this approach is not very scalable and hard to test.  But it's great for prototyping things.

#### Service Objects

For more robust solution I like to use Service Objects for report generators.  I create folders **app/services/reports** and **spec/services/reports**.

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

But then you need to create more reports.  There will be lots of common code when it comes to saving and emailing files but the business logic of each query will differ.  Object oriented programming to the rescue.

{% highlight ruby %}
class BaseReport
  def initialize
    @output_file = "tmp/#{self.class.name}_#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}.xlsx"
  end
  def email_file
  end
  def archive_file_to_S3
  end
  ...
end
class UserReport < BaseReport
  def initialize
    super
  end
  def perform
    # report specific biz logic here
    email_file
    archive_file_to_S3
  end
end
{% endhighlight %}
You could group BaseReport methods into before_ and after_ and use [Active Model Callbacks](http://api.rubyonrails.org/classes/ActiveModel/Callbacks.html).

You also want to give users ability to execute these reports via UI so you don't have to run bash commands.  For that I use ReportsController with index and create actions.  You can download the file with [send_data or send_file](http://api.rubyonrails.org/classes/ActionController/DataStreaming.html).

{% highlight ruby %}
# config/application.rb
config.report_types = ['users', 'articles', ...]
# routes.rb
resources :reports, only: [:index, :create]
# app/views/reports/index.html.erb
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

Using [duck typing](https://en.wikipedia.org/wiki/Duck_typing) I am calling the appropriate report.  So if I add new report type I just include it in application.rb and create new service object following the naming convention.  No need to change controller or UI.

#### Background Jobs

Some reports can take a long time to execute so we run them via background job using [Sidekiq](https://github.com/mperham/sidekiq) (or Resque or DelayedJob).

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

### Emailing reports
A nice feature is to enable users to opt-in to receive specific reports by email on periodic basis.

#### Frequency

We need a new model to store user selected reports / frequency on top of which you can build standard Rails scaffold with CRUD operations.
{% highlight ruby %}
# config/application.rb
config.report_frequency = ['daily', 'weekly', 'monthly']
config.report_types = ['users', 'articles', ...]
# app/models/user_reports.rb
class UserReports
  # Mongoid schema
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
The most common format I export data to is Excell.  For PDF you can use [prawn](https://github.com/prawnpdf/prawn).  Here is good [RailsCasts](http://railscasts.com/episodes/153-pdfs-with-prawn-revised) episode.

### Custom reports
Sometimes you have large customers that have unique data requirements that cannot be satisfied with the common reports.  As much as it pains to write custom code, sometimes we need to do it.  The important thing is to keep it separate from your main codebase.

I usually create folders such as **app/services/custom/** and **app/jobs/custom/** and place my code there.  You can build these one-off reports quickly and email the files (have your customers create email distribution lists so they can add/remove recipients).

To expose these reports via UI you can create a config file to map which reports can be seen by whom.
{% highlight ruby %}
# config/initializers/custom_reports.rb
CUSTOM_REPORTS_MAP = {
  'customer1_id' => ['customer1_report1'],
  'customer2_id' => ['customer2_report1', 'customer2_report2'],
}
# app/services/custom/custom_reports_map.rb
class CustomReportsMap
  def get_reports current_user
    # get current_user.customer_id and find list of reports in CUSTOM_REPORTS_MAP
  end
end
# app/views/reports/index.html.erb
<% CustomReportsMap.get_reports(current_user).each do |rep_type|) %>
  <%= link_to rep_type, "#{reports_path}?rep_type=#{rep_type}", method: 'post' %>
<% end %>
end
{% endhighlight %}
ReportsController code will use duck_typing to run the appropriate class.  I have never actually implemented such solution in production so there are might be better ideas out there.

### Access permissions

Different users might need to be restricted from seeing sensitive reports (financial data).  You can use [cancancan](https://github.com/CanCanCommunity/cancancan) to define permissions like this:

{% highlight ruby %}
class Ability
  include CanCan::Ability
  def initialize(user)
    if user.roles.include? :admin
      can :manage, :all
    elsif user.roles.include? :salesrep
      can :run_user_report
      cannot :run_money_report
    else
  end
end
class ReportsController < ApplicationController
  def create
    # do something like this:
    report_permission = "run_#{params[:rep_type]_report"
    if can? :"#{report_permission}"
      ReportJob.perform_later(params[:rep_type], current_user.email)
    else
      redirect_to root_path, alert: 'You are not authorized to run report'
    end
  end
end
{% endhighlight %}

For more flexible solution checkout [punding](https://github.com/elabs/pundit), less DSL and more Ruby code.

### Data pre-generation and archiving
Even with declining storage costs you eventually need to start purging some of the granular data and only retain high level summary stats.  I personally like to pre-generate data in all granularity levels upfront and then delete the more granular data sets.  Let's say we are tracking article views.

{% highlight ruby %}
class AricleViews
  # records each visit and unique IP address
  include Mongoid::Document
  include Mongoid::Timestamps::Created # no updates needed
  belongs_to :article
  field: ip, type: String
  index({created_at: 1}, {expire_after_seconds: 1.week})
end
class DailyArticleViews
  # times each article was read per day.  You can track IP separately
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  belongs_to :article
  field: day, type: Date
  field: counter, type: Integer
  index({created_at: 1}, {expire_after_seconds: 1.month})
end
class MonthlyArticleViews
  # times each article was read per month
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  belongs_to :article
  field: month, type: String
  field: year,  type: Integer
  field: counter, type: Integer
end
{% endhighlight %}
Use Mongo [TTL indexes](https://docs.mongodb.com/manual/core/index-ttl/) to expire data (no need for cron job).

Alternatively you could model data differenly using Mongo documents where each documents contains records for all dates for each article.

{% highlight ruby %}
# create records
DailyArticleViews.update_one( {article_id: article.id},
{ "$inc" => { :"#{time.to_date}" => 1 } }, :upsert => true )
# { "_id" : ObjectId("..."), "article_id" : ObjectId("..."), "2016-01-01": 1, "2016-01-02": 2, ... }
# query for records
DailyArticleViews.find(:article_id => id)
.projection(:article_id => 0, :_id => 0).first
{% endhighlight %}

Another option is to rollup details stats to daily summaries (deleting detailed stats), then convert daily to monthly (and delete daily records).  I personally find it more complex and error prone.

### Reporting API
Often users need to extract data from your application and load it into another system.  Excell can be a viable alternative at small scale but you will need a more robust solution as you grow.

Reporting APIs can be synchronous with data sent the data on the first request.  It is simpler to build but it can timeout if report generation takes too long.  Or you can create asynchronous API where client is issued a token, report generation is queued up and client needs to make second request to retrieve the data within certain time period (before file is purged).

{% highlight ruby %}
class GenerateReportController < ApplicationController
  def index
    job_id = GenerateReportJob.perform_later(params).job_id
    render json: { job_id: job_id }
  end
end
class GenereateReportJob < ActiveJob::Base
  after_perform :upload_file_to_s3
  def perform(*args)
    # query DB for data
  end
  private
  def upload_file_to_s3
    # use job_id as S3 object key
  end
end
class DownloadReportController < ApplicationController
  def index
    render json: { error: 'need to provide job_id' } unless params[:job_id].present?
    # use AWS S3 client to get file from S3
    # if file is not found respond with appropriate message
    end
  end
end
{% endhighlight %}
Here is a good blog post on using [AWS S3 Ruby SDK](https://ruby.awsblog.com/post/Tx354Y6VTZ421PJ/Downloading-Objects-from-Amazon-S3-using-the-AWS-SDK-for-Ruby).  You can delete files from S3 using [object expiration](https://aws.amazon.com/blogs/aws/amazon-s3-object-expiration/) policy.

Also I prefer to create separate URL endpoints for APIs (api.mywebsite.com vs mywebsite.com) so it can be directed to different load ballancer using DNS (eaiser to scale if needed).  You could even build API with different technology ([express](http://expressjs.com/), [sinatra](http://www.sinatrarb.com/), or [rails-api](https://github.com/rails-api/rails-api)).

Well, that's it for this post, I hope you find it useful.  All comments are welcomed.