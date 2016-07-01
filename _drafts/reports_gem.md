---
title: "Reports_gem"
date: 2016-06-29
categories:
---

Earlier I wrote a post about different reporting gems but lack of cohesive reporting frameworks.  Well, after many unsucessful attempts to create a useful gem I humbly announce rails_reports.

What it does is provide a template and some useful generators for creating separate report generator classes.

Folders **app/services/reports** and **app/models/reports**.

Naming convention -

app/services/reports/reporb.rb - base report class which contains the commmon functionality (saving to XLSX, emailing to the user)
all classes must end in report (UserReport, AccountReport)

app/models/reports/report_filter.rb - base report filter which allows users to save reports they want with



all classes expose `perform` method.


{% highlight ruby %}
# config/application.rb - add to this to autoload the paths
config.autoload_paths += Dir[Rails.root.join('app', 'models', '{**}')]
config.autoload_paths += Dir[Rails.root.join('app', 'services', '{**}')]
config.autoload_paths += Dir[Rails.root.join('app', 'jobs', '{**}')]
{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}


{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}
