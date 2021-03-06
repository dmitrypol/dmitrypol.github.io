---
title:  "Importing LOTS of data"
date: 2015-11-28
categories:
---

Often you have to enable users to load large amounts of records into your application (usually from spreadsheets).  So you build a few methods on your models, create controller end points and basic upload forms.  With model validations your code is fairly clean and works great.  Except then users start loading very large amounts of data (many thousand of records).  And they sit there waiting for controller response.

One simple solution is to output results into another spreadsheet.  Records that import successfully go into "success" tab, records that fail go into "errors" tab.  Your process can even save the file periodically on the server and when finished it will email results to the user who inititated the upload.  User then fixes the errors and reuploads the new file.  This approach works up to a point.  You are still processing only one record at a time.  And what if you need to restart the application?  You have to start upload from the beginning manually.  You also should build your code so it will not create duplicate records via some kind of unique validation (email for users).

I experimented with putting upload spreadsheet on S3 and then grabbing it from there in case of server restart (spreadsheet gets deleted once the import is complete).  But it still causes the import to begin from the first row.  What I really want is to continue the import.

Here is the solution I am working on:

* Go through the spreadsheeet and turn each row into separate import job.
* Queue them up in [Sidekiq](https://github.com/mperham/sidekiq) / [Resque](https://github.com/resque/resque) / [AWS SQS](https://aws.amazon.com/sqs/).  You want some kind of in memory solution because saving each job as a record into regular DB will take too long.
* This way controller can respond to user fairly quickly with "your import has began, you will receive results by email" message.
* Process each job and and store results in "errors" and "success" queues.
* When you are done with the last row kick off separate process to create spreadsheet based on contents of "errors" and "success" queues and email it to the user.

I will update this post once I actually implement this.
