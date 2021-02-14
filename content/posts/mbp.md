---
title: "Care and Feeding of a mid-2012 MacBook Pro"
date: 2021-02-13T13:52:52-05:00
draft: false
type: "posts"
---

A friend recently gave me his old mid-2012 13" MacBook Pro. He has a newer MacBook Air now, and no longer needed his older Pro. He warned me that it had become exceedingly slow, but otherwise had no problems.

For the past several years, my primary machines have been a desktop and a Surface Pro 5. While the Surface is great, and I recommend it if you have any use at all for a pen (drawing, OneNote, whiteboarding), it's definitely a tablet and not a laptop. It's a tablet that tries, I have to give it that, but the kickstand is not a replacement for a hinge. Typing on a Surface in bed is an exercise in pain. Using it in the car or on the couch are barely any better.

Long story short, it's exciting to have a usable daily driver laptop for the first time in about five years.

Being a Windows guy and being spoiled by solid state drives, the first order of business was to pull the 5400rpm spinning rust HDD and replace with an SSD. My last spare SSD had been installed in some Thinkpad and had Windows already installed. On a whim, I decided to throw the drive into the MBP without reimaging it. I did not expect it to work, but 4 restarts later, Windows seemed to have properly reconfigured itself for it's new home. The keyboard was still missing it's function keys, trackpad multitouch was entirely missing, and wifi could see my SSID but refused to actually connect. 

Thankfully, ethernet was fully operational, so I could start the search for drivers. Apple really, __really__ wants you to install Bootcamp on your MacOS partition, and use that to download the Windows driver packages onto a flash drive. That's great unless you're a guy with no MacOS partition. It took two days to find a download link for the Windows files, but [here it is](https://support.apple.com/kb/DL1720?locale=en_US). I did find a newer download link, but those drivers didn't fix the wifi, so I kept going until I found 5.1.5621, which fixed the wifi and keyboard.

The trackpad still didn't work until I installed [this](https://github.com/imbushuo/mac-precision-touchpad) third party touchpad driver. With that, 2, 3, and 4 finger multitouch all work properly in Windows.