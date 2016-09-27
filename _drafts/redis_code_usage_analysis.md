---
title: "Redis_code_usage_analysis"
date: 2016-09-26
categories: redis
---

Would you like to know how much of your code in production is actually getting used?  And how often?  When we run our tests we can use code coverage metrics (like https://github.com/colszowka/simplecov) to see which parts of our code are not tested.  

Class.method counter in Redis

Performance impact?  This needs to be selectively turned on specific classes or groups of classes.  

What do you hook into to fire each time a method is called?  before_ callback?  

Default TTL of 1 week to expire

Get the list of all classes / methods in Rails app?  Show the diff and you have classes/methods that were not called.  

This can be a great tool to see which parts of your code are used often and perhaps need to be improved for performance or test coverage.  Also, you can see which parts of your code are not exercised and perhaps those features can be removed.  
