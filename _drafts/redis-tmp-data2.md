---
title: "Storing temp data in Redis"
date: 2016-09-14
categories: redis
---

Reporting dashboards
Often you need to collect various metrics and display them in reporting dashboard.  Data might not fit into your core tables.

https://github.com/agoragames/leaderboard


Report generation:
User runs a report and you want to store the user name, report name and other parameters (such as dates).


Data import:
User imports data and you want to know the user name, file name, size, number of records and results (success or error).


Deployment history:
If you do not have a dedicated deployment system you might want to know the last revision of code, commit message, name of engineer who deployed it and time.
