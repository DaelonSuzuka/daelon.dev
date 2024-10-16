---
title: "NiceGUI Dialogs"
date: 2024-10-05T15:38:58-04:00
draft: false
description: ""
---

This post is inspired by a [reddit thread](https://old.reddit.com/r/nicegui/comments/18d0gmj/i_made_a_question_popup_with_two_buttons_i_wanted/) I responded to a while back.


Here's the solution I posted:

```py
from nicegui import ui

class AskPopup(ui.dialog):
    def __init__(self, question: str, options: list[str]):
        super().__init__(value=True)
        self.props("persistent")
        with self, ui.card():
            ui.label(question).classes("text-lg")
            with ui.row():
                for option in options:
                    ui.button(option, on_click=lambda e, o=option: self.submit(o))

async def click():
    result = await AskPopup("Do you like candy?", ["YES!", "Not really"])
    ui.notify(result)

ui.button("Click", on_click=click)
ui.run()
```