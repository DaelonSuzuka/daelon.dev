---
title: "Nicegui Social Previews"
date: 2024-12-03T12:10:28-05:00
draft: False
description: "Setting up Social Media Page Previews in NiceGUI Apps."
tags: [nicegui]
---

Social media and chat apps typically support thumbnail style page previews when you share a link. These previews are usually use Open Graph protocol, a format published by Facebook but adopted nearly everywhere.

Open Graph documentation: https://ogp.me

Less technical overview: https://ahrefs.com/blog/open-graph-meta-tags/

{{< alert >}}
A word of warning! Many social media sites will fetch the metadata with a web crawler running on their servers, and cache the result! This means that you can't debug your OGP previews inside Discord or Facebook chat, because it'll keep showing you the first preview that it loaded. 

I recommend using a tool like https://socialsharepreview.com to check your tags, so you don't get tricked by secret caching.
{{< /alert >}}

## OGP in NiceGUI

Supporting these page previews in NiceGUI is relatively easy, we just need to add the relevant HTML meta tags to the page head:

```py
from nicegui import ui

# call this at the top level to set the tags for your entire app
ui.add_head_html(
    """
    <meta property="og:title" content="Lol Lmao" />
    <meta property="og:description" content="lol, lmao" />
    <meta property="og:image" content="/static/lol_lmao.jpg" />
    """,
    shared=True, # shared adds this HTML to the base page template 
)

@ui.page('/somewhere')
def somewhere():
    # call this inside a page to set the tags for only that page
    # if you want page-specific previews, then do not set the global tags because
    # if multiple of one type exist, the first one will typically be used
    ui.add_head_html(
        """
        <meta property="og:title" content="Somewhere" />
        <meta property="og:description" content="somewhere" />
        <meta property="og:image" content="/static/somewhere/preview.jpg" />
        """
    )

ui.run()
```
