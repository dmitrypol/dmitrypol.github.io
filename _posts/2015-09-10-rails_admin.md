---
title:  "RailsAdmin Custom Actions"
date: 	2015-09-10
categories:
---

RailsAdmin is a great gem and it can be extended via [custom actions](https://github.com/sferik/rails_admin/wiki/Custom-action).  But the documentation is slightly incomplete so I wanted to share my experience using it over the last couple of years.  Using these custom actions we were able to significantly extend our internal admin UI.  The look & feel is not as important as ability to quickly enable basic editing functionality.

Create lib/rails_admin/custom_actions.rb
{% highlight ruby %}
module RailsAdmin
  module Config
    module Actions
      # common config for custom actions
      class Customaction < RailsAdmin::Config::Actions::Base
        register_instance_option :member do  #	this is for specific record
          true
        end
        register_instance_option :pjax? do
          false
        end
        register_instance_option :visible? do
          authorized? 		# This ensures the action only shows up for the right class
        end
      end
      class Foo < Customaction
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :only do
          # model name here
        end
        register_instance_option :link_icon do
          'fa fa-paper-plane' # use any of font-awesome icons
        end
        register_instance_option :http_methods do
          [:get, :post]
        end
        register_instance_option :controller do
          Proc.new do
            # call model.method here
            flash[:notice] = "Did custom action on #{@object.name}"
            redirect_to back_or_index
          end
        end
      end
      class Bar < Customaction
      	...
      end
      class Collection < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :collection do
          true	#	this is for all records in specific model
        end
        ...
      end
      class Root < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :root do
          true	#	this is for all records in all models
        end
        ...
      end
    end
  end
end
{% endhighlight %}

Modify rails_admin.rb initializer to load the file and actions
{% highlight ruby %}
require Rails.root.join('lib', 'rails_admin', 'custom_actions.rb')
...
config.actions do
dashboard
index
...
foo
bar
collection
root
...
end
{% endhighlight %}

Modify en.yml file
{% highlight ruby %}
  admin:
    actions:
      Foo:
        menu: 'Foo'
{% endhighlight %}

#### Create custom pages

All you have to do is in app/views/rails_admin/main create files such as root.html.haml and collection.html.haml (named after your custom actions).  They will load when you click appropriate links.

These pages can be used to display high level reports or upload data into the system (just put a form_tag pointing to appropriate controller endpoint).  Think of them as regular Rails pages but the controller code is in the custom_actions.rb.

#### Useful links

* [http://stackoverflow.com/questions/11525459/customize-rails-admin-delete-action-for-a-specific-model](http://stackoverflow.com/questions/11525459/customize-rails-admin-delete-action-for-a-specific-model)
* [http://blog.endpoint.com/2014/02/long-term-benefits-from-railsadmin.html](http://blog.endpoint.com/2014/02/long-term-benefits-from-railsadmin.html)
* [https://github.com/sferik/rails_admin/blob/master/lib/rails_admin/config/actions/base.rb](https://github.com/sferik/rails_admin/blob/master/lib/rails_admin/config/actions/base.rb)
* [http://www.slideshare.net/benoitbenezech/rails-admin-overbest-practices](http://www.slideshare.net/benoitbenezech/rails-admin-overbest-practices)