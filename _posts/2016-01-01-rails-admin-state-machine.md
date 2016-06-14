---
title: "Using Rails Admin to implement state machine workflow UI"
date: 2016-01-01
categories:
---

Happy New Year.  As we transition from old to new I was thinking about [state machines](https://en.wikipedia.org/wiki/Finite-state_machine).  Well, not really but I thought it was a good opening for this post.

There are various processes at my job where we would benefit from actually enforcing the business rules.  Before implementing solution in production I wanted to prototype it in a standalone app.  There are several [gems](https://www.ruby-toolbox.com/categories/state_machines.html) for this but one I like is [aasm](https://github.com/aasm/aasm).  Let's say you are building a publishing system.  You have authors and editors.  Authors write article drafts and submit them.  Editors have to approve articles before they can be published.  Or editor can reject an article and it goes back to draft state.

Here is the basic model:
{% highlight ruby %}
class Article
  include Mongoid::Document
  field :title, type: String
  field :body, type: String
  ...
  field :aasm_state
  include AASM
  aasm do
    state :draft, :initial => true
    state :submitted
    state :published
    event :submit do
      transitions :from => :draft, :to => :submitted
    end
    event :approve do
      transitions :from => :submitted, :to => :published
    end
    event :reject do
      transitions :from => :submitted, :to => :draft
    end
  end
...
end
{% endhighlight %}

Rails_admin sees aasm_state field as a string and allows you to edit it anyway you want.  A simple way to restrict it is to add this to the Article model using [enumerize](https://github.com/brainspec/enumerize) gem:
{% highlight ruby %}
extend Enumerize
enumerize :aasm_state, in: aasm.states
{% endhighlight %}
Now rails_admin creates a dropdown with the list of possbile aasm states but it still allows you to set the field to any option w/o enforcing workflow.

For slightly better solution add this to Article model:
{% highlight ruby %}
rails_admin do
  include_all_fields
  field :aasm_state, :enum do
    enum do
      bindings[:object].aasm.states(:permitted => true).map(&:name)
    end
  end
end
{% endhighlight %}
This will restrict the options in the dropdown to the ones allowed for specific state of the Article.  Here is appropriate documentation for [aasm](https://github.com/aasm/aasm#inspection) and [rails_admin enum](https://github.com/sferik/rails_admin/wiki/Enumeration)

But this still does **article.update(aasm_state: 'submitted')** and what we really want to do is **article.submit**.  This way we can really put model through state transition and do things like fire callbacks.  One way to achive that is via [rails_admin custom actions](https://github.com/sferik/rails_admin/wiki/Custom-action).

Change aasm_state field to read only by replacing enum section in Article model with this:
{% highlight ruby %}
rails_admin do
  configure :aasm_state do
    read_only true
  end
end
{% endhighlight %}

Add this at the top of config/initializers/rails_admin.rb.  Alternatively you can put it in separate file and load it from rails_admin.rb
{% highlight ruby %}
module RailsAdmin
  module Config
    module Actions
      # common config for custom actions
      class Cmsaction < RailsAdmin::Config::Actions::Base
        register_instance_option :member do
          true
        end
        register_instance_option :only do
          Article
        end
        register_instance_option :visible? do
          authorized? # combine with Devise/CanCanCan or alternative auth tools
        end
        register_instance_option :controller do
          object = bindings[:object]
        end
      end
      class Submit < Cmsaction
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :visible? do
          bindings[:object].may_submit?  # this will show/hide link depending on state
        end
        register_instance_option :link_icon do
          'fa fa-location-arrow'
        end
        register_instance_option :controller do
          Proc.new do
            object.submit!
            flash[:notice] = "Submitted #{object.title}"
            redirect_to show_path
          end
        end
      end
      class Approve < Cmsaction
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :visible? do
          bindings[:object].may_approve?
        end
        register_instance_option :link_icon do
          'fa fa-thumbs-up'
        end
        register_instance_option :controller do
          Proc.new do
            object.approve!
            flash[:notice] = "Approved #{@object.title}"
            redirect_to show_path
          end
        end
      end
      class Reject < Cmsaction
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :visible? do
          bindings[:object].may_reject?
        end
        register_instance_option :link_icon do
          'fa fa-thumbs-down'
        end
        register_instance_option :controller do
          Proc.new do
            object.reject!
            flash[:notice] = "Rejected #{@object.title}"
            redirect_to show_path
          end
        end
      end
    end
  end
end
{% endhighlight %}

Enable these actions in rails_admin.rb config section:
{% highlight ruby %}
RailsAdmin.config do |config|
  config.actions do
    dashboard                     # mandatory
    ...
    submit
    approve
    reject
{% endhighlight %}

And add this to config/locales/en.yml
{% highlight ruby %}
en:
  admin:
    actions:
      submit:
        menu: 'Submit'
        ...
{% endhighlight %}

Bonus feature - use model scopes to filter articles by different states.
{% highlight ruby %}
class Article
  ...
  scope :draft,       ->{ where(aasm_state: 'draft')  }
  scope :submitted,   ->{ where(aasm_state: 'submitted')  }
  scope :published,   ->{ where(aasm_state: 'published')  }
  ...
  rails_admin do
    list do
      scopes    [nil, 'draft', 'submitted', 'published']
    end
  end
  ...
{% endhighlight %}

Now appropriate links/icons with show up depending on user's permissions and article state.  Let's say you have an author who wants to approve article draft (w/o submitting it) by hacking URL http://website.com/admin/article/article_id/approve.  You will get **AASM::InvalidTransition** error.

We now have a very functional UI and were able to build it very quickly by editing only 3 files - article.rb , rails_amdin.rb and en.yml.

There is also a [rails_admin_aasm](https://github.com/zcpdog/rails_admin_aasm) but it does not seem to be actively maintained and I wanted to have more control over certain aspects.
