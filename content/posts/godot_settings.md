---
title: "Godot Editor Settings and You: An Exercise in Pain Reduction"
date: 2022-09-27T22:21:45-04:00
draft: false
---


The Godot editor has a number of absolutely boneheaded default settings. Here's my recommendations for a better overall experience:

~~Step one: Use an external text editor~~

This just saves space:

```gdresource
interface/inspector/horizontal_vector2_editing = true
```

These prevent the internal script editor from building a collection of every single script in your project:

```gdresource
interface/scene_tabs/restore_scenes_on_load = true
text_editor/files/open_dominant_script_on_scene_change = false
text_editor/files/restore_scripts_on_load = false
```

This makes the editor (attempt) to reload things like tool and plugin scripts when you change them in a real text editor.

```gdresource
text_editor/files/auto_reload_scripts_on_external_change = true
```

These stop the blasted thing from opening the internal script editor when there's an error:

```gdresource
text_editor/external/use_external_editor = true
text_editor/external/exec_path = ""
text_editor/external/exec_flags = ""
```

These apply to LSP completions when using an external editor:

```gdresource
text_editor/completion/add_type_hints = true
text_editor/completion/use_single_quotes = true
```

These improve the LSP experience a little bit:

```gdresource
network/language_server/show_native_symbols_in_editor = true
network/language_server/use_thread = true
```
