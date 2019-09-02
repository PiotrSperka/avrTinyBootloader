;
; UartExample.asm
;
; Created: 29.08.2019 19:50:17
; Author : Piotr Sperka
;


.include "tn13adef.inc"

.def		Txbyte = R18			; Data to be transmitted
.def		Rxbyte = R19			; Received data

.equ		PUTCHAR = 0x1de			; Putchar function address (in bootloader)
.equ		GETCHAR = 0x1ed			; Getchar function address (in bootloader)

.MACRO LCM ; Load Constant address from Memory
			ldi		ZH, high(2 * @0)
			ldi		ZL, low(2 * @0)
.ENDMACRO

.org	0x00
			rjmp	START

.org	0x0A
START:
			ldi		R16, RAMEND
			out		SPL, R16		; Since RAMEND fits in 8 bits, we don't need to use SPH
			lcm		HELLO_MSG
			rcall	PUTSTRING

LOOP:		rcall	GETCHAR
			inc		Rxbyte
			mov		Txbyte, Rxbyte
			rcall	PUTCHAR
			rjmp	LOOP

PUTSTRING:
	PS_NEXT:
	lpm			Txbyte, Z+
	and			Txbyte, Txbyte
	breq		PS_END
	rcall		PUTCHAR
	rjmp		PS_NEXT

	PS_END:
	ret

; ----------------------------------
; -------- TEXT CONSTANTS ----------
; ----------------------------------
HELLO_MSG: .db "Hello! I will get every character, increment it, and send it back to you.", 13, 10, 0