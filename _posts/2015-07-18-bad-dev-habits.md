---
title:  "My bad development habits"
date: 2015-07-18
categories:
---

Like all developers I have some bad habits.  And even though I know they are bad, they are hard to break (like flossing teeth at night).  The purpose of making this list was almost like therapy, to get me to change these habits.  Here are some of them:

**Very large methods**.  As a good rule of thumb I know that method should be 5-10 lines of code.  Yet I have some that are over 20.  Why?  It starts simple but then business logic creeps in and it's hard to break things up, especially when you need to ship that day.

**Very large classes**.  Similar problem to the one above.  I know I should limit them to 100-200 lines but with MVC "skinny controllers fat models" can lead to "morbidly obese models".  A few months ago I started using Service Objects and Decorators as a way to lighten up the models.  And I really like it.  It forces me to put things in smaller buckets, it forces to me create some base classes to store common code and then inherit from them.

**Lots of commented out code**.  You know how when you refactor it's tempting to leave the code behind (just in case) but to make sure it does not get executed you comment it out.  Except it's still sitting in your repo six months later.  You grep through your code and you find references to entire classes just commented out.  At least when it's your own code you can probably remember that you don't need it.

**Class methods vs instance methods**.  It's just so tempting to do self.method_name.  No need to thinking about properly instantiating the object and passing the right params in.  And pretty soon you are passing in the same params over and over to different methods.

So what else am I doing to change these bad habits (besides writing this post)?  I have implemented some code analyzer tools.  Here is a good list of [resources](https://infinum.co/the-capsized-eight/articles/top-8-tools-for-ruby-on-rails-code-optimization-and-cleanup).  You can also signup for service like [https://codeclimate.com/](https://codeclimate.com/).