---
title:  "Speeding up automated tests"
date: 2015-06-20
categories:
---

Like many developers today I whole heartedly embrace automated tests.  Both for unit tests and more high level integration tests.  Ability to run a test suite with good (hopefully 90%) code coverage gives me a great feeling even when I make minor changes.  And it's especially important when building major features or doing significant refactoring.  

But with time your application grows and it takes longer and longer to run your test suite.  By longer I do not mean hours or days of manual testing that it would take otherwise.  But waiting over 10 minutes for test to finish just messes up your workflow.  I am done with code and ready to deploy and now I am waiting.  You could integrate with 3rd party service (like [Codeship](https://codeship.com/) or [CircleCI](https://circleci.com/)) but we've seen strange issues where tests that work on our dev machines fail on their systems.  And having tests and fail for weird reasons completely destroys the safety net that automated tests are suppose to give you.  

So how to speed up your tests?  First, do you really need to run certain tests?  I have lots of validations in my code making sure that some fields are required.  I used to test them just in case but not only was it taking time to run test, it was also taking time to maintain them.  If user.title is no longer requried, I have to change not only the model but the test as well.  I still have tests on more complex validations where I have custom methods/conditions but not on out of the box validation provided by framework.  

Second, do you need to persist data to the database?  We use [Rspec](https://github.com/rspec/rspec-rails) and [FactoryGirl](https://github.com/thoughtbot/factory_girl_rails) for mocking data.  What I find is when tests are on one model, usually I can use FactoryGirl **build** (which creates object in memory) vs **create** (which saves to DB).  If a test involves multiple models (counting total_orders for customer) I need to do **create**.  

Third, (and perhaps that's where the biggest speed gain can be achieved) do you need to make outbound API calls during your tests?  It's slow and makes it harder to simulate particular conditions where that API responds with specific data (important for testing error handling in your code). I am using [Webmock](https://github.com/bblimke/webmock) to intercept those requests and respond with standard JSON/XML that I pre-created.  There is also [VCR gem](https://github.com/vcr/vcr).  

Another interesting gem is [httplog](https://github.com/trusche/httplog).  It will record the outbound request your application makes in a log file.  If you are using client library provided by the API service provider it can be useful to see the exact content of outbound messages.  

Fourth - having smaller classes means you have smaller test suites for those classes and they execute faster.  You still want to run the entire suite when you are done with your code.