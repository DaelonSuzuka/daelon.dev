---
title: "Godot Layout Helpers: Additional Exercises in Pain Reduction"
date: 2022-10-03T20:43:03-04:00
draft: false
type: "posts"
description: Small helpers that make a big difference
tags: ["godot"]
---


# The setup

Creating UI layouts in GDScript is annoying, but it doesn't have to be. Let's explore:

Consider the following snippet, that creates a dialog box, a vertical box layout, and a Label and ProgressBar.


```gdscript
var update_dialog = AcceptDialog.new()
var vbox = VBoxContainer.new()
update_dialog.add_child(vbox)
var status_label = Label.new()
vbox.add_child(status_label)
var progress_bar = ProgressBar.new()
vbox.add_child(progress_bar)
```

This is unpleasant for a number of reasons, but the most important one is that you can't just read it from top to bottom. Every other line diverts your attention back up the page. Nearly as bad, almost half the lines are just layout boilerplate, and don't really say anything valuable.

Simply put, the signal-to-noise ratio of this 7 line snippet is awful.


# The better way

This snippet uses a helper class to simplify the layout code, reduce boilerplate, and prevent your flow from being interrupted by removing most of the backtracking. This version can be read from top to bottom in one shot.


```gdscript
var update_dialog = AcceptDialog.new()
var vbox = VBox.new(update_dialog)
var status_label = vbox.add(Label.new())
var progress_bar = vbox.add(ProgressBar.new())
```

# The explanation

This class is 7 lines long, do I really need to explain it?


```gdscript
class VBox extends VBoxContainer:
    func _init(parent=null):
        if parent:
            parent.add_child(self)

    func add(object):
        add_child(object)
        return object
```

Okay, fine, there are some subtleties:

- This is a `class`, intended to be copied into some other script. I did this to avoid polluting the global class namespace and creating changes in `project.godot`.
- The name `VBox` was chosen because it's shorter and thus produces shorter code.
- The `_init()` method's `parent` argument is optional, so you can still use it the normal way.

(Do I have to point out that if you want the horizontal version, just change two `V`s to `H`s?)
