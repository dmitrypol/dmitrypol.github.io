---
title: "Redis and asynchronous microservices"
date: 2016-09-07
categories: redis
---

Previously I about creating [Microservices with Sidekiq]({% post_url 2016-02-02-microservices %}).  This artcile is an expansion on those ideas.  

Most of us are familiar with how [Google Analytics](https://www.google.com/analytics) or [Mixpanel](https://mixpanel.com) track user interactions on websites.  Or perhaps we used error notifcation services such as [Rollbar](https://rollbar.com/), [RayGun](https://raygun.com/) or [AirBrake](https://airbrake.io/).  The common pattern is to separate the system into one component that simply receives the messages and another component(s) that process the data and display it to the users.  

To demo these concepts I built a [sample app](https://github.com/dmitrypol/redis_microservices).  Requests contain user's IP, User Agent, Time of the event and URL (which sent the request).  It highly oversimplified to show the basic functionality.  

### API

It has a simple endpoint in `HomeController` that takes requests params and throws them into Redis queue using [Sidekiq](https://github.com/mperham/sidekiq).  It is built using [Rails 5 API](http://edgeguides.rubyonrails.org/api_app.html) but could be implemented with [Ruby Sinatra](http://www.sinatrarb.com/), [NodeJS]([https://nodejs.org/en/) / [Express](https://expressjs.com/) or [Python Flask](http://flask.pocoo.org/).  There is a Sidekiq implementation in [nodejs](https://www.npmjs.com/package/sidekiq) or you could build your own client to throw messages into Redis in the appropriate format.  

API is completely unaware of the main DB or any other components.  If you look inside API `ProcessRequestJob` you will see that it does not actually do anything.  It is simply an easy way queue the job with `.perform_later` call from the `HomeController`.  Sidekiq background process does not run w/in API.  

After cloning the repo you need to `cd api && bundle && rails s`.  API also contains `api.rake` tasks which makes HTTP requests to `http://localhost:3000` passing various IPs, user agents, etc.  Just run `rake api:test_requests`.  

### UI

It is build with Rails 5 / ActiveRecord / SQLite.  It uses [RailsAdmin](https://github.com/sferik/rails_admin) CRUD dashboard so you can view the `Requests` table and see how data is aggregated.  There is basic authentication / authorization with [Clearance](https://github.com/thoughtbot/clearance), [Pundit](https://github.com/elabs/pundit) and [Rolify](https://github.com/RolifyCommunity/rolify).

UI also contains the Sidekiq library that actually processes background jobs.  In true microservices design it would probably be a separate application.  `ProcessRequestJob` class contains the actual logic for grabbing parameters stored w/in each job and creating records in the main DB in `Requests` table.  

After cloning repo you need to `cd ui && bundle && rails s -p 3001`

Browse to `http://localhost:3001/` and login with admin@email.com / password.  You can then access `http://localhost:3001/admin` and `http://localhost:3001/sidekiq` (see how background jobs queue up when you run rake task).  Then run `sidekiq`.  It will process jobs and create Request records

### Design

This approach would allow us to scale API or UI separately, upgrading or replacing components as needed.  We could rewrite API endpoint in different framework, deploy it to production and do realistic A/B performance test.  

We could upgrade Redis servers or even replace Redis with a different queue such as [AWS SQS](https://aws.amazon.com/sqs/).  We would deploy the upgraded API and it will start pushing messages to the new queue.  Then we wait for old Redis queue to drain (should not take long) and deploy the new background job processor code.  As long as the message format remains the same the background job process and API will function independently.  

We could even replace our main DB (move from MySQL to Postgres).  That would require downtime for the UI while data is migrated but the API will be simply collecting data in the queue.  After migration you will need to update the DB connection string in the the background job process and start it up.  Just be careful NOT to exceed RAM needed for Redis.  

None of the ideas I described above are revolutionary.  What I like about this approach is how easy it is to integrate separate applications and quickly build a very robust and flexible system.  
