---
title: "Decrease your dependencies"
date: 2016-11-07
categories:
---

Mike Perhaps write a great post encouraging us to [kill our dependencies](http://www.mikeperham.com/2016/02/09/kill-your-dependencies/).  His point was that sometimes it's better to use native Ruby functionality instead of complex gem that will pull its own dependencies into our applications.  

But sometimes we need those gems because they signficantly speed up our development process.  But we might not need ALL of their features.  I would like to show a few examples from our application.  

### ActiveMerchant

Last year we had to integrate with [CyberSource](http://www.cybersource.com/) for credit card processing (long story why but I assure you there is a reason).  We used [ActiveMerchant](https://github.com/activemerchant/active_merchant) and it saved us lots of time.  Except, this gem supports multiple gateways which we did not need.  So there is no need to load those specific classes.  


### Fog

[Fog](https://github.com/fog/fog) is a great library for integrating with various [cloud services](http://fog.io/about/provider_documentation.html).  We use it to upload images to [S3](https://aws.amazon.com/s3/).  But we do not need to talk to Google, Bluebox or DigitalOcean.  Fog gems uses other gems to talk to specific providers.  

Fog is required by [carrierwave](https://github.com/carrierwaveuploader/carrierwave)

gem 'fog', require: 'fog/aws/storage'
