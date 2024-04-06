---
title: "Code Generation: How bad is it, really?"
date: 2024-04-06T17:09:32-04:00
draft: true
type: "posts"
description: ""
tags: ["embedded", "C", "Python", "codegen"]
---

Much has been written about the evils of code generation: it's been described as an anti-pattern, a maintenance nightmare, and a nuclear option. 

One situation where it has repeatedly proven to be a net positive is configuration management in embedded systems. 

# The status quo

Here are some snippets from a real project. This is the section of code that defines human readable names for specific pins:

```c
// hardware.h
// Pin Definitions - latX for outputs, portX for inputs

// Front Panel bitbang SPI
#define CLOCK_PIN           LATAbits.LATA6    //
#define DATA_PIN            LATAbits.LATA7    // 
#define STROBE_PIN          LATAbits.LATA3    // 

// Front Panel LEDs
#define ANT_LED             LATAbits.LATA5    // 
#define BYPASS_LED          LATAbits.LATA4    // 

#define BITBANG_PORT        LATEbits.LATE2    // 
#define FREQ_PIN            PORTEbits.RE3     // 
#define RADIO_OUT_PIN       LATAbits.LATA2    // 

#define RELAY_BUS_PIN       LATEbits.LATE0    // 
#define ANTENNA_RELAY       LATEbits.LATE1    // 

// ADC Channel Select macros
#define ADC_FWD_PIN 0
#define ADC_REV_PIN 1
```

This is the matching initializing code, which sets up all the GPIOs in the correct modes: analog vs digital, input vs output. Notice that the pin names defined in the header can barely help us, because we need to access different registers for initialization than for reading/writing.

```c
// hardware.c

void ports_init(void) {
    // Pin Analog select: 1 = analog, 0 = digital
    ANSELA = 0b00000011;
    ANSELB = 0b00000000;
    ANSELC = 0b00000000;
    ANSELD = 0b00000000;
    ANSELE = 0b00000000;

    // Pin Direction select: 1 = input, 0 = output
    TRISA = 0b00000011; // RA0 and RA1 inputs for FWD/REV
    TRISB = 0b11111111; 
    TRISC = 0b11111111;
    TRISD = 0b00000000;
    TRISE = 0b00000000; // Radio CMD and RelayBus are outs
}

void startup(void) {
    ports_init();
    
    // INITIALIZATIONS
    STROBE_PIN = 0;
    CLOCK_PIN = 0;
    RADIO_OUT_PIN = 0;
}
```

All in all, this isn't unreasonable. A lot of firmware like this exists. Handling one or two projects like this is perfectly manageable. 

But what about five?

Ten? Twenty?

# Story Time: Scaling with the status quo

Imagine it's new product time: You get a schematic for the new board from the hardware team. You look it over and it's reasonably similar to one of the projects you've already been working on. You do the obvious thing: fork the most similar project and start modifying it. Plug the new MCU pinout into `hardware.h` as pin definitions. Modify the `port_init()` function in `hardware.c`.

The code compiles. When the dev unit arrives, you upload your hex and the LEDs come on and the serial port chatters happily. Maybe there was some swearing, but overall you're satisfied, so you commit all your progress and start pulling datasheets for the other chips you're going to need to talk to.

Fast forward 3 weeks: it's time to sketch out the ADC driver for the new sensor module. Everything starts out okay, but quickly you notice that you're not getting the range of values you expect. You spend the afternoon tracing out the sensor circuit with your oscilloscope, but you can't find the cause. At five o'clock you put away your probes and head home, frustrated that you haven't found the issue yet.

The next day you turn on your computer, open your editor, and your eyes catch on a line of code:

```c
ANSELA = 0b00000011;
```

Wait, `A0` and `A1`? This product moved one of the analog inputs to `A2`! Okay, easy fix:

```c
ANSELA = 0b00000110;
```

A stupid typo. Annoyed, you recompile and upload the hex. Amazingly, the ADC works better when it's actually enabled in the GPIO registers. 

# I mean, it's one typo. What could it cost?

This is a true story. It's happened to me more times than I want to admit, and it's probably happened to you. In my experience, there are two reasons why this simple typo hits so hard:

### (Lack of a) Single Source of Truth

In the original configuration example, changing something about a pin requires making changes in multiple places in multiple files. The changes also aren't all in a standardized format. Deciding to change a pin from a digital output to an analog input could easily require 5, 6, 7 edits. It's very difficult to [make the wrong code look wrong](https://www.joelonsoftware.com/2005/05/11/making-wrong-code-look-wrong/) with this kind of setup.

### Temporal Distance

Unless you can test *every* subsystem in your processor in a single day, there's going to be some delay between when you do the inital setup and when you can start writing code that targets a given peripheral. This creates a gap between when the error happens and when it's possible to detect it. All the deep context from when you first wrote the setup code is gone, and your debugging efforts have to start from a blank page. In this situation, even simple typos can punch WAY above their weight.