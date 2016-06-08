---
title: "Reporting frameworks"
date: 2016-06-03
categories:
---

As the amount of data we deal with grows it is important to effectively present it.  Users need to see high level summary and then drill in on specific details.

In the past when I was using .NET technologies I really liked SQL Reporting Services.  While the reports had fairly standard look they were easy to build with WYSIwIG tols and wizards.  They also gave you features such as exporting and emailing reports right out of the box.

Unfortunately I have not been able to find such an integrated framework in Ruby world but there are lots of gems that allow you to build something much more customizable to your needs.

### Charts
This enables users to easily visualize data.

https://github.com/ankane/chartkick


### Sorting
https://github.com/bogdan/datagrid


### Filtering


### Pagination
https://github.com/amatsuda/kaminari


### Export
Even when we build highly visual and interactive dashboards users often need to dump data into Excel.

https://github.com/randym/axlsx
https://github.com/straydogstudio/axlsx_rails


### Email notifications


#### Frequency


#### Format


### Reporting API
Often users need to extract data from your application and load it into another system.  While Excell can be viable alternative at small scale you


### Access permissions
Different users might need to be restricted from seeing sensitive reports (financial data).

### Ad hoc reports


### Data archiving

