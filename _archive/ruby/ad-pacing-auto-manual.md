---
title: "Ad Pacing Auto Manual"
date: 2016-11-21
categories:
---

In advertising there is a concept of [ad pacing](https://developers.facebook.com/docs/marketing-api/pacing).  

{% highlight ruby %}
# app/models/ad.rb
class Ad
  field :title,           type: String
  field :body,            type: String
  field :link,            type: String
  field :pacing_percent,  type: Integer,  default: 100
  field :cpc,             type: Money
  field :daily_budget,    type: Money
  field :remain_budget,   type: Money
  validates :pacing_percent,  numericality: { greater_than_or_equal_to: 1,
    less_than_or_equal_to: 100 }
end
{% endhighlight %}

We assume that ad should be shown all the time.  If we want to slow down how often ad is shown (and how fast we spend the budget) we can set it to specific percentage.  

Here is the basic algorithm logic to decide whether to show ad or not:

{% highlight ruby %}
rand = Random.rand(1..100)
if rand < ad.pacing_percent
  # show the ad
end
{% endhighlight %}

This approach requires human to manually set the pacing_percent value.  And that is how we implemented this logic on an ad platform that I worked on at previous job.  

But what if wanted to make the system smarter so it woudl automatically adjust the pacing to provide relatively even spend througout the day?  We want to run a periodic process that compares `daily_budget` to `remain_budget`.  If we are spending money too fast, the `pacing_percent` is decreased.  If too slow, then `pacing_percent` is increased.  

{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
