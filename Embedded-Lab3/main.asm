
; Embedded-Lab3.asm
;
; Created: 2/27/2023 8:20:33 PM
; Author : Kai Lindholm & James Ostrowski


.include "m328Pdef.inc"
.equ delay2 = 0x20 ; delay value for debouncing
.equ digit_0 = 0x3F; pattern to display digit 0
.equ digit_1 = 0x06 ; pattern to display digit 1
.equ digit_2 = 0x5B ; pattern to display digit 2
.equ digit_3 = 0x4F ; pattern to display digit 3
.equ digit_4 = 0x66 ; pattern to display digit 4
.equ digit_5 = 0x6D ; pattern to display digit 5
.equ digit_6 = 0x7D ; pattern to display digit 6
.equ digit_7 = 0x07 ; pattern to display digit 7
.equ digit_8 = 0x7F ; pattern to display digit 8
.equ digit_9 = 0x6F ; pattern to display digit 9
.equ dash = 0x40

.def value = r20       ; r20 is the value of the display 0-0, A-F
.def sequence = r16    ; r16 is the value of the shift register to display a value
.def input = r19	   ; r18 is the value from the RPG 
.def prevInput = r21
.def temp = r18
.cseg 
.org 0x00
; Set SER (PB2), RCLK (PB3), and SRCLK (PB4) as outputs in PORTB
clr r16
ldi r16, (1<<DDB2) | (1<<DDB3) | (1<<DDB4)
out DDRB, r16
nop

reset: 
	clr value				; the digit to display first is 0
	clr sequence
	in prevInput, PINB
	andi prevInput, 0x01		; extract pin A from RPG
	ldi r30, low(digits<<1)
	ldi r31, high(digits<<1)
	lpm sequence, Z+
	rcall display			; display a 0 to the 7-seg
main: 
	in input, PINB			; load in current state of RPG
	andi input, 0x01		; extract current state of pin A from RPG
	cp input, prevInput		; if curr and prev states are not equal
	brne update_count		; determine which way to update the counter
	mov input, prevInput
	rjmp main

update_count: 
	in prevInput, PINB			
	andi prevInput, 0x02			; extract pin B from RPG 
	lsr prevInput					; shift bit to lsb 
	cp input, prevInput				; compare pin b to pin a, if they are not equal dec
	breq decrement
	inc value				; if they are equal increment value 
	cpi value, 17
	brge reset
	lpm sequence, Z+		; change the sequence to display
	rcall display
	rjmp main

decrement:
	cpi value, 0x00			; if the value is already 0
	breq main
	dec value				; else decrement the value
	lpm sequence, Z
	rcall display
	rjmp main

display:
	push sequence			; Backup used registers on stack
	push R17
	in R17, SREG
	push R17
	ldi R17, 8				; loop --> test all 8 bits
	nop
	nop
loop:
	rol sequence			; rotate left through Carry
	BRCS set_ser_in_1		; branch if Carry is set

	cbi PORTB, PB2			; clear PB0 (SER)
	nop
	rjmp end
	set_ser_in_1:
		sbi PORTB, PB2		; set PB0 (SER)
		nop

end:
	sbi PORTB, PB4			; set PB2 (SRCLK)
	nop
	cbi PORTB, PB4			; clear PB2 (SRCLK)
	nop

	dec R17
	brne loop
	; pulse rclk, which sends values to storage register for displaying
	sbi PORTB, PB3 ; set PB1 (RCLK)
	nop
	cbi PORTB, PB3 ; clear PB1 (RCLK)
	nop
	; Restore registers from stack
	pop R17
	out SREG, R17
	pop R17
	pop sequence
	cbi PORTB, PB2 ; clear pb0, ser
	nop
	ret

; digit lookup table, first index is a digital 0, last index is an 9
; TODO: Add a - f values
digits: 
	.db 0x3F, 0x06, 0x5B, 0x4F, 0x66
	.db 0x6D, 0x7D, 0x07, 0x7F, 0x6F
	.db 0x77, 0xFC, 0x39, 0x5E, 0x79, 0x79, 0x71
