---
title: "Scripts"
date: 2021-02-11T17:28:33-05:00
draft: false
---

Useful scripts that are too small to deserve their own project page go here.

### GNU Screen backspace fix
GNU Screen does something weird with the backspace key, and this [.screenrc](/scripts/.screenrc) fixes it for me.
```sh
bindkey -d -k kb stuff "\010"
```

