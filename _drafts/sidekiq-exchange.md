---
title: "Sidekiq Exchange"
date: 2017-11-04
categories: redis sidekiq
---

In previous post I wrote about benefits of RabbitMQ exchange.  Application sends one message to exchange and RabbitMQ sends it to appropriate queues.  Executes jobs on multiple servers but only on appropriate ones.  Different than when

How can we model it with Sidekiq / Redis?

RabbitMQ bindings:

direct

fanout

topic

headers



ActiveJob


Multiple calls to Redis from application.  Use atomic transaction


https://github.com/antirez/disque
