---
title: "Rspec Perf Test"
date: 2016-10-30
categories:
---

We write tests to make sure our code works.  But how can we write tests to see if our code will perform optimally under various conditions?  We are not going to create a million records in our test DB for each automated test run.  

What we want to check is if our code is doing unnecessary work (like looping over records when the result is already known).  

It's similar to various classic interview questions (reversing stingc, etc)

How can we test for various best/worst Big O notation case scenarios using tools like Rspect?  