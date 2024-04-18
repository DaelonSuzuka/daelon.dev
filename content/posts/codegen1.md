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
import cog # Cog actually imports this automatically!
cog.outl("Hello world!") # cog.outl() inserts its output after the block
]]]*/
Hello world!
//[[[end]]]

/*[[[cog
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

A pin is defined by 3 elements, a PIN_ID, a PIN_NAME, and a list of tags. The PIN_ID is the pin's identifier in the hardware/datasheet. The PIN_NAME should be human-readable, and is used to generate the macros and functions. The list of tags describes what features you want enabled on that pin.

```py
# Pin definition format:
# 'PIN_ID': ('PIN_NAME', ['list', 'of', 'tags'])
common = {
    'A0': None, # pins can be left undefined
    'A2': ('ONE_BUTTON_PIN', ['input', 'gpio', 'button']),
    'A7': ('RED_LED_PIN', ['output', 'gpio']),
}
```

The `Pin` class is at the top of `pinmap.py`, and functions as both a reference for the available tags, as well as a helpful shortcut for commonly used tag groups.

```py
class Pin:
    # possible pin functions (this is just here for reference)
    tags = [
        'input', 'output', # initial pin direction
        'gpio', # generate GPIO utility functions
        'tristate', # pin direction will be changed at runtime
        'analog', # generate ADC helpers
        'pullup', # enable the pullup resistor
        'button', # pin is used by the button debouncer
        'pps' # generate pin remapping helpers
    ]

    # shortcuts, common groups of functions
    button = ['input', 'gpio', 'button']
    digital_out = ['output', 'gpio']
    analog_in = ['input', 'analog']
    uart_tx = ['output', 'pps']
    uart_rx = ['input', 'pps']
```

Here's an example pinmap with a variety of features being used:

```py
# format: 'PIN_ID': ('PIN_NAME', ['list', 'of', 'tags'])
common = {
    # Buttons
    'A2': ('ONE_BUTTON_PIN', ['input', 'gpio', 'button']), # specify tags
    'A3': ('TWO_BUTTON_PIN', Pin.button), # or use the premade tag groups

    # Individual LEDs
    'A5': ('GREEN_LED_PIN', Pin.digital_out),
    'A6': ('YELLOW_LED_PIN', Pin.digital_out), 
    'A7': ('RED_LED_PIN', ['output', 'gpio']),

    # Analog inputs
    'B0': ('KNOB_ONE_PIN', Pin.analog_in),
    'B1': ('KNOB_TWO_PIN', Pin.analog_in),

    # LED Bargraph -bitbang SPI
    'C3': ('BARGRAPH_CLOCK_PIN', Pin.digital_out),
    'C5': ('BARGRAPH_DATA_PIN', Pin.digital_out),
    'E0': ('BARGRAPH_STROBE_PIN', Pin.digital_out),

    # LCD - bitbang serial
    'D2': ('LCD_TX_PIN', Pin.digital_out),

    # RGB LED - common cathode, active high
    'D5': ('RGB_1_LED_PIN', Pin.digital_out),
    'D6': ('RGB_2_LED_PIN', Pin.digital_out),
    'D7': ('RGB_3_LED_PIN', Pin.digital_out),

    # USB uart
    'F6': ('USB_TX_PIN', Pin.uart_tx),
    'F7': ('USB_RX_PIN', Pin.uart_rx),
}
```

The toolchain supports development and release builds, and the following two pin dictionaries are merged with the common dictionary to create the full configuration for each mode.

This allows for using different hardware for dev and release, driven by a single declarative configuration

```py
development = {
    # the debug serial port is only available on development builds
    'B6': ('DEBUG_TX_PIN', Pin.uart_tx),
    'B7': ('DEBUG_RX_PIN', Pin.uart_rx),
}

release = {
}
```

## Generated Code

Let's go over the generated `pin.h` section by section, starting with the Cog block that's doing all the work. This block is what's actually executed by running Cog, and it imports some python libraries that are tucked away in the toolchain directory (these will be explored at a later date). 

```c
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pin_declarations()))
]]] */
// <generated code goes here>
// [[[end]]]
```

Here's an easier to read version, if you prefer:

{{< details "Expand me" >}}
```python
from codegen import fmt
import pins
import cog # im

# parse pinmap.py and return a string containing the C code we want
raw_output = pins.pin_declarations()
# format the C code using clang-format so it matches the project
formatted_output = fmt(raw_output)
# insert the formatted code after the Cog block
cog.outl(formatted_output)
```

{{< /details >}}

### GPIO Helper Functions

The next section is GPIO related utility functions. These functions use the human readable pin names, and are only created for pins that are marked as requiring specific functionality. This hides the details of which functions are on which pins from the rest of your application, and also tricks the compiler into helping detect configuration errors.

```c
// GPIO read functions
extern bool read_ONE_BUTTON_PIN(void);
extern bool read_TWO_BUTTON_PIN(void);

