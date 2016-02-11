---
title:  "Doing HTTP redirect with AWS Route 53"
date: 	2014-01-01
categories: aws
---

I have used several domain registration services / DNS management tools and like [AWS Route 53](https://aws.amazon.com/route53/) the best (especially if you are already running your site on AWS).  But it's missing ability to do HTTP redirect from foo.com to bar.com.  You can create CNAME record but sometimes you actually need to do real redirect.  And yes, I know that HTTP redirection is not part of DNS functionality but it's just so convinient sometimes.

The way to solve this is by creating S3 bucket

Here is more in-depth [article](http://www.holovaty.com/writing/aws-domain-redirection/) describing solution.  And here is a [StackOverflow page](http://stackoverflow.com/questions/10115799/set-up-dns-based-url-forwarding-in-amazon-route53)

But would someone at AWS please implement it as a feature of Route 53 so we don't have to do this "workaround"?