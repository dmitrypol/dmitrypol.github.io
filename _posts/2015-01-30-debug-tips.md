---
title: "Rails debugging tips and tricks"
date: 2015-01-30
categories:
---

All of us have various debugging techniques we prefer.  Some like features provided by powerfull IDEs (Visual Studio, RubyMine, Eclipse), others use vim, Sublime or Atom.

I have been using [pry](https://github.com/pry/pry) and [byebug](https://github.com/deivid-rodriguez/byebug).  But sometimes you just need/want to do **Rails.logger.debug**.  Except you development.log is chock full of other information.  So you put things like "foobar" or your first name in the log messages and search for that.

Another techniquie I recently discovered is create custom file using [multi_logger](https://github.com/lulalala/multi_logger).  You can create an initializers with **MultiLogger.add_logger('foobar')**.  Then in your code you can call **Rails.logger.foobar.debug('error message here')**.

Much easier to tail log/foobar.log and see only the messages that you care about.  Not a huge post but something I wanted to share.  As I think of more ideas I will add them here.