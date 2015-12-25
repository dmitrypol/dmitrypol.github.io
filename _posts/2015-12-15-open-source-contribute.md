---
title:  "Why contribute to open source?"
date: 2015-12-15
categories:
---

Many of us use open source software to get stuff done.  Yet, few of us contribute back.  I am guilty of that.  I've done a few PRs, created 1 gem that I consider somewhat valuable, plus wrote few comments on StackOverflow (my reputation is not very high).  

So what does motiviate someone to spend a great deal of time for no pay writing software that will help others?  I think you need to be very passionate about solving specific problem (usually something you deal with at work and have in-depth understanding of).  

I think this passion and personal connection make a real difference.  Recently I was looking to integrate a new Ruby gem to help me with something.  I found two options - a more mature one where progress has slowed done and a newcomer that was being actively worked on.  However, I saw a potential flaw for my use case and created an issue on GitHub.  In fact, there were several other issues expressing similar concern.  The maintainer of the older gem responded how it's not really an problem.  Eventually someone posted a monkey patch that I implemented but it was never merged into master.  And a few weeks later the maintainer published a strongly worded post how he is tired of working w/o pay and has to focus on work and family (which I completely understand).

In contrast the maintainer of the newcomer gem responded to my GitHub issue in less than hour.  He asked me clarifying questions and said he will get back to me.  Sure enough, in a couple of weeks I got an alert that he had a branch with proposed solution.  I tested it and pointed out a different situation where his solution did not work.  He responded with fix in literally matter of minutes.  I tested it, deployed to prod and watched closely.  It worked great.  A few days later it was merged into master a new version of gem was available on RubyGems.  Wow, talk about service.  It also made me feel good that my idea helped improve this piece of software.  

Overall I want to express my deep appreciation to ALL developers who contribute to open source projects (regardless of their motivations).  And am not saying that I am ready to jump in with both feet.  But I am looking for something that I am passionate about.  One idea I had was for automated smoke test solution that integrates with your deployment tool.  Here is the skeleton [https://github.com/dmitrypol/capistrano-smoke-test](https://github.com/dmitrypol/capistrano-smoke-test).  As you can see, I have not been making much progress on it ;-).  