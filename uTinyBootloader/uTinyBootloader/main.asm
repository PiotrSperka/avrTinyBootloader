;
; uTinyBootloader.asm
;
; Created: 12.08.2019 20:22:40
; Author : Piotr Sperka
;

.include "tn13adef.inc"

; +------------------------------------------+
; | ENABLE SELF PROGRAMMING IN FUSE BITS !!! |
; +------------------------------------------+

//#define		ADD_EEPROM_SUPPORT

; Lets use PB0 as out I/O pin
.equ		IODDRR = DDRB
.equ		IOPORTR = PORTB
.equ		IOPINR = PINB
.equ		IOPIN = 0

.equ		baud = 17				; 9600 bps @ 1.2 MHz clock
.def		bitcnt = R16			; bit counter
.def		temp = R17				; temporary storage register
.def		Txbyte = R18			; Data to be transmitted
.def		Rxbyte = R19			; Received data

.equ		FPAGESIZE = PAGESIZE	; Flash page size in words
.equ		FPAGECNT = 32			; Flash pages count

.org	0x00
			rjmp	BOOTLOADER_START

#ifdef ADD_EEPROM_SUPPORT
.org 0x190
#else
.org 0x1b0
#endif

BOOTLOADER_START:
			ldi		R16, RAMEND
			out		SPL, R16		; Since RAMEND fits in 8 bits, we don't need to use SPH

			sbic	IOPINR, IOPIN
			rjmp	0x000A			; First address after interrupt vector table
			
_READ_LOOP:
			rcall	getchar
#ifdef ADD_EEPROM_SUPPORT
			cpi		Rxbyte, 'E'
			breq	_READ_EEPROM
			cpi		Rxbyte, 'F'
			breq	_WRITE_EEPROM
#endif
			cpi		Rxbyte, 'R'
			breq	_READ_FLASH
			cpi		Rxbyte, 'P'
			breq	_PROGRAM_PAGE

			rjmp	_READ_LOOP

#ifdef ADD_EEPROM_SUPPORT
_READ_EEPROM:
			clr		R25
_REL:		sbic	EECR, EEPE ; Wait for completion of previous write
			rjmp	_READ_EEPROM
			out		EEARL, R25 ; Set up address (r17) in address register
			sbi		EECR,EERE ; Start eeprom read by writing EERE
			in		Txbyte, EEDR ; Read data from data register
			rcall	putchar
			inc		R25
			cpi		R25, (EEPROMEND + 1) ; EEPROM is 64 bytes, so we need only one register to count
			brne	_REL

			rjmp	_READ_LOOP

_WRITE_EEPROM:
			sbic	EECR, EEPE ; Wait for completion of previous write
			rjmp	_WRITE_EEPROM
			ldi		R16, (0<<EEPM1)|(0<<EEPM0) ; Set Programming mode
			out		EECR, R16
			rcall	getchar ; Set up address (r17) in address register
			out		EEARL, Rxbyte
			rcall	getchar ; Write data (r16) to data register
			out		EEDR, Rxbyte
			sbi		EECR, EEMPE ; Write logical one to EEMPE
			sbi		EECR, EEPE ; Start eeprom write by setting EEPE

			; Send response
			ldi		Txbyte, 'Y'
			rcall	putchar
			
			rjmp	_READ_LOOP
#endif

_READ_FLASH:
			ldi		R24, LOW(2*(FLASHEND + 1))
			ldi		R25, HIGH(2*(FLASHEND + 1))
			clr		R30
			clr		R31

_RFL:		lpm		Txbyte, Z+
			rcall	putchar
			sbiw	R24, 1
			brne	_RFL

			rjmp	_READ_LOOP

_PROGRAM_PAGE:
			ldi		R25, 0x10 ; 16 words to write into flash
			ldi		R24, 0x01 ; New value for SPMCSR register
			rcall	getchar   ; Get more significant part of Z register
			mov		R31, Rxbyte
			rcall	getchar   ; Get less significant part of Z register
			mov		R30, Rxbyte
