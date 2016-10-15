---
title: "Deliver_now_later"
date: 2016-07-14
categories:
---

Finally upgrading my application to Rails 4.2 and encountered a few issues with new ActionMailer

I realized that I can simplify our bulk mailer code.  Before to avoid long running jobs (we sent out thousands of emails) we would break up emails in batches of a few hundred.  One job would query DB, get all the users who need to get email and then queue up other job (passing user_ids) that wouldd actually do the mailing.

But with deliver_later (and Sidekiq) we can just loop through all users and deliver_later on each email.  Each email will get queued up as separate job.

Do something like Sidekiq or Resque, where it does not have to be persisted to disk (like MySQL with DelayedJob)

