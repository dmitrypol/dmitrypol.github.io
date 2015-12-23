---
title:  "My first gem"
date: 	2015-12-01
categories:
---

Small step for me, giant leap for ... nobody.  

I recently created my first official Ruby gem.  Sure, I created basic skeletons before and even pushed them to Github.  A few are still out there, waiting for me to actually finish the real logic.  

Recently we were looking to integrate with Sparkpost API for sending emails.  Unfortunately they do not have a Ruby gem client but their curl example was very helpful.  So I decided to use RestClient gem as a way to do the POST requests. But instead of putting in Ruby class I decided to actually make it into gem.  This would allow us to keep the code more modular and potentially reuse it for a different application.  

I found going through the process of building this gem to be very valuable.  I even pushed it to RubyGems so you can check out it.  
