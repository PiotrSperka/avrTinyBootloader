avrTinyBootloader
=================
Homepage: https://sperka.online<br />
Description [PL]: https://blog.sperka.online/2019/09/uboot-avrtiny-bootloader-dla-attiny13/<br />
Description [EN]: https://blog.sperka.online/en/2019/09/uboot-avrtiny-bootloader-for-attiny13/

Simple bootloader for tiniest AVR microcontrollers (like ATtiny13, etc). Without EEPROM programming capabilities, it takes only **160 bytes** (80 words!). For communication it uses software UART fed through single wire (half-duplex).

Bootloader is provided in two versions:
* flash read/write,
* flash and eeprom read/write.

I guess that asm files are commented well enough to be understood. I've also provided simple Python script to make use of bootloader.

Software UART functions are placed at the end of flash memory, and they can be reused by user application if needed.

**Bootloader and examples are compiled to use with 1.2MHz oscillator! If you want to use different speed, consider modifying baud constant at the beginning of bootloader code according to AVR305 note**

**One important thing to remember:** You have to enable self-programming in fuse bits!

Files in bin directory:
* hex2bin.exe - application to convert hex files to binary (not mine)
* prog-flash-and-eeprom.py - script to use with EEPROM + FLASH version of bootloader
* prog-flash-only.py - script to use with FLASH only version of bootloader
* TestBlink1.bin - user application that blinks LED
* TestBlink2.bin - user application that blinks LED, but slower
* UartExample.bin - user application that uses UART routines from bootloader
* uBoot-flash-and-eeprom.bin - EEPROM + FLASH version of bootloader, 9600 baud/s @ 1.2MHz
* uBoot-flash-only.bin - FLASH only version of bootloader, 9600 baud/s @ 1.2MHz
