---
title: "Cloning records in Rails"
date: 2016-11-15
categories:
---

Sometimes we need to enable our users to clone their records instead of creatign new ones from scratch (huge time saver).  Let's imagine a system where users have many accounts.  

{% highlight ruby %}
# app/models/user.rb
class User
  has_many :accounts
end
# app/models/account.rb
class Account
  belongs_to :user
  field :name
end
{% endhighlight %}

### Clone one record

[ActiveRecord](http://apidock.com/rails/ActiveRecord/Base/clone) and [Mongoid](http://www.rubydoc.info/github/mongoid/mongoid/Mongoid/Copyable) have `clone` method which we can wrap like this.

{% highlight ruby %}
# app/models/account.rb
def clone_record
  new_record = self.clone
  new_record.name = "#{name} CLONE"
  new_record.created_at = Time.now
  new_record.updated_at = Time.now
  ...
  new_record.save!
  return new_record  
end
{% endhighlight %}

We can add more logic to `clone_record` to ensure uniqueness or transform data as needed.  For basic CRUD UI I like using [RailsAdmin](https://github.com/sferik/rails_admin).  We can create [custom action]({% post_url 2015-09-10-rails-admin %}) to call `clone_record` method.

{% highlight ruby %}
# config/initializers/rails_admin.rb
module RailsAdmin
  module Config
    module Actions
      class Clone < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :member do true end
        register_instance_option :only do [Account] end
        register_instance_option :link_icon do 'fa fa-clone' end
        register_instance_option :http_methods do [:get, :post] end
        register_instance_option :controller do
          proc do
            if request.post?
              new_obj = @object.clone_record
              flash[:notice] = "Cloned #{@object.name}."
              redirect_to show_path(id: new_obj.id)
            end
          end
        end
      end
    end
  end
end
RailsAdmin.config do |config|
  config.actions do
    dashboard
    ...
    clone
  end
end
# config/locales/en.yml
en:
  admin:
    actions:
      clone:
        title: 'Clone title'
        menu: 'Clone menu'
        breadcrumb: 'Clone breadcrumb'
# app/views/rails_admin/main/clone.html.erb
<h3><%= "Are you sure you want to clone '#{@object.name}'" %></h3>
<%= link_to 'Clone', clone_path, method: 'post', class: "btn btn-danger" %>
<%= link_to 'Cancel', show_path, class: "btn" %>
{% endhighlight %}

Making `GET` request will load the `clone` page where user can confirm or cancel the action.  This can be extended to cloning other records in the system.  Just create `clone_record` method in the respective classes and add class name to `register_instance_option :only do ...`.  

### Clone multiple records

We also might want to clone multiple records at a time.  RailsAdmin supports bulk actions such as [bulk_delete](https://github.com/sferik/rails_admin/blob/master/lib/rails_admin/config/actions/bulk_delete.rb).  

{% highlight ruby %}
# config/initializers/rails_admin.rb
module RailsAdmin
  module Config
    module Actions
      class BulkClone < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :collection do true end
        register_instance_option :bulkable? do true end          
        register_instance_option :only do [Account] end
        register_instance_option :http_methods do [:post, :get] end
        register_instance_option :controller do
          proc do
            if request.post?
              # loads the preview page
              @objects = list_entries(@model_config, :post)
              render @action.template_name
            elsif request.get?
              @objects = list_entries(@model_config, :get)
              @objects.each do |object|
                object.clone_record
              end 
              flash[:success] = "#{@model_config.label} successfully cloned."
              redirect_to back_or_index
            end
          end
        end
      end
      ...
    end
  end
end
RailsAdmin.config do |config|
  config.actions do
    dashboard
    ...
    clone
    bulk_clone
  end
end
# config/locales/en.yml
...
# app/views/rails_admin/main/bulk_clone.html.erb
...
{% endhighlight %}

The differences from before are `register_instance_option :collection do true end` and `register_instance_option :bulkable? do true end`.  Also there is `bulk_clone` UI page.  

You can configure UI labels following this [pattern](https://github.com/sferik/rails_admin/blob/master/config/locales/rails_admin.en.yml).  And here is [bulk_delete template](https://github.com/sferik/rails_admin/blob/master/app/views/rails_admin/main/bulk_delete.html.haml).  Big thanks to this [post](http://fernandomarcelo.com/2012/05/rails-admin-creating-a-custom-action/) for guidance on how to do custom bulk actions.  