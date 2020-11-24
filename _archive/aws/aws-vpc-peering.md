---
title: "Global infrastructure with AWS VPC inter-region peering"
date: 2018-01-08
categories: aws
---

VPC allows us isolate resources.  

Instead of setting up VPN connections setup inter-region VPC peering.  No single point of failure.  

Ad network with ad servers in different regions.  Need to communicate with primary DB in the main region.  
Usual data transfer charges apply.  

Collect click data in appropriate region
GDPR https://www.geekwire.com/2017/gdpr-geekwires-guide-new-european-data-protection-laws-impact-cloud/

https://aws.amazon.com/about-aws/whats-new/2017/11/announcing-support-for-inter-region-vpc-peering/
https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html
https://docs.aws.amazon.com/AmazonVPC/latest/PeeringGuide/Welcome.html
https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html

Sending messages to SQS from one region to another

Currently not available in all AWS regions.  
