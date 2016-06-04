---
title: "Service objects"
date: 2016-06-03
categories:
---

I like using service objects to encapsulate business logic so my models can follow [Single Resposibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle).  The challenge is unlike regular Rails generated code I do not have pre-created structure.  

If I have Users scaffold I know what to put in my user model, controller and view.  I can extract presentation aspects (such as date formatting) to decorator.  I can use serializer for my JSON API output.  With service objects I can structure them anyway I want but "with great power comes great responsibility".  


### Usefull links
* http://code.tutsplus.com/tutorials/solid-part-1-the-single-responsibility-principle--net-36074
