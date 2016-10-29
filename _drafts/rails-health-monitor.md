---
title: "Rails health monitoring"
date: 2016-10-21
categories: rails
---

Previous post on [/health]({% post_url 2015-02-17-prod-monitor %}).

I want to expand on these ideas

Check for primary DB connectivity
Check for secondary DB / caching - Redis / Memcache
Check background processes status - what if too many are backed up.  

https://github.com/ianheggie/health_check
https://github.com/sportngin/okcomputer
http://blog.arkency.com/2016/02/the-smart-way-to-check-health-of-a-rails-app/

Create my own gem - Rails Engine, mount route, create initializer where checks are configured

http://godrb.com/