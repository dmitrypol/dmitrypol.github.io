---
title: "Roles and Permissions - switching from CanCanCan to Pundit"
date: 2016-09-22
categories:
---

Recently we switched our application from [CanCanCan](https://github.com/CanCanCommunity/cancancan) to [pundit](https://github.com/elabs/pundit).  CanCanCan is a great gem but we outgrew it.  Here are the various lessons learned.

First, it's important to acknowlege that CanCanCan is very easy to get started with and has great integrations with [RailsAdmin](https://github.com/sferik/rails_admin), [Devise](https://github.com/plataformatec/devise) and other gems.  All permissions are defined in `ability.rb` but with time this file can grow quite large.  Other downsides are inability to define field level permissions and unit testing role permissions separately from other code.  

Pundit separates permissions into individual policy classes which can inherit from each other.  So you treat them as POROs with methods.  

* TOC
{:toc}

### Grouping policies
Frequently you have lots of models that need to share the same permsisions.  So you might not want to create policy files to each model and duplicate code.  Since your policy files are just Ruby classes you can do this:

{% highlight ruby %}
class ApplicationPolicy
  # define common permissions here
end
class UserPolicy < ApplicationPolicy
  # customize permissions for various methods index?, show?, etc
  # call super if needed
end
class CommonPolicy < ApplicationPolicy
  ...
end
{% endhighlight %}

Your models may look like this. I am using [Mongoid](https://github.com/mongodb/mongoid) but the same design would work with ActiveRecord.  
{% highlight ruby %}
class User
  belongs_to :client
  # will automatically use UserPolicy
end
class Client
  has_many :accounts
  has_many :users
  def self.policy_class
    CommonPolicy # manuall specify policy
  end
end
class Account
  belongs_to :client
  def self.policy_class
    CommonPolicy
  end
end
class Company
  belongs_to :client
  def self.policy_class
    CommonPolicy
  end
end
{% endhighlight %}

Alternatively you could create separate policies for Client, Account and Company and then you would not need to do  `self.policy_class`.  You also could specify more granular permissions for Client, Account and Company models if needed.  
{% highlight ruby %}
class ClientPolicy < CommonPolicy
  ...
end
class AccountPolicy < CommonPolicy
  ...
end
class CompanyPolicy < CommonPolicy
  ...
end
{% endhighlight %}

### Mapping roles to permissions

Users can belong to one or more clients and same user can have different roles for various clients.
{% highlight ruby %}
class User
  has_many :user_clients
end
class Client
  has_many :user_clients
end
class UserClient
  belongs_to :client
  belongs_to :user
  field :roles, type: Array
  extend Enumerize
  enumerize :roles, in: [:admin, :readonly_admin, :account_admin, :company_admin],
  multiple: true  
end
class UserClientPolicy < ApplicationPolicy
  ...
end
{% endhighlight %}

`admin` can do anything for client (including granting roles to other users).  `readonly_admin` can only view all records, `account_admin` can create/edit/delete accounts and `company_admin` can do the same for company records.  For this we needed to create separate policies for Client, Account and Company models.  

Additionally there are system wide roles (for internal users) defined directly on User model.  Only internal users can create/destroy create new clients but Client Admins can modify Client attributes.
{% highlight ruby %}
class User
  extend Enumerize
  enumerize :roles, in: [:sysadmin, :acnt_mngr], multiple: true  
end
{% endhighlight %}

This will give access to internal users to all records
{% highlight ruby %}
  class ApplicationPolicy
    def index?
      return true if @user.roles.include? ['sysadmin', 'acnt_mngr']
    end
    def show?
      index?
    end
    def update?
      index?
    end
    def edit?
      index?
    end
    def create?
      # must have higher level permissions
      return true if @user.roles.include? ['sysadmin']
    end
    def new?
      create?
    end
    def destroy?
      create?
    end
  end
{% endhighlight %}

This will give readonly access to Client records via `index` and `show` to `admin` and `readonly_admin` and edit/update access to other roles.  
{% highlight ruby %}  
  class ClientPolicy
    def index?
      return true if @user.user_clients.where(client: @record)
      .in(roles: ['admin', 'readonly_admin']).count > 0
      super
    end
    def show?
      index?
    end
    def edit?
      return true if @user.user_clients.where(client: @record)
      .in(roles: ['admin']).count > 0      
      super
    end
    def update?
      edit?
    end
    #  new?, create? and destroy? are not set so it uses ApplicationPolicy
  end
{% endhighlight %}  

Permissions for Account and Company are a little different.
{% highlight ruby %}  
  class AccountPolicy
    def index?
      return true if @user.user_clients.where(client: @record.client)
      .in(roles: ['admin', 'readonly_admin', 'account_admin']).count > 0    
      super
    end
    def show?
      index?
    end
    def edit?
      return true if @user.user_clients.where(client: @record.client)
      .in(roles: ['admin', 'account_admin']).count > 0    
      super
    end
    def update?
      edit?
      # same checks for new?, create? and destroy?
    end
  end
  class CompanyPolicy
    # similar checks using 'company_admin' role instead of 'account_admin'
  end  
{% endhighlight %}

Checking for `@user.user_clients.where(client: @record.client).in(roles: ...)` is not DRY so we can extract it into separate class.

{% highlight ruby %}
# app/service/role_check.rb
class RoleCheck
  def initialize user:, client:, roles: nil
    @user = user
    @client = client
    @roles = roles
  end
  def perform
    roles2 = [:admin, @roles].flatten
    return true if @client.user_clients.where(user_id: @user.id)
      .in(roles: roles2).count > 0
  end
end
#
class AccountPolicy
  def index?
    RoleCheck.new(user: user, client: @record.client,
      roles: [:account_admin, :readonly_admin]).perform
  end
end
{% endhighlight %}

You also could use [Rolify](https://github.com/RolifyCommunity/rolify) gem to map users to roles but we already had UserClient model for other reasons so we leveraged that.  

### Beyond REST actions

You start with `:index?`, `:show?`, etc but then you need to define more custom permissions.  Let's say user has to be `admin` to `activate?` an `account`.

{% highlight ruby %}
class AccountPolicy
  def activate?
    # no need to pass admin as RoleCheck automatically includes it
    RoleCheck.new(user: user, client: @record.client).perform
  end
end
{% endhighlight %}

These kinds of custom actions will usually be specific to only one model but if they are common to several you could push them into lower policy class and inherit from it in the model specific policy.  

### Require authorize in application controller for all actions
I personally prefer to require authorize for all controller actions even I put `def index?   true; end` to give everyone access.

{% highlight ruby %}
class AccountsController < ApplicationController
  after_action except: [:index] { authorize @account }
  after_action only:   [:index] { authorize @accounts }
end
{% endhighlight %}


### Field level permissions
Sometimes you need to define permissiosn on specific field w/in record.  Sales reps should able to see their own commissions on each sale but NOT be able to change them no be able to see other reps commissions.  A manager should be able to see all reps commissions in his/her team and Admin might need to be able to change the commissions.
I even posted question http://stackoverflow.com/questions/34822084/field-level-permissions-using-cancancan-or-pundit



### Scopes


### Testing


### Headless policies

Make sure your policy file only contains the basic permission check.  When you run `rails g pundit:policy dashboard` it will include placeholder for `class Scope < Scope`

{% highlight ruby %}
class DashboardPolicy < Struct.new(:user, :dashboard)
  def index?
    true
  end
end
{% endhighlight %}

Otherwise you get

{% highlight ruby %}
Pundit::NotDefinedError at /dashboard
unable to find policy `DashboardPolicy` for `:dashboard`
{% endhighlight %}


https://github.com/elabs/pundit/issues/77

Let's say you have `Report_admin` that allows user to run various reports from the dashboard.  


### UI

In traditional erb/haml server generated UI you can use check recommended on Pundit wiki page.  

{% highlight ruby %}
  <% if policy(@account).update? %>
    <%= link_to "Edit account", edit_account_path(@account) %>
  <% end %>
{% endhighlight %}

But what if you are building Single Page Application?  We used [ActiveModelSerializers](https://github.com/rails-api/active_model_serializers) and dynamically added methods with `define_method`.  You could even push some of the common actions into `ApplicationSerializer`.  
{% highlight ruby %}
class AccountSerializer < ApplicationSerializer
  attributes :id, :name
  ...
  actions = [:index?, :show?, :new?, :create?, :edit?, :update?, :destroy?]
  attributes actions
  actions.each do |action|
    define_method(action) do
      policy = "#{object.class.name}Policy".constantize
      policy.new(current_user, object).send(action)
    end
  end
end
{% endhighlight %}

You controller could respond with either HTML or JSON output.  
{% highlight ruby %}
class AccountsController < ApplicationController
  def index
    @accounts = Account.all
    respond_to do |format|
      format.html
      format.json  { render  json: @accounts }
    end
    authorize @accounts
  end
end
{% endhighlight %}

Now your frontend application JS can use output from `http://localhost:3000/accounts.json` to check permissions and show/hide/disable appropriate UI controls.  

{% highlight ruby %}
[
  {
  id: "1",
  name: "account 1",
  index?: true,
  show?: true,
  new?: false,
  create?: false,
  edit?: null,
  update?: null,
  destroy?: false
  },
]
{% endhighlight %}





### More resources

http://blog.carbonfive.com/2013/10/21/migrating-to-pundit-from-cancan/
https://www.viget.com/articles/pundit-your-new-favorite-authorization-library
http://through-voidness.blogspot.com/2013/10/advanced-rails-4-authorization-with.html
https://www.sitepoint.com/straightforward-rails-authorization-with-pundit/
https://www.varvet.com/blog/simple-authorization-in-ruby-on-rails-apps/

https://github.com/sudosu/rails_admin_pundit
https://github.com/chrisalley/pundit-matchers

{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}
