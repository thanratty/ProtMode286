# 286 Protected Mode Environment

## Background
I discovered this in a backup image I took of an old 40 Mb hard drive I had many years ago in my desktop 286 PC.

This is a very basic OS I wrote back in the 90's when I was playing around with Intel protected mode and learning C, having programmed solely in various assemblers up till then. It's in the style of a classic 'monitor' program, ie dump memory, edit memory, display regs etc.. Over time I added more submenus whenever I was experimenting with particular hardware or trying some code, so it ended up with a floating point module (not fast, not IEEE 754). That was written to follow pseudo code in a Byte magazine article. A fair amount of time went into reading floppies from other makes of computer so there's a lot of stuff in there to control the floppy disk controller. Eventually I could read BBC format floppy disks and Archimedes 1.6 Mb disks in a normal PC floppy drive using the Intel 82072 floppy dfisk controller. I vaguely recall being able to read Amiga disks too but that might just be a fever dream.

Originally the build was designed to to create an absolute image that could be booted from a floppy, but it proved quicker (for development) to build an EXE which simply kicks out MS-DOS and takes over the PC, switches to protected mode & 'boots' to a command line. Impressively DOSbox handles this and runs the program without a hitch, though it does choke if you try to start a task using a 286 Task Descriptor.

## Building
Apart from one C file handling BBC/DOS file I/O, everything is written in assembler.

I used Borland Turbo Assembler v1.01, available [>> HERE <<](https://winworldpc.com/product/turbo-assembler/1x). I haven't tried with more up-to-date versions.

Aztec C was a popular professional compiler at the time with excellent documentation & full library source. It is available [>> HERE <<](http://www.clipshop.ca/Aztec/index.htm)

Edit the SET-VARS batch file so the configured environment variables match your installation.
There is a Makefile which pulls everything together and outputs MON.EXE

You'll need to build under DOSbox as the tools don't run in a modern Windows environment. Download [>> HERE <<](https://www.dosbox.com/)

## Running
Fire up DOSbox and run MON.EXE!
All commands are two letters, and 'HE' display the help menu in any screen.
Pressing ESCape at any point coldboots the monitor.

## Finally
I can't imagine this code will be of any use to anybody, anywhere... but you never know!
MONCODE.ASM is the startup file, so start your journey there.

16 bit protected mode awaits :)

(My apologies for using TABs in the source. I was young and foolish.)