_PP_GDL:	rcall	getchar   ; Get Data Loop, get more significant byte of word
			mov		R0, Rxbyte
			rcall	getchar   ; Get less significant byte of word
			mov		R1, Rxbyte
			out		SPMCSR, R24
			spm               ; Write word to temp buffer
			dec		R25
			breq	_PP_ERASE
			inc		R30       ; Increment PCWORD by 2 (Z reg)
			inc		R30
			rjmp	_PP_GDL

			; Erase page
_PP_ERASE:  ldi		R24, 0x03 ; New value for SPMCSR
			out		SPMCSR, R24
			spm

			; Write flash
			ldi		R24, 0x05 ; New value for SPMCSR
			andi	R30, 0xE0 ; Zero PCWORD in Z
			out		SPMCSR, R24
			spm

			; Send response
			ldi		Txbyte, 'Y'
			rcall	putchar

			rjmp	_READ_LOOP

; UART FUNCTIONS TAKEN FROM AN305 (AVR305) NOTE
.org 0x1de ; We place them at the end of flash
;***************************************************************************
;*
;* "putchar"
;*
;* This subroutine transmits the byte stored in the "Txbyte" register
;* The number of stop bits used is set with the sb constant
;*
;* Number of words	:15 including return
;* Number of cycles	:Depens on bit rate
;* Low registers used	:None
;* High registers used	:2 (bitcnt,Txbyte)
;* Pointers used	:None
;*
;***************************************************************************
putchar:
			sbi		IODDRR, IOPIN
			ldi		bitcnt, 10		; 1+8+sb (sb is # of stop bits)
			com		Txbyte			; Inverte everything
			sec						; Start bit
putchar0:	brcc	putchar1		; If carry set
			cbi		IOPORTR, IOPIN	;    send a '0'
			rjmp	putchar2		; else	
putchar1:	sbi		IOPORTR, IOPIN	;    send a '1'
			nop
putchar2:	rcall	UART_delay		; One bit delay
			rcall	UART_delay
			lsr		Txbyte			; Get next bit
			dec		bitcnt			; If not all bit sent
			brne	putchar0		;   send next
									; else
			ret						;   return

;***************************************************************************
;*
;* "getchar"
;*
;* This subroutine receives one byte and returns it in the "Rxbyte" register
;*
;* Number of words	:15 including return
;* Number of cycles	:Depens on when data arrives
;* Low registers used	:None
;* High registers used	:2 (bitcnt,Rxbyte)
;* Pointers used	:None
;*
;***************************************************************************
getchar:
			cbi		IODDRR, IOPIN
			ldi 	bitcnt, 9		; 8 data bit + 1 stop bit
getchar1:	sbic 	IOPINR, IOPIN		; Wait for start bit
			rjmp 	getchar1
			rcall	UART_delay		; 0.5 bit delay
getchar2:	rcall	UART_delay		; 1 bit delay
			rcall	UART_delay		
			clc						; clear carry
			sbic 	IOPINR, IOPIN		; if RX pin high
			sec
			dec 	bitcnt			; If bit is stop bit
			breq 	getchar3		;   return
									; else
			ror 	Rxbyte			;   shift bit into Rxbyte
			rjmp 	getchar2		;   go get next
getchar3:	ret

;***************************************************************************
;*
;* "UART_delay"
;*
;* This delay subroutine generates the required delay between the bits when
;* transmitting and receiving bytes. The total execution time is set by the
;* constant "b":
;*
;*	3·b + 7 cycles (including rcall and ret)
;*
;* Number of words	:4 including return
;* Low registers used	:None
;* High registers used	:1 (temp)
;* Pointers used	:None
;*
;***************************************************************************
UART_delay:
			ldi		temp, baud
UART_delay1:dec		temp
			brne	UART_delay1
			ret


