---
title:  "Open Source Software and Documentation"
date: 2016-03-04
categories:
---

Many of us have come across an open source library that seems to be just what we need to solve a specific problem.  Or watched a YouTube video of the project founder demoing it at a conference.  Except when we actually use the library, we hit a wall.  Or if we use it in a different way (due to custom requirements) and get cryptic error messages.  So being open source we read the code and hit even bigger wall.

It can be quite frustrating.  It's easy to think "I am a good developer, why can't I can't make sense of this".  Well, there is a difference between being a good developer and understanding specific code (it takes time to really dig in and we are all busy).  It's also much easier to blame the other developer and say "that library is not stable, we need to write our own custom code".

That's where good documentation can make a huge difference to adoption of the library.  Both overall guide (wiki pages or README) and code comments.  I was listening to podcast where Yehuda Katz was talking about how one of the first things he did was create documentation for JQuery.  He wrote XSLT parser that automatically updated the docs based on code comments.  This helped other developers understand JQuery, to use it on more projects and eventually contribute back.

It reminded me of my recent experience.  About a year ago I came across a gem that looked promising at first but I could not integrate into my application.  It also was not actively maintained.  So I wrote a custom solution.  And then I had to write more qnd more code to extend my solution.  I looked at that gem again and discovered that a new maintainer started regularly releasing updates.  I was able to integrate it much easier and  it worked for most cases.  But I do have some specific requirements.  I filed a few issues on Github and the maintainer responded with suggestions.  One of them was incorporated into the wiki.  And I am truly grateful because it really helped me.

But to be honest the wiki docs are still rough.  More specific examples for various customizations would make a huge difference for other developers who come across it.  I understand that some of the customizations I asked about might not make sense for the main use cases.  And it's best when library auto-magically detects your settings.  But getting a useful error message and the reading docs telling you how to configure things, is not too bad.

I also forked the gem because I wanted to submit a pull request.  Again, there were very few comments in the code.  And some of tests were failing.  It took me a while to really understand it and by then I lost some of my enthusiasm and desire to contribute.  I did a PR but much smaller than I originally planned.

Overall it was a really useful exercise for me to learn this library and new way solving a specific problem.  Hopefully the maintainer will accept my PR and I have a few more ideas on how to improve that gem.  It will help me at work and I don't mind sharing these features with the community.