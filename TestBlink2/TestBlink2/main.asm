;
; TestBlink2.asm
;
; Created: 28.08.2019 20:19:41
; Author : Piotr Sperka
;

.include "tn13adef.inc"

.org	0x00
			rjmp	START

.org	0x0A
START:
			ldi		R16, RAMEND
			out		SPL, R16		; Since RAMEND fits in 8 bits, we don't need to use SPH
			sbi		DDRB, 3

LOOP:		sbi		PORTB, 3
			rcall	Delay
			cbi		PORTB, 3
			rcall	Delay
			rjmp	LOOP

Delay:
			ldi		r24, 0xFF
			ldi		r25, 0xFF
DL:			sbiw	r24, 0x01
			nop
			nop
			nop
			nop
			brne	DL
			ret