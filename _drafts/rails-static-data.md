---
title: "Rails and static data"
date: 2016-10-29
categories: rails
---

Usually in our Rails application the data is stored in DB.  We use controllers and models to read and write it.  But sometimes that data is so static it does not make sense to put it in DB.  

You might have several roles (admin, editor, author).  They can be stored as config values in application.rb (or dev.rb, test.rb, prod.rb)

https://github.com/ledermann/rails-settings
https://github.com/railsconfig/config


But sometimes the amount of data is pretty large.  For example, you need to store the list of all zip codes in US.  Why not create `data` folder in root and appropriate subfolder structure in it.  You can put JSON, YML or CSV files.  


{% highlight ruby %}
# app/services/my_class.rb
class MyClass
  def perform
    csv_text = File.read('data/my_file.csv')
    csv = CSV.parse(csv_text, headers: false)
    csv.each do |row|
    end
  end
end
{% endhighlight %}



{% highlight ruby %}

{% endhighlight %}

