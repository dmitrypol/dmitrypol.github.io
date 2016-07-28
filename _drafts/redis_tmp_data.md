---
title: "Storing non-permanent data in Redis"
date: 2016-07-28
categories: redis
---

Sometimes we already have an existing DB (MySQL, Postgres, etc) that we use to store information about our users and other core models for our application.  But then there is data you might want to store additional data that does not fit well into your existing tables.  And you might want to store this data for a limited about of time.


Reporting dashboards
Often you need to collect various metrics and display them in reporting dashboard.  Data might not fit into your core tables.


Report generation:
User runs a report and you want to store the user name, report name and other parameters (such as dates).


Data import:
User imports data and you want to know the user name, file name, size, number of records and results (success or error).


Deployment history:
If you do not have a dedicated deployment system you might want to know the last revision of code, commit message, name of engineer who deployed it and time.


