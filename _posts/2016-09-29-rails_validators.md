---
title: "Rails validators"
date: 2016-09-29
categories:
---

Rails model validations are very important for ensuring data integrity.  You usually start with really simple [inline](http://edgeguides.rubyonrails.org/active_record_validations.html#presence) `validates :name, presence: true`.  

You can then implement more complex validations for inclusion, format, numericallity.  Or add conditional validations.  Eventually the logic gets too complex for one line statements and you implement `custom methods`

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
  ...
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

Now you can create `spec/validators/name_validator_spec.rb` and test it by passing different record types (user or organization).  

### Useful links
* [ActiveModel validations](https://github.com/rails/rails/blob/master/activemodel/lib/active_model/validations.rb)
* [Mongoid validations](https://mongoid.github.io/old/en/mongoid/docs/validation.html) if you are not using AR.  
