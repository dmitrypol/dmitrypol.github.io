---
title: "Rails application validations"
date: 2016-11-23
categories:
---

http://guides.rubyonrails.org/active_record_validations.html allows to do complex validations for presence, uniqueness, numericallity, etc.  

2016-09-29-rails-validators

Performance impact of  uniqueness validations.  Requires DB query, better move to DB index.  


Another validation that requires DB query is conditional validation depending on parent record.  

If parent has something then child must have this value set.  
