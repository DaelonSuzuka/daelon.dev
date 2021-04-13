---
title: "Introducing Chitin"
date: 2021-04-13T15:09:59-04:00
draft: true
type: "posts"
---

One of the challenges of working on tiny embedded systems is the difficulty of inspecting and monitoring the system while it's running. It's somewhat similar to being a pediatrician: your patient is fundamentally the same as an adult, but you can ask an adult what's wrong with them.

The usual workflows for building web or desktop applications usually come with tremendous debugging capability. The entire operating system is a toolbox that helps you capture logs and control your application's environment. If your application crashes, you can almost always just kill it with the Task Manager(or htop or similar). Your OS is already monitoring CPU and RAM usage. If your kernel allows, you can install probes and traces to capture and play back every instruction your program executes. This doesn't even get into the prevalence of actual program debuggers like GDB that let you watch your program execute line-by-line.

Larger microcontrollers do support in-situ debugging over JTAG or SWD, but not all projects can or do use chips that big. Personally, I enjoy using Microchip PIC18s, most recently the [Q43 Family](https://www.microchip.com/en-us/products/microcontrollers-and-microprocessors/8-bit-mcus/pic-mcus/pic18-q43). The one I use most is the [PIC18F57Q43](https://www.microchip.com/wwwproducts/en/PIC18F57Q43). 

PIC18F57Q43 Specs:
- 16MHz CPU
- 8KB of RAM
- 128KB of flash
- 1KB of EEPROM

Random desktop in my house:
- 3.1 GHz, quad core CPU
- 16GB of RAM
- 120GB SSH
- 1TB HDD