// GPIO write functions
extern void set_GREEN_LED_PIN(bool value);
extern void set_YELLOW_LED_PIN(bool value);
extern void set_RED_LED_PIN(bool value);
extern void set_BARGRAPH_CLOCK_PIN(bool value);
extern void set_BARGRAPH_DATA_PIN(bool value);
extern void set_LCD_TX_PIN(bool value);
extern void set_RGB_1_LED_PIN(bool value);
extern void set_RGB_2_LED_PIN(bool value);
extern void set_RGB_3_LED_PIN(bool value);
extern void set_BARGRAPH_STROBE_PIN(bool value);

// GPIO direction functions
// none
```

### Button Subsytem

I use a standard button debouncing system in most of my projects, an evolution of [this one](https://hackaday.com/2015/12/09/embed-with-elliot-debounce-your-noisy-buttons-part-i/) described by Elliot Williams at Hackaday. A 5ms timer triggers an interrupt service routine(ISR), which scans all the buttons in the system. The system tracks the recent history of each button, allowing it to ignore button noise and detect 4 distinct input states: UP, DOWN, PRESSED (rising edge), and RELEASED (falling edge).

The generated array `buttonFunctions` is used in the ISR to scan each button in a loop. The enum of the button names allows us to have a clean API for checking button state from application code: `is_btn_down(ONE)`, `is_btn_pressed(TWO)`, etc.

```c
// Button stuff
#define NUMBER_OF_BUTTONS 2

typedef bool (*button_function_t)(void);

// array of pointers to button reading functions
extern button_function_t buttonFunctions[NUMBER_OF_BUTTONS];

// enum of button names
enum {
    ONE,
    TWO,
} button_names;
```

### Pin Remapping

This family of microcontrollers allows remapping internal peripherals to different pin using a module called the Peripheral Pin Select, or PPS. Using these helpers to initialize the PPS system ensures peripherals are always routed to the correct locations.

Also note the presence of `#ifdef DEVELOPMENT`, allowing the system to switch between development and release mode by simply adding or removing the `-DDEVELOPMENT` compiler flag.

```c
// PPS Pin initialization macros
#define PPS_LCD_RX_PIN PPS_INPUT(D, 3)
#define PPS_USB_TX_PIN PPS_OUTPUT(F, 6)
#define PPS_USB_RX_PIN PPS_INPUT(F, 7)
#ifdef DEVELOPMENT
#define PPS_DEBUG_RX_PIN PPS_INPUT(B, 6)
#endif
#ifdef DEVELOPMENT
#define PPS_DEBUG_TX_PIN PPS_OUTPUT(B, 7)
#endif
```

### Analog Helpers

A numeric channel ID is required to initialize an ADC read, so generated helper macros make sure the correct channels are always being used.

```c
// ADC Channel Select macros
#define ADC_KNOB_ONE_PIN 8
#define ADC_KNOB_TWO_PIN 9
```

### Full `pins.h`

The full header, if you want to see everything together:

{{< details "Expand me" >}}
```c
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pin_declarations()))
]]] */

// GPIO read functions
extern bool read_ONE_BUTTON_PIN(void);
extern bool read_TWO_BUTTON_PIN(void);

// GPIO write functions
extern void set_GREEN_LED_PIN(bool value);
extern void set_YELLOW_LED_PIN(bool value);
extern void set_RED_LED_PIN(bool value);
extern void set_BARGRAPH_CLOCK_PIN(bool value);
extern void set_BARGRAPH_DATA_PIN(bool value);
extern void set_LCD_TX_PIN(bool value);
extern void set_RGB_1_LED_PIN(bool value);
extern void set_RGB_2_LED_PIN(bool value);
extern void set_RGB_3_LED_PIN(bool value);
extern void set_BARGRAPH_STROBE_PIN(bool value);

// GPIO direction functions
// none

/* -------------------------------------------------------------------------- */

// Button stuff
#define NUMBER_OF_BUTTONS 2

// array of pointers to button reading functions
typedef bool (*button_function_t)(void);
extern button_function_t buttonFunctions[NUMBER_OF_BUTTONS];

// enum of button names
enum {
    ONE,
    TWO,
} button_names;

/* -------------------------------------------------------------------------- */

// PPS Pin initialization macros
#define PPS_LCD_RX_PIN PPS_INPUT(D, 3)
#define PPS_USB_TX_PIN PPS_OUTPUT(F, 6)
#define PPS_USB_RX_PIN PPS_INPUT(F, 7)
#ifdef DEVELOPMENT
#define PPS_DEBUG_RX_PIN PPS_INPUT(B, 6)
#endif
#ifdef DEVELOPMENT
#define PPS_DEBUG_TX_PIN PPS_OUTPUT(B, 7)
#endif

/* -------------------------------------------------------------------------- */

// ADC Channel Select macros
#define ADC_KNOB_ONE_PIN 8
#define ADC_KNOB_TWO_PIN 9

// [[[end]]]
```
{{< /details >}}

