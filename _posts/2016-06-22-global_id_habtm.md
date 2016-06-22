---
title: "Global ID and has_and_belongs_to_many"
date: 2016-06-22
categories:
---

Recently I had to design a feature where user could save specific reports with preset filter options to make it easier to run them.  The challenge is that reports can be ran across different types of records so modeling the relations was interesting.

* TOC
{:toc}

### Separate relationships in the same class

Here is the first design I went with:

{% highlight ruby %}
class Report
  field :user
  has_and_belongs_to_many :accounts,  inverse_of: :nil
  has_and_belongs_to_many :articles,  inverse_of: :nil
  # other filter options like date range or various statuses
  field :report_type
  extend Enumerize
  enumerize :report_type, in: [:account, :artcile]
  validates :user, :report_type, presence: true
  validates :accounts, presence: true, if: Proc.new { |r| r.report_type == :account }
  validates :articles, presence: true, if: Proc.new { |r| r.report_type == :article }
end
{% endhighlight %}

When users logs into dashboard they will see their saved reports and be able to run them with one click.  Depending on report_type it will call separate classes with the actual queries for aggregating the data.  Each report can gather data for one or more accounts or articles.  And I set `inverse_of: :nil` because from Article or Account model I do not need to know which reports it's included in.

The problem is we are storing all relationship / logic in the same class / table even though account report_type will never have `:articles`.  So we have to create conditional validation.  Plus there could be other filter params specific to only some of the reports.  Overall it just feels like putting too many things in the same place.

### Single Table Inheritance

Next I created separate classes.

{% highlight ruby %}
class Report
  field :user
  validates :user, presence: true
end
class AccountReport < Report
  has_and_belongs_to_many :accounts,  inverse_of: :nil
  validates :accounts, presence: true
  # adds _type field
  # additonal params for this report
end
class ArticleReport < Report
  has_and_belongs_to_many :articles,  inverse_of: :nil
  validates :articles, presence: true
  # adds _type field
  # additonal params for this report
end
{% endhighlight %}

Here the logic is spread across appropriate classes so it's much more modular.  The challenge is from the UI you now can no longer do `Report.create(..)`.

### Polymorphic HABTM relationship with a mapping table

I previously wrote about creating [polymorphic has_and_belongs_to_many]({% post_url 2016-06-12-polymorphic_habtm %}) relationships.

{% highlight ruby %}
class Report
  field :user
  validates :user, presence: true
  has_many :report_maps
end
class ReportMap
  belongs_to :report
  belongs_to :record_type, polymorphic: true
  validates :report, :record_type, presence: true
end
class Account
  has_many :report_maps, as: :record_type
end
class Article
  has_many :report_maps, as: :record_type
end
{% endhighlight %}

Here you have to build custom validation that if `report_type == :account` then ReportMap can only belong_to Account record_type.  Plus you must have relationships from the Account or Article side.  And you first need to create Report and then ReportMap records (which are needed to actually generate data).

### GlobaldID

The solution I settled on is using [GlobalID](https://github.com/rails/globalid) where we have URIs like this `gid://MyApp/Some::Model/id`.  We can store array of these on only one side of the relationship.  It's similar to regular polymorphic relationship but you can have many of them.

{% highlight ruby %}
class Report
  field :user
  field :records, type: Array
  # { "records" : ['gid://MyApp/Article/123', 'gid://MyApp/Article/456' ], ... }
  field :report_type
  extend Enumerize
  enumerize :report_type, in: [:account, :artcile]
  validates :user, :report_type, :records, presence: true
  validate  :records_type
  #
  def get_records
    output = []
    records.each do |r| output << GlobalID::Locator.locate(r) end
    return output
  end
private
  def records_type
    case report_type
    when :account, :article
      unless get_records.map(&:model_name).uniq == [report_type.to_s.capitalize]
        errors[:base] << 'must have same record type'
      end
    end
  end
end
{% endhighlight %}

`get_records` method will return the actual objects based on their GlobalID using `GlobalID::Locator.locate` and `records_type` validation uses `model_name` to make sure they are all the same and of correct type.

You also could have a report that gathers data for both accounts and articles.  For that you need to setup different `when case` in the validator method.

As you can see all of these solutions are much more complex that usual belongs_to and has_many.  You have to create appropriate validations and test your code carefully.


### Useful links

* [https://github.com/rails/globalid](https://github.com/rails/globalid)
* [http://stefan.haflidason.com/simpler-polymorphic-selects-in-rails-4-with-global-id/](http://stefan.haflidason.com/simpler-polymorphic-selects-in-rails-4-with-global-id/)
* [http://stackoverflow.com/questions/34084140/using-global-id-to-specify-an-object-in-a-polymorphic-association](http://stackoverflow.com/questions/34084140/using-global-id-to-specify-an-object-in-a-polymorphic-association)
* [http://dev.mikamai.com/post/96343027199/rails-42-new-gems-active-job-and-global-id](http://dev.mikamai.com/post/96343027199/rails-42-new-gems-active-job-and-global-id)
