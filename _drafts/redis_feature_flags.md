---
title: "Redis and application feature flags"
date: 2016-10-14
categories: redis
---

When we implement new features sometimes we want to turn them on only for select groups of users.  Or we want to gradually increase percentage of users accessing new feature to slow perf test new code in production.  For that you need to do very quick lookups.


https://github.com/fetlife/rollout

https://github.com/jnunemaker/flipper
