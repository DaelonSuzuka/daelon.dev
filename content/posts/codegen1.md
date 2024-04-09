---
title: "Code Generation Case Study: Firmware Configuration"
date: 2024-04-06T17:09:32-04:00
draft: false
type: "posts"
description: ""
tags: ["embedded", "C", "Python", "codegen"]
---

This article is part 1 in a series exploring code generation systems.

1. Case Study: Firmware Configuration
2. Case Study: Message Decoding (coming soon)

Configuration management in embedded systems is a difficult problem. The projects are often resource contrained, and the languages and tools are... not usually modern. It's rather common to have a series of products built on a common platform (same microcontroller(MCU), shared libraries), but different hardware configurations. Sharing code between projects is a valuable time/effort saver, but it's non-trivial to correctly abstract away model-specific details like the exact layout of the MCU's pins. 

## The status quo

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

## Story Time: Scaling with the status quo

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

## I mean, it's one typo, Michael. What could it cost?

This is a true story. It's happened to me more times than I want to admit, and it's probably happened to you. In my experience, there are two reasons why this simple typo hits so hard:

#### (Lack of a) Single Source of Truth

In the original configuration example, changing something about a pin requires making changes in multiple places in multiple files. The changes also aren't all in a standardized format. Deciding to change a pin from a digital output to an analog input could easily require 5, 6, 7 edits. It's very difficult to [make the wrong code look wrong](https://www.joelonsoftware.com/2005/05/11/making-wrong-code-look-wrong/) with this kind of setup.

#### Temporal Distance

Unless you can test *every* subsystem in your processor in a single day, there's going to be some delay between when you do the inital setup and when you can start writing code that targets a given peripheral. This creates a gap between when the error happens and when it's possible to detect it. All the deep context from when you first wrote the setup code is gone, and your debugging efforts have to start from a blank page. In this situation, even simple typos can punch WAY above their weight.

## There Must be a Better Way!

An ideal solution fixes the above problems, plus a few more:

- single source of truth
- solve the temporal distance issue by making wrong configurations a compiler error
- write as much of the configuration in one shot as possible
- support multiple compilation profiles (dev/release)
- good ergonomics
- powerful, flexible, and extensible

If we were writing C++, we could use templates and constexpr. Unfortunately, this project is restricted to C. The C preprocessor is deeply abusable, but even it's dark powers are limited.

What I eventually settled on was Python scripts as part of my toolchain, using a tool from Ned Batchelder called [Cog](https://nedbatchelder.com/code/cog/). Cog allows you to write Python directly in other source code, inside block comments. When you run cog on the combined source, it evaluates the contents of the cog block and inserts the output into the specified region.

```c
/*[[[cog
import cog
fnames = ['DoSomething', 'DoAnotherThing', 'DoLastThing']
for fn in fnames:
    cog.outl("void %s();" % fn)
]]]*/
void DoSomething();
void DoAnotherThing();
void DoLastThing();
//[[[end]]]
```

Cog doesn't modify the file if the output hasn't changed, so it's `make` friendly. The generated code can be mixed with handwritten code, and is checked directly into version control, so it's explorable and discoverable, and your IDE/tools can navigate it directly.

## Pin Definition Format

The following file is the custom format for pin definitions. It's designed to minimize write/edit friction and maximize reviewability. The intended usage is to reference the schematic, and match each pin on the schematic with its definition in the configuration. Any data entry errors should be trivially discoverable by stepping through the config line-by-line.

```py
class Pin:
    # possible pin functions
    tags = ['input', 'output', 'tristate', 'gpio', 'analog', 'pullup', 'button', 'pps']

    # shortcuts, common groups of functions
    button = ['input', 'gpio', 'button']
    led = ['output', 'gpio']
    uart_tx = ['output', 'pps']
    uart_rx = ['input', 'pps']
    analog_in = ['input', 'analog']

# a pin definition is:
# <pin ID>: (<pin name>, [list of pin tags])
common = {
    # port A
    'A0': ('FWD_PIN', Pin.analog_in), # use the premade tag groups
    'A1': ('REV_PIN', Pin.analog_in), # Pin.analog_in == ['input', 'analog']
    'A2': ('POWER_LED_PIN', Pin.led), # Pin.led == ['output', 'gpio']
    'A3': ('POWER_BUTTON_PIN', Pin.button),
    'A4': ('CDN_BUTTON_PIN', Pin.button),
    'A5': ('LUP_BUTTON_PIN', Pin.button),
    'A6': ('FP_CLOCK_PIN', ['output', 'gpio']), # or directly specify tags
    'A7': ('RADIO_CMD_PIN', ['output', 'gpio']),

    # port B
    'B0': None, # pins don't have to be defined
    'B1': ('ANT_LED_PIN', Pin.led),
    'B2': ('CUP_BUTTON_PIN', Pin.button),
    'B3': None,
    'B4': ('FUNC_BUTTON_PIN', Pin.button),
    'B5': ('LDN_BUTTON_PIN', Pin.button),
    'B6': None,
    'B7': None,

    # port C
    'C0': ('RELAY_CLOCK_PIN', Pin.led),
    'C1': ('RELAY_DATA_PIN', Pin.led),
    'C2': ('RELAY_STROBE_PIN', Pin.led),
    'C3': ('BYPASS_LED_PIN', Pin.relay),
    'C4': ('FP_STROBE_PIN', Pin.relay),
    'C5': ('FP_DATA_PIN', Pin.relay),
    'C6': ('USB_TX_PIN', Pin.uart_tx),
    'C7': ('USB_RX_PIN', Pin.uart_rx),

    # port E
    'E0': ('FREQ_PIN', Pin.freq),
}

# The toolchain supports development and release builds, and the following two
# pin dictionaries are merged with the common dictionary to create the full
# configuration for each mode.

# This allows for using different hardware for dev and release, driven by a single
# declarative configuration

development = {
    'D2': ('DEBUG_TX_PIN', Pin.uart_tx),
    'D3': ('DEBUG_RX_PIN', Pin.uart_rx),
    'E1': ('TUNE_BUTTON_PIN', Pin.button),
    'E2': ('ANT_BUTTON_PIN', Pin.button),
}

release = {
    'B6': ('TUNE_BUTTON_PIN', Pin.button),
    'B7': ('ANT_BUTTON_PIN', Pin.button),
}
```

## Generated Code

This is the header file `pins.h`, which is the project's central location for pin stuff.

```c
#ifndef _PINS_H_
#define _PINS_H_

#include "peripherals/pps.h"
#include <stdbool.h>

/* ************************************************************************** */
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pin_declarations()))
]]] */

// GPIO read functions
extern bool read_POWER_BUTTON_PIN(void);
extern bool read_CDN_BUTTON_PIN(void);
extern bool read_LUP_BUTTON_PIN(void);
extern bool read_CUP_BUTTON_PIN(void);
extern bool read_FUNC_BUTTON_PIN(void);
extern bool read_LDN_BUTTON_PIN(void);
extern bool read_FREQ_PIN(void);
extern bool read_TUNE_BUTTON_PIN(void);
extern bool read_ANT_BUTTON_PIN(void);

// Button stuff
#define NUMBER_OF_BUTTONS 8

// array of pointers to button reading functions
typedef bool (*button_function_t)(void);
extern button_function_t buttonFunctions[NUMBER_OF_BUTTONS];

// enum of button names
enum {
    POWER,
    CDN,
    LUP,
    CUP,
    FUNC,
    LDN,
    TUNE,
    ANT,
} button_names;

// GPIO write functions
extern void set_POWER_LED_PIN(bool value);
extern void set_FP_CLOCK_PIN(bool value);
extern void set_RADIO_CMD_PIN(bool value);
extern void set_ANT_LED_PIN(bool value);
extern void set_RELAY_CLOCK_PIN(bool value);
extern void set_RELAY_DATA_PIN(bool value);
extern void set_RELAY_STROBE_PIN(bool value);
extern void set_BYPASS_LED_PIN(bool value);
extern void set_FP_STROBE_PIN(bool value);
extern void set_FP_DATA_PIN(bool value);

// GPIO direction functions
extern void set_tris_BYPASS_LED_PIN(bool value);
extern void set_tris_FP_STROBE_PIN(bool value);
extern void set_tris_FP_DATA_PIN(bool value);

// PPS Pin initialization macros
#define PPS_USB_TX_PIN PPS_OUTPUT(C, 6)
#define PPS_USB_RX_PIN PPS_INPUT(C, 7)
#define PPS_FREQ_PIN PPS_INPUT(E, 0)
#ifdef DEVELOPMENT
    #define PPS_DEBUG_TX_PIN PPS_OUTPUT(D, 2)
#endif
#ifdef DEVELOPMENT
    #define PPS_DEBUG_RX_PIN PPS_INPUT(D, 3)
#endif

// ADC Channel Select macros
#define ADC_FWD_PIN 0
#define ADC_REV_PIN 1

// [[[end]]]

/* ************************************************************************** */

extern void pins_init(void);

#endif /* _PINS_H_ */
```

And the matching `pins.c` (long, only added for completeness):

{{< details "Expand me" >}}

```c
#include "pins.h"
#include "peripherals/pic_header.h"

/* ************************************************************************** */
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pin_definitions()))
]]] */

// GPIO read functions
bool read_POWER_BUTTON_PIN(void) { return PORTAbits.RA3; }
bool read_CDN_BUTTON_PIN(void) { return PORTAbits.RA4; }
bool read_LUP_BUTTON_PIN(void) { return PORTAbits.RA5; }
bool read_CUP_BUTTON_PIN(void) { return PORTBbits.RB2; }
bool read_FUNC_BUTTON_PIN(void) { return PORTBbits.RB4; }
bool read_LDN_BUTTON_PIN(void) { return PORTBbits.RB5; }
bool read_FREQ_PIN(void) { return PORTEbits.RE0; }
bool read_TUNE_BUTTON_PIN(void) {
#ifdef DEVELOPMENT
    return PORTEbits.RE1;
#else
    return PORTBbits.RB6;
#endif
}
bool read_ANT_BUTTON_PIN(void) {
#ifdef DEVELOPMENT
    return PORTEbits.RE2;
#else
    return PORTBbits.RB7;
#endif
}

// Button stuff
// array of pointers to button reading functions
button_function_t buttonFunctions[NUMBER_OF_BUTTONS] = {
    read_POWER_BUTTON_PIN, //
    read_CDN_BUTTON_PIN,   //
    read_LUP_BUTTON_PIN,   //
    read_CUP_BUTTON_PIN,   //
    read_FUNC_BUTTON_PIN,  //
    read_LDN_BUTTON_PIN,   //
    read_TUNE_BUTTON_PIN,  //
    read_ANT_BUTTON_PIN,   //
};

// GPIO write functions
void set_POWER_LED_PIN(bool value) { LATAbits.LATA2 = value; }
void set_FP_CLOCK_PIN(bool value) { LATAbits.LATA6 = value; }
void set_RADIO_CMD_PIN(bool value) { LATAbits.LATA7 = value; }
void set_ANT_LED_PIN(bool value) { LATBbits.LATB1 = value; }
void set_RELAY_CLOCK_PIN(bool value) { LATCbits.LATC0 = value; }
void set_RELAY_DATA_PIN(bool value) { LATCbits.LATC1 = value; }
void set_RELAY_STROBE_PIN(bool value) { LATCbits.LATC2 = value; }
void set_BYPASS_LED_PIN(bool value) { LATCbits.LATC3 = value; }
void set_FP_STROBE_PIN(bool value) { LATCbits.LATC4 = value; }
void set_FP_DATA_PIN(bool value) { LATCbits.LATC5 = value; }

// GPIO direction functions
void set_tris_BYPASS_LED_PIN(bool value) { TRISCbits.TRISC3 = value; }
void set_tris_FP_STROBE_PIN(bool value) { TRISCbits.TRISC4 = value; }
void set_tris_FP_DATA_PIN(bool value) { TRISCbits.TRISC5 = value; }

// [[[end]]]

/* ************************************************************************** */
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pins_init()))
]]] */

void pins_init(void) {
    // FWD_PIN
    TRISAbits.TRISA0 = 1;
    ANSELAbits.ANSELA0 = 1;

    // REV_PIN
    TRISAbits.TRISA1 = 1;
    ANSELAbits.ANSELA1 = 1;

    // POWER_LED_PIN
    TRISAbits.TRISA2 = 0;

    // POWER_BUTTON_PIN
    TRISAbits.TRISA3 = 1;
    WPUAbits.WPUA3 = 1;

    // CDN_BUTTON_PIN
    TRISAbits.TRISA4 = 1;
    WPUAbits.WPUA4 = 1;

    // LUP_BUTTON_PIN
    TRISAbits.TRISA5 = 1;
    WPUAbits.WPUA5 = 1;

    // FP_CLOCK_PIN
    TRISAbits.TRISA6 = 0;

    // RADIO_CMD_PIN
    TRISAbits.TRISA7 = 0;

    // ANT_LED_PIN
    TRISBbits.TRISB1 = 0;

    // CUP_BUTTON_PIN
    TRISBbits.TRISB2 = 1;
    WPUBbits.WPUB2 = 1;

    // FUNC_BUTTON_PIN
    TRISBbits.TRISB4 = 1;
    WPUBbits.WPUB4 = 1;

    // LDN_BUTTON_PIN
    TRISBbits.TRISB5 = 1;
    WPUBbits.WPUB5 = 1;

    // RELAY_CLOCK_PIN
    TRISCbits.TRISC0 = 0;

    // RELAY_DATA_PIN
    TRISCbits.TRISC1 = 0;

    // RELAY_STROBE_PIN
    TRISCbits.TRISC2 = 0;

    // BYPASS_LED_PIN
    TRISCbits.TRISC3 = 0;

    // FP_STROBE_PIN
    TRISCbits.TRISC4 = 0;

    // FP_DATA_PIN
    TRISCbits.TRISC5 = 0;

    // USB_TX_PIN
    TRISCbits.TRISC6 = 0;

    // USB_RX_PIN
    TRISCbits.TRISC7 = 1;

    // FREQ_PIN
    TRISEbits.TRISE0 = 1;

// DEBUG_TX_PIN
#ifdef DEVELOPMENT
    TRISDbits.TRISD2 = 0;
#endif

// DEBUG_RX_PIN
#ifdef DEVELOPMENT
    TRISDbits.TRISD3 = 1;
#endif

// TUNE_BUTTON_PIN
#ifdef DEVELOPMENT
    TRISEbits.TRISE1 = 1;
#else
    TRISBbits.TRISB6 = 1;
#endif
#ifdef DEVELOPMENT
    WPUEbits.WPUE1 = 1;
#else
    WPUBbits.WPUB6 = 1;
#endif

// ANT_BUTTON_PIN
#ifdef DEVELOPMENT
    TRISEbits.TRISE2 = 1;
#else
    TRISBbits.TRISB7 = 1;
#endif
#ifdef DEVELOPMENT
    WPUEbits.WPUE2 = 1;
#else
    WPUBbits.WPUB7 = 1;
#endif
}
// [[[end]]]
```

{{< /details >}}

# Feature Overview, or: Why did we actually do all this?

The implementation of the code generator is unremarkable(it's just strings in python), so we'll skip over that for now. Far more interesting is how many different firmware features are handled:

- function wrappers for all register access:
    - GPIO read
    - GPIO write
    - GPIO direction set
- Button debouncing subsystem configuration:
    - total button count
    - an array of function pointers to the GPIO read function for each button
    - an enum of the button names
- Peripheral Pin Select (PPS) macros, used to remap features to different pins
- ADC Channel select macros
- Supports dev/release mode, using `DEVELOPMENT` macro
- Automatically regenerated when `pinmap.py` is changed

This code generation system was directly responsible for reducing new project setup time from days (and a long tail of errors that lasted weeks) to approximately 30 minutes. I was able to get a new schematic from the hardware team, clone the most similar existing project, and have the new project compiled, running on hardware and responding to serial comms in 30 minutes, with no configuration timebombs waiting to derail me a month down the road.