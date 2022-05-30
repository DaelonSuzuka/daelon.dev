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

### Enforce trailing newlines on entire directories
This isn't fast, but it's copy/pastable and should be very portable.
```sh
find . -type f -exec sed -i -e '$a\' {} \; -print
```

### Fix ssh key permissions

```sh
find .ssh/ -type f -exec chmod 600 {} \;; find .ssh/ -type d -exec chmod 700 {} \;; find .ssh/ -type f -name "*.pub" -exec chmod 644 {} \;
```