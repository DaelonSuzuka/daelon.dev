---
title: "Python_classproperty"
date: 2024-12-21T19:18:17-05:00

description: "Quick and easy Python classproperties"
tags: [python, decorators, property, classmethod, classproperty]
---


I have occasionally desired the ergonomics of a classmethod/property. This works in Python ~3.9+, but is marked as deprecated and scheduled for removal in 3.13.

```py
class OPTIONS:
    lol = 'lol'

    @classmethod
    @property
    def lmao(self):
        return self.lol + ', lmao'
```


Apparently this only works accidentally, and there are Good and Proper Reasons:tm: for removing the ability to combine these two decorators, but if want to use a classproperty, damnit, I want a classproperty!

Enter `classproperty`:

```py
class classproperty:
    def __init__(self, func):
        self.fget = func

    def __get__(self, instance, owner):
        return self.fget(owner)


class OPTIONS:
    lol = 'lol'

    @classproperty
    def lmao(self):
        return self.lol + ', lmao'


print(OPTIONS.lol)
# >>> lol
print(OPTIONS.lmao)
# >>> lol, lmao
```

Easy.