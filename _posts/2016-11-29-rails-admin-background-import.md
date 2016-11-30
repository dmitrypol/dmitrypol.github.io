---
title: "RailsAdmin background import"
date: 2016-11-29
categories: redis
---

[rails_admin_import](https://github.com/stephskardal/rails_admin_import) is a great gem allowing us to import records.  But sometimes we have to import many thousands of records and this gem does not scale well.  What we want to do is display "import has began" message to the user and queue up a background process to import records.  Here is a pattern I have been following.

This approach uses [rails_admin](https://github.com/sferik/rails_admin) [custom actions]({% post_url 2015-09-10-rails-admin %}) and [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html) with [Sidekiq](https://github.com/mperham/sidekiq) gem.  It develops on ideas I expored in this [post]({% post_url 2016-03-18-sidekiq-batches %}).  

Let's imagine a multitenant system where Users belong to multiple Clients via UserClient relationship.  We want to be able to import Users, Clients and UserClients.  

{% highlight ruby %}
# app/models/user.rb
class User
  has_many :user_clients
end
# app/models/client.rb
class Client
  has_many :user_clients
end
# app/models/user_client.rb
class UserClient
  belongs_to :user
  belongs_to :client
end
{% endhighlight %}

Create `bgimport` custom action:

{% highlight ruby %}
# config/initializers/rails_admin.rb
module RailsAdmin
  module Config
    module Actions
      class Bgimport < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :collection do  true  end
        register_instance_option :only do [User, Client, UserClient] end
        register_instance_option :link_icon do 'fa fa-upload' end
        register_instance_option :http_methods do [:get, :post] end
        register_instance_option :controller do
          proc do
            if request.get?
              # just show the page
            elsif request.post?
              record_type = params[:model_name]
              QueueImport.new.perform(params[:file], record_type)
              flash[:success] = "imporing #{record_type} records"
              redirect_to back_or_index
            end
          end
        end
      end
    end
  end
end
...
RailsAdmin.config do |config|
  config.actions do
  dashboard
  ...
  bgimport
{% endhighlight %}

We need a basic UI to upload files with data.  

{% highlight ruby %}
# app/views/rails_admin/main/bgimport.html.erb
<%= form_tag bgimport_path, multipart: true do %>
  <%= file_field_tag :file, required: "required" %>
  <%= submit_tag "Import", class: 'btn btn-primary' %>
<% end %>
{% endhighlight %}

We will be running jobs in a batch and using Redis to store job IDs:

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new(...)
REDIS_BATCH = Redis::Namespace.new(:batch, redis: REDIS)
{% endhighlight %}

Create PORO service object.  This could be moved into `Bgimport` custom action class but it's easier to test in a PORO.  It will queue up individual jobs for each row in spreadsheet.  It will use naming conventon pattern to determine which job class to call.  

{% highlight ruby %}
# app/services/queue_import.rb
class QueueImport
  def perform file, record_type
    klass = ("#{record_type.camelize}ImportJob").constantize
    batch_id = SecureRandom.uuid
    spreadsheet = CSV.read(file.path, headers:true)
    spreadsheet.size.times do |i|
      row = spreadsheet[i].to_hash
      job = klass.perform_later(row: row, batch_id: batch_id)
      REDIS_BATCH.sadd(batch_id, job.job_id)
    end
  end
end
{% endhighlight %}

Create appropriately named jobs:

{% highlight ruby %}
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
private
  def batch_tasks batch_id
    REDIS_BATCH.srem(batch_id, self.job_id)
    if REDIS_BATCH.scard(batch_id) == 0
      # do something at batch completion
      Rails.logger.info "completed batch #{batch_id} for #{self.class.name}"
    end
  end
end
# app/jobs/user_import_job.rb
class UserImportJob < ApplicationJob
  def perform(row: , batch_id:)
    # biz logic to create/update records
    batch_tasks(batch_id)
  end
end
# app/jobs/client_import_job.rb
class ClientImportJob < ApplicationJob
  def perform(row: , batch_id:)
    # biz logic to create/update records
    batch_tasks(batch_id)
  end
end
# app/jobs/user_client_import_job.rb
class UserClientImportJob < ApplicationJob
  def perform(row: , batch_id:)
    # find user
    # find client
    # create/update user_client with user_id and client_id
    batch_tasks(batch_id)
  end
end
{% endhighlight %}

This approach gives us a lot of control on how to implement biz logic specific to our application.  For example, let's say that users must have unique emails within clients.  We can query DB by those 2 params and then create or update user record. In case of `UserClient` we need to first find User and Client records (perhaps User by email and Client by name) and then create/update `UserClient` record.  

When importing large amounts of data we are likely to encounter different errors with some of the records.  We want to give users valid feedback.  I describe various options in this [post]({% post_url 2016-03-18-sidekiq-batches %})

Separately we might want to import data not via UI file upload but by downloading records from FTP / API.  We simply create another job to download the file and pass it to the QueueImport.  

{% highlight ruby %}
class UserImportFtpJob < ApplicationJob
  def perform
    Net::SFTP.start(host, username, password: password) do |sftp|
      sftp.download!("/path/to/remote", "/path/to/local")
    end  
    QueueImport.new.perform(file, 'user')
  end
end
{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}
