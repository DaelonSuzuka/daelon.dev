---
title: "First Steps For New Firmware"
date: 2021-04-13T15:53:56-04:00
draft: false
type: "posts"
---

It's always useful to have a concrete, achievable goal. When working on embedded systems, especially starting a new project, there's so many things to do that it's easy to get overwhelmed by decision paralysis. Imagine you just got the first prototype of a new board. You don't have any code for it yet. Where do you start?

# Blink An LED
Hopefully your hardware has an LED tied to a microcontroller pin. Assuming it does, the first real goal of the project is to turn that LED on. 

I know it sounds trivial, but getting an LED blinking program to run on your hardware actually contains a bunch of non-trivial accomplishments:
- the compiler has to installed correctly
- the toolchain has to be able to see your project files and invoke the compiler
- the programmer has to exist
- the programmer's drivers have to be installed correctly
- the programmer's control software has to be installed correctly
- the toolchain has to be able to invoke the programmer
- the board has to not explode when you plug in power
- the board has to provide power to the processor
- the board's in circuit programming has to be designed correctly
- the board has to be connected to the programmer
- the programmer has to be connected to the computer
- the processor isn't dead
- the processor boots
- the processor boots and then loads the program you uploaded to it 

I could go on, but hopefully you get the point. Just compiling and uploading a program requires a long list of steps to all go properly, and you should never overlook how complicated this process actually is. Ideally, you should have a toolchain that allows single click or single command compilation and programming of your hardware. 

My open source PIC18 toolchain, [EasyXC8](https://github.com/DaelonSuzuka/Easy-XC8), uses a Makefile with the commands `compile` and `upload`. Just running `make upload` will cause a new hex to be compiled(if necessary), and then the upload that new hex to the hardware using the specified programmer. I'm not telling you to use EasyXC8, but if uploading firmware to your board is harder than `make upload`, there's something wrong with your workflow.

# Timing Is Everything

Blinking an LED proved that your environment works, and that your processor will boot and run _something_.

The next goal is making sure that the something happens when we want it to. Let's set a modest objective: instead of just turning an LED on, let's make that LED blink on and off once per second:

```c
void main(void) {
    while(1) {
        set_led(1);
        delay_ms(1000);
        set_led(0);
        delay_ms(1000);
    }
}
```

While it's usually unwise to use blocking delay functions like these, writing this little delay library will be a useful exercise in getting familiar with your hardware.

This is a "simple" implentation of delay_ms():
```c
void delay_init(void) {
    timer2_clock_source(TMR2_CLK_FOSC4);
    timer2_postscale(TMR_POSTSCALE_10);
    timer2_prescale(TMR_PRESCALE_16);
    timer2_period_set(100);
    timer2_start();
}

void delay_ms(uint16_t milliSeconds) {
    while (milliSeconds--) {
        timer2_interrupt_flag_clear();
        while (!timer2_interrupt_flag_read());
    }
}
```

This is a deceptively difficult task, because everything about it depends on your specific circumstances. This example is written for a [PIC18F57Q43](https://www.microchip.com/wwwproducts/en/PIC18F57Q43) running at 64MHz. This processor has 7 timers, of which I've chosen timer 2, an 8bit period match timer with a configurable period. I picked this timer because I can start it once and leave it running, and because it automatically resets the counter when it reaches the selected period value. These features make the delay_ms function simpler.

The postscale, prescale, and period were calculated starting from the main system clock value of 64MHz. In PICs, the main clock is known as FOSC. The selected clock source of `TMR2_CLK_FOSC4` is the FOSC divided by 4, or 16MHz. At 16MHz, one clock tick is 62.5nS long. 

A single millisecond is equivalent to 1000 microseconds, or 1,000,000 nanoseconds. Dividing 1mS by 62.5nS gives us 16,000, the number of clock ticks in a millisecond. An 8bit timer can't count to 16,000, so we use the prescale to divide by 16, and the postscale to divide by 10, leaving us with a nice target of 100 timer ticks. With the period set to 100, the timer will now overflow every 1 millisecond, and set its interrupt flag.

The while loop inside delay_ms() only does two things: clear the interrupt flag, and wait for the flag to be set again. Each time through the loop is supposed to be 1mS, and the loop executes once per millisecond we want to delay.

You can use an oscilloscope on the LED to test that your delays are delaying for the right amount of time. Test multiple delay values. If the delay is too long or too short, the timer configuration can be adjusted to bring it in line.

A simple microsecond delay can be made without even using a timer:
```c
void delay_us(uint16_t microSeconds) {
    while (microSeconds--) {
        asm("nop"); asm("nop"); asm("nop"); asm("nop"); asm("nop");
        asm("nop"); asm("nop"); asm("nop"); asm("nop"); asm("nop");
    }
}
```





# Say Hello

\<future content>