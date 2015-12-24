---
title:  "AWS T2 instances and how to NOT run out of CPU credits"
date: 2015-08-05
categories: aws
---

When you first launch your site you are not sure of what the traffic load will be and don't want to spend too much $ on hosting.  The nice thing about AWS is you can scale up as you need by adding new instances or upgrading existing ones.  But in those early days you will often have mostly small loads with occasional spikes when you have influx of visitors or are running periodic background process.  

This is where AWS [T2 instances](https://aws.amazon.com/blogs/aws/low-cost-burstable-ec2-instances/) are very useful.  You can monitor their CPU usage via CloudWatch and get a sense of system load.  The tricky part is differentiating between the usual X% load that your instance supports from the maximum capacity it can handle depending on your CPUCreditBalance.  The article linked to above does a good job explaining how to you accumulate these credits and the max amount you can have.

To make sure you do not run out of that capacity during a particulary long spike I setup a separate CloudWatch montior on CPUCreditBalance metric.  I set mine to the equivalent of 5 hours of capacity which should give us time to respond if needed.  

Overall I really like T2 instances for their cost savings but you've got to use them with caution.  