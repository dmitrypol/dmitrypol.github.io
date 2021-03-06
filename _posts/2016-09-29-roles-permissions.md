---
title: "Roles and permissions - switching from CanCanCan to Pundit"
date: 2016-09-29
categories:
redirect_from:
  - 2016/09/29/roles_permissions.html
---

Recently we switched our application from [CanCanCan](https://github.com/CanCanCommunity/cancancan) to [pundit](https://github.com/elabs/pundit).  CanCanCan is a great gem but we outgrew it.  Here are the various lessons learned.

First, it's important to acknowlege that CanCanCan is very easy to get started with and has great integrations with [RailsAdmin](https://github.com/sferik/rails_admin), [Devise](https://github.com/plataformatec/devise) and other gems.  All permissions are defined in `ability.rb` but with time this file can grow quite large.  Other downsides are inability to define field level permissions and unit testing role permissions separately from other code.  

Pundit separates permissions into individual policy classes which can inherit from each other.  So you treat them as POROs with methods.  

* TOC
{:toc}

### Grouping policies
Frequently you have lots of models that need to share the same permsisions.  So you might not want to create policy files to each model and duplicate code.  Since your policy files are just Ruby classes you can do this:

{% highlight ruby %}
# app/policies/application_policy.rb
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

Your models may look like this. We are using [Mongoid](https://github.com/mongodb/mongoid) but the same design would work with ActiveRecord.  
{% highlight ruby %}
# app/models/user.rb
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

This can be a common case with [Single Table Inhertiance](https://en.wikipedia.org/wiki/Single_Table_Inheritance).  Often the permissions for the different models derived form the same base model are the same so you could share policies.  

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

To keep things simple users can belong to only one client.

{% highlight ruby %}
class User
  has_one :user_client
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

`admin` can edit it's client record and do CRUD on client children records.  `readonly_admin` can only view all records, `account_admin` can do CRUD operations on accounts and `company_admin` can do the same for company records.  For this we needed to create separate policies for Client, Account and Company models.  

Additionally there are system wide roles (for internal users) defined directly on User model.  Only internal users can create/destroy create new clients but Client Admins can modify Client attributes.
{% highlight ruby %}
class User
  extend Enumerize
  enumerize :roles, in: [:sysadmin, :acnt_mngr], multiple: true  
end
{% endhighlight %}

This will give internal users access to all records.

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
    index?
  end
  def new?
    index?
  end
  def destroy?
    # must have higher level permissions  
    return true if @user.roles.include? ['sysadmin']
  end
end
{% endhighlight %}

So this works great for granting application wide permissions but client specific users need to be resticted more.  Additionally when we are in `show`, `update`, `edit` or `destroy` we can get client from the record.  In `index` we have multiple records and in `new` / `create` the record does not exist yet so we need to get client from user.  

{% highlight ruby %}
class User
  def get_client_id
    user_client.client_id
  end
end
class ApplicationPolicy
  def get_client_id
    # or we could just always get client from user
    return @record.client_id if @record.try(:client_id)
    return @user.get_client_id
  end
end
{% endhighlight %}

This will give readonly access to Client records via `index` and `show` to `admin` and `readonly_admin` and edit/update access to other roles.  

{% highlight ruby %}
class ClientPolicy
  def index?
    return true if @user.user_clients.where(client: get_client_id)
    .in(roles: ['admin', 'readonly_admin']).count > 0
    super
  end
  def show?
    index?
  end
  def edit?
    return true if @user.user_clients.where(client: get_client_id)
    .in(roles: ['admin']).count > 0      
    super
  end
  def update?
    edit?
  end
  #  new?, create? and destroy? are not set so it uses ApplicationPolicy
end
{% endhighlight %}  

Checking for `@user.user_clients.where(client: @record.client).in(roles: ...)` is not DRY so we can extract it into separate class.

{% highlight ruby %}
# app/services/role_check.rb
class RoleCheck
  def initialize user:, client:, roles: nil
    @user = user
    @client = client
    @roles = roles
  end
  def perform
    return true if @user.roles.include? :sysadmin
    roles2 = [:admin, @roles].flatten
    return true if @user.user_clients.in(client_id: @client)
      .in(roles: roles2).count > 0
  end
end
#
class ClientPolicy
  def index?
    RoleCheck.new(user: user, client: get_client_id,
      roles: [:client_admin, :readonly_admin]).perform
  end
end
{% endhighlight %}

Permissions for Account and Company are a little different.

{% highlight ruby %}
class AccountPolicy
  def index?
    RoleCheck.new(user: user, client: get_client_id,
      roles: [:account_admin, :readonly_admin]).perform
    super
  end
  def show?
    index?
  end
  def edit?
    RoleCheck.new(user: user, client: get_client_id,
      roles: [:account_admin]).perform
    super
  end
  def update?
    edit?
    # same checks for new?, create? and destroy?
  end
end
class CompanyPolicy
  # similar checks using 'company_admin' role
end  
{% endhighlight %}

You also could use [Rolify](https://github.com/RolifyCommunity/rolify) gem to map users to roles but we already had UserClient model for other reasons so we leveraged that.  

### Beyond RESTful actions

You start with `:index?`, `:show?`, etc but then you need to define more custom permissions.  Let's say user has to be `admin` to `activate?` an `account`.

{% highlight ruby %}
class AccountPolicy
  def activate?
    # no need to pass admin role as RoleCheck automatically includes it
    RoleCheck.new(user: user, client: @record.client).perform
  end
end
{% endhighlight %}

These kinds of custom actions will usually be specific to only one model but if they are common to several you could push them into lower policy class and inherit from it in the model specific policy.  

To check these custom permissions you could create a non-RESTful action in your AccountsController.

{% highlight ruby %}
class AccountsController < ApplicationController
  def activate
    authorize @account
    @account.update(status: 'active')
  end
end
# or to stick with traditional REST actions you create a separate controller
class Accounts::ActivateController < ApplicationController
  def update
    authorize @account
    @account.update(status: 'active')
  end
end
{% endhighlight %}

Then you just call `authorize`.

### Require authorize in application controller for all actions

I personally prefer to require authorize for all controller actions even I put `def index?   true; end` to give everyone access.

{% highlight ruby %}
class AccountsController < ApplicationController
  after_action except: [:index] { authorize @account }
  after_action only:   [:index] { authorize @accounts }
end
{% endhighlight %}

### Headless policies

Let's say you have `report_admin` role that allows user to run various reports from the dashboard.  

{% highlight ruby %}
class DashboardPolicy < Struct.new(:user, :dashboard)
  def index?
    RoleCheck.new(user: user, client: user.get_client_id,
    roles: [:report_admin]).perform  
  end
end
# somehere in the UI navbar
<%= link_to('Dashboard', dashboard_index_path) if policy(:dashboard).index? %> |
{% endhighlight %}

Make sure your policy file only contains the basic permission check.  When you run `rails g pundit:policy dashboard` it will include placeholder for `class Scope < Scope`.  Otherwise you hit this [github issue](https://github.com/elabs/pundit/issues/77).  

{% highlight ruby %}
Pundit::NotDefinedError at /dashboard
unable to find policy `DashboardPolicy` for `:dashboard`
{% endhighlight %}

### Scopes

Internal users can see all records but client specific users can see only accounts and companies scoped to that client.  

{% highlight ruby %}
class AccountPolicy < ApplicationPolicy
  ...
  class Scope < Scope
    def resolve
      if @user.roles.include? ['sysadmin', 'acnt_mngr']
        scope.all
      else
        scope.in(client_id: @user.get_client_id)
      end
    end
  end
end
{% endhighlight %}

### Field level permissions

Sometimes you need to define permissions on specific field w/in record.  Let's say that that only `sysadmin` can edit Client status field.  

{% highlight ruby %}
class ClientPolicy < ApplicationPolicy
  def permitted_attributes
    if user.roles.include? :sysadmin
      [:name, :status]
    else
      [:name]
    end
  end
end
class ClientController < ApplicationController
  def update
    if @client.update_attributes(permitted_attributes(@client))
    ...
end
{% endhighlight %}

You also want to show/hide the Status field in the Client edit page.  Just call `permitted_attributes` method.  

{% highlight ruby %}
# app/views/clients/_form.html.erb
<% if policy(@client).permitted_attributes.include? :status %>
  <div class="form-inputs">
    <%= f.input :status %>
  </div>
<% end %>
{% endhighlight %}

I am working on a better solution to use CSS **visibility** or **disabled** attributes and push the logic into decorator.  

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

Your controller responds with either HTML or JSON output.  
{% highlight ruby %}
class AccountsController < ApplicationController
  def index
    @accounts = Account.all
    respond_to do |format|
      format.html
      format.json  { render  json: @accounts }
    end
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

### Testing

Testing these policies interaction with the common `RoleCheck` code can get quite repetitive.  That's where [stubbing](https://www.relishapp.com/rspec/rspec-mocks/docs) can be a valuable tool.  This will simulate passing user, client and roles parameters to RoleCheck and returning true or nil.  

{% highlight ruby %}
# spec/policies/account_policy_spec.rb
permissions :index?, :show? do
  it 'valid' do
    rl = double('RoleCheck', perform: true)
    RoleCheck.stub(:new).with(user: user, client: client,
      roles: ['admin', 'readonly_admin']).and_return(rl)
    expect(subject).to permit(user, Account.new(client: client))
  end
  it 'invalid' do
    rl = double('RoleCheck', perform: nil)
    RoleCheck.stub(:new).with(user: user, client: client,
      roles: ['admin', 'readonly_admin']).and_return(rl)
    expect(subject).to permit(user, Account.new(client: client))
  end
end
permissions :create?, :update?, :new?, :edit?, :destroy? do
  it 'valid' do
    rl = double('RoleCheck', perform: true)
    RoleCheck.stub(:new).with(user: user, client: client,
      roles: ['admin']).and_return(rl)
    expect(subject).to permit(user, Account.new(client: client))
  end
  ...
end
{% endhighlight %}

Also checkout [pundit-matchers](https://github.com/chrisalley/pundit-matchers) gem.  

### Usefull links

* [http://blog.carbonfive.com/2013/10/21/migrating-to-pundit-from-cancan/](http://blog.carbonfive.com/2013/10/21/migrating-to-pundit-from-cancan/)
* [https://www.viget.com/articles/pundit-your-new-favorite-authorization-library](https://www.viget.com/articles/pundit-your-new-favorite-authorization-library)
* [http://through-voidness.blogspot.com/2013/10/advanced-rails-4-authorization-with.html](http://through-voidness.blogspot.com/2013/10/advanced-rails-4-authorization-with.html)
* [https://www.sitepoint.com/straightforward-rails-authorization-with-pundit/](https://www.sitepoint.com/straightforward-rails-authorization-with-pundit/)
* [https://www.varvet.com/blog/simple-authorization-in-ruby-on-rails-apps/](https://www.varvet.com/blog/simple-authorization-in-ruby-on-rails-apps/)
* [https://github.com/sudosu/rails_admin_pundit](https://github.com/sudosu/rails_admin_pundit)
