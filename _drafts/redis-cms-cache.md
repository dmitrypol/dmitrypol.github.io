---
title: "Redis as CMS cache"
date: 2016-09-21
categories: redis
---

Lots of websites are built using Content Management Systems such as [Wordpress](https://wordpress.org) and [Drupal](https://www.drupal.org/project/redis).  The obvious advantage is that these sites can be built faster w/o requiring large dev teams.  Configuration changes can be implemented by power users.  But how do you scale these applications?

### Wordpress

https://www.digitalocean.com/community/tutorials/how-to-configure-redis-caching-to-speed-up-wordpress-on-ubuntu-14-04
https://wordpress.org/plugins/redis-cache/
https://wordpress.org/plugins/wp-redis/


### Drupal

https://www.drupal.org/project/redis
https://pantheon.io/docs/redis/
https://pantheon.io/blog/why-we-recommend-redis-drupal-or-wordpress-caching-backend
https://redislabs.com/drupal-redis
http://blog.markdorison.com/post/57742555038/setting-up-redis-caching-with-drupal

### Ruby on Rails CMS
https://hackhands.com/9-best-ruby-rails-content-management-systems-cms/


### Flushing cache
Web GUI vs direct command line access?  


### Hosting
There are lots of sites that enable you to host your WP site w/o setting up your own Linux or MySQL.  But how do you get them to enable Redis?  
If you are running your own server you have full control and can setup your own Redis.  