And the full source file. It's essentially just the matching implementation of the header.

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
bool read_ONE_BUTTON_PIN(void) { return PORTAbits.RA2; }
bool read_TWO_BUTTON_PIN(void) { return PORTAbits.RA3; }

// GPIO write functions
void set_GREEN_LED_PIN(bool value) { LATAbits.LATA5 = value; }
void set_YELLOW_LED_PIN(bool value) { LATAbits.LATA6 = value; }
void set_RED_LED_PIN(bool value) { LATAbits.LATA7 = value; }
void set_BARGRAPH_CLOCK_PIN(bool value) { LATCbits.LATC3 = value; }
void set_BARGRAPH_MISO_PIN(bool value) { LATCbits.LATC4 = value; }
void set_BARGRAPH_DATA_PIN(bool value) { LATCbits.LATC5 = value; }
void set_LCD_TX_PIN(bool value) { LATDbits.LATD2 = value; }
void set_RGB_1_LED_PIN(bool value) { LATDbits.LATD5 = value; }
void set_RGB_2_LED_PIN(bool value) { LATDbits.LATD6 = value; }
void set_RGB_3_LED_PIN(bool value) { LATDbits.LATD7 = value; }
void set_BARGRAPH_STROBE_PIN(bool value) { LATEbits.LATE0 = value; }

// GPIO direction functions
// none

// Button stuff
// array of pointers to button reading functions
button_function_t buttonFunctions[NUMBER_OF_BUTTONS] = {
    read_ONE_BUTTON_PIN, //
    read_TWO_BUTTON_PIN, //
};

// [[[end]]]

/* ************************************************************************** */
/* [[[cog
    from codegen import fmt; import pins
    cog.outl(fmt(pins.pins_init()))
]]] */

void pins_init(void) {
    // ONE_BUTTON_PIN
    TRISAbits.TRISA2 = 1;
    WPUAbits.WPUA2 = 1;

    // TWO_BUTTON_PIN
    TRISAbits.TRISA3 = 1;
    WPUAbits.WPUA3 = 1;

    // GREEN_LED_PIN
    TRISAbits.TRISA5 = 0;

    // YELLOW_LED_PIN
    TRISAbits.TRISA6 = 0;

    // RED_LED_PIN
    TRISAbits.TRISA7 = 0;

    // KNOB_ONE_PIN
    TRISBbits.TRISB0 = 1;
    ANSELBbits.ANSELB0 = 1;

    // KNOB_TWO_PIN
    TRISBbits.TRISB1 = 1;
    ANSELBbits.ANSELB1 = 1;

    // BARGRAPH_CLOCK_PIN
    TRISCbits.TRISC3 = 0;

    // BARGRAPH_MISO_PIN
    TRISCbits.TRISC4 = 0;

    // BARGRAPH_DATA_PIN
    TRISCbits.TRISC5 = 0;

    // LCD_TX_PIN
    TRISDbits.TRISD2 = 0;

    // LCD_RX_PIN
    TRISDbits.TRISD3 = 1;

    // RGB_1_LED_PIN
    TRISDbits.TRISD5 = 0;

    // RGB_2_LED_PIN
    TRISDbits.TRISD6 = 0;

    // RGB_3_LED_PIN
    TRISDbits.TRISD7 = 0;

    // BARGRAPH_STROBE_PIN
    TRISEbits.TRISE0 = 0;

    // USB_TX_PIN
    TRISFbits.TRISF6 = 0;

    // USB_RX_PIN
    TRISFbits.TRISF7 = 1;

// DEBUG_RX_PIN
#ifdef DEVELOPMENT
    TRISBbits.TRISB6 = 1;
#endif

// DEBUG_TX_PIN
#ifdef DEVELOPMENT
    TRISBbits.TRISB7 = 0;
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
- automatic port initializing, making sure every pin is configured correctly
- Button debouncing subsystem configuration:
    - total button count
    - an array of function pointers to the GPIO read function for each button
    - an enum of the button names
- Peripheral Pin Select (PPS) macros, used to remap features to different pins
- ADC Channel select macros
- Supports dev/release mode, using `DEVELOPMENT` macro
- Automatically regenerated when `pinmap.py` is changed

This code generation system was directly responsible for reducing new project setup time from days (and a long tail of errors that lasted weeks) to approximately 30 minutes. I was able to get a new schematic from the hardware team, clone the most similar existing project, and have the new project compiled, running on hardware and responding to serial comms in 30 minutes, with no configuration timebombs waiting to derail me a month down the road.