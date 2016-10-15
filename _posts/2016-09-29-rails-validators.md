---
title: "Rails validators"
date: 2016-09-29
categories:
redirect_from:
  - 2016/09/29/rails_validators.html
---

Rails model validations are very important for ensuring data integrity.  You usually start with really simple [inline](http://edgeguides.rubyonrails.org/active_record_validations.html#presence) `validates :name, presence: true`.  

You can then implement more complex validations for inclusion, format, numericallity.  Or add conditional validations.  Eventually the logic gets too complex for one line statements and you write [custom methods](http://guides.rubyonrails.org/active_record_validations.html#custom-methods)

{% highlight ruby %}
class User < ApplicationRecord
  validate :valid_user, on: :create
private
  def valid_user
    errors.add(:base, "is not valid") if ... # add biz logic here
  end
end
{% endhighlight %}

But then you encounter a situation where you need to perform the same validations in two different models.  

{% highlight ruby %}
# app/models/user.rb
class NameValidator < ActiveModel::Validator
  def validate(record)
    unless record.name.starts_with? 'X'
      record.errors[:name] << 'Need a name starting with X please!'
    end
  end
end
class User < ApplicationRecord
  validates_with NameValidator
  ...
end
# app/models/organization.rb
class Organization < ApplicationRecord
  validates_with User::NameValidator
  ...
end
{% endhighlight %}

However, you will get these warnings in your logs:

{% highlight ruby %}
App 1206 stderr: .../app/models/organization.rb:43: warning: toplevel constant
NameValidator referenced by User::NameValidator
{% endhighlight %}

Plus this approach is just not very clean.  Instead, why not create a app/validators folder and put the class there?  

{% highlight ruby %}
# app/validators/name_validator.rb
class NameValidator < ActiveModel::Validator
  def validate(record)
    @record = record
    # => call appropriate method to do validation based on record type
    send(record.class.name.downcase)
  end
private
  def user
    unless @record.name.starts_with? 'X'
      @record.errors[:name] << 'Need a name starting with X please!'
    end
  end
  def organization
    # could be slightly different validation
  end  
end
# app/models/user.rb
class User < ApplicationRecord
  validates_with NameValidator
  ...
end
# app/models/organization.rb
class Organization < ApplicationRecord
  validates_with NameValidator
  ...
end
{% endhighlight %}

Keep in mind that these validators are POROs so you could create `class AppplicationValidator < ActiveModel::Validator` to contain common logic and inherit from that.  And you can create `spec/validators/name_validator_spec.rb` and test validation by passing different record types (user or organization).  

{% highlight ruby %}
# spec/validators/name_validator_spec.rb
require 'rails_helper'
describe NameValidator, type: :validator do
  context 'user' do
    it 'valid' do
      user = build(:user, name: 'X org')
      expect(user).to be_valid
    end
    it 'invalid' do
      user = build(:user, name: 'wrong name')
      expect(user).not_to be_valid
    end
  end
  context 'organization' do
    # similar tests
  end
end
{% endhighlight %}

One useful place for custom validator class is when records can only belong to certain types of records.  Let's say we have Account that `belongs_to` Organization.  User also `belongs_to` Organization AND `has_and_belongs_to_many` Accounts.  But User cannot have Account that belongs_to different Organization than User.

{% highlight ruby %}
# app/models/
class User < ApplicationRecord
  validates_with CommonUserOrgAccount
end
class Organization < ApplicationRecord
  validates_with CommonUserOrgAccount
end
class Account < ApplicationRecord
  validates_with CommonUserOrgAccount
end
# app/validators/common_user_org_account.rb
class CommonUserOrgAccount < ActiveModel::Validator
def validate(record)
  @record = record
  # => call appropriate method to do validation based on record type
  send(record.class.name.downcase)
end
private
  def user
    # validation logic here
  end
  def organization
  end  
  def account
  end
end
# spec/validators/common_user_org_account_spec.rb
require 'rails_helper'
describe CommonUserOrgAccount, type: :validator do
  context 'user'
  context 'organization'
  context 'account'
end
{% endhighlight %}

### Useful links
* [ActiveModel validations](https://github.com/rails/rails/blob/master/activemodel/lib/active_model/validations.rb)
* [Mongoid validations](https://mongoid.github.io/old/en/mongoid/docs/validation.html) if you are not using AR.  
