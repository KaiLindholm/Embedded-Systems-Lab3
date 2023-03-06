
; Embedded-Lab3.asm
;
; Created: 2/27/2023 8:20:33 PM
; Author : Kai Lindholm & James Ostrowski


.include "m328Pdef.inc"

.def value = r20       ; r20 is the value of the display 0-0, A-F
.def sequence = r16    ; r16 is the value of the shift register to display a value
.def input = r19	   ; r18 is the value from the RPG 
.def prevInput = r21
.def temp = r18
.def loopCt = r23
.def iLoopRh = r25
.def iloopRl = r24
.equ iVal = 39998
.cseg 
.org 0x00
; Set SER (PB2), RCLK (PB3), and SRCLK (PB4) as outputs in PORTB
clr r16
ldi r16, (1<<DDB2) | (1<<DDB3) | (1<<DDB4)
out DDRB, r16
nop
ldi		r16, LOW(RAMEND)
out		SPL, r16
ldi		r16, HIGH(RAMEND)
out		SPH, r16
reset: 
	clr		value				; the digit to display first is 0
	clr		sequence

	in		prevInput, PINB			
	andi	prevInput, 0x03		; extract input values

	ldi		r30, low(digits<<1)
	ldi		r31, high(digits<<1)
	lpm		sequence, Z+	
main:
	rcall	display				; display a 0 to the 7-seg
	in		input, PINB			; load in current state of RPG
	andi	input, 0x03			; extract new input values 
	ldi		loopCt, 5
	rcall	delay10ms
	cp		prevInput, input	 
	brne	update_count		; if the current current state is not the same, determine the direction

	rjmp	main				

update_count: 
	in		input, PINB			; load in the current state again 
	andi	input, 0x03			; extract input pins  
	mov		temp, input			; store input in temp register

	andi	input, 0x02			; extract B bit from input			
	lsr		input				; shift B bit to LSB

	andi	prevInput, 0x01		; extract A bit from the prev input

	cp		input, prevInput			
	breq	decrement			; if the A and B bit are equal RPG is moving CCW

	cpi		value, 0x10			; if the value is 16, we have reached the max value that can be displayed do nothing
	brge	main					

	inc		value 
	lpm		sequence, Z+ 

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	main

decrement:
	cpi		value, 0x00
	breq	reset

	dec		value				; else decrement the value
	sbiw	Z, 0x01				; decrement Z pointer by 1  
	lpm		sequence, Z

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	main

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
delay10ms: 
	ldi		iLoopRl, LOW(iVal)
	ldi		iLoopRh, HIGH(iVal)
iLoop: 
	sbiw	iLoopRl, 1 
	brne	iLoop

	dec		loopCt
	brne	delay10ms

	nop

	ret
digits: 
	.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, \
	0x6D, 0x7D, 0x07, 0x7F, 0x6F, \
	0x77, 0xFC, 0x39, 0x5E, 0x79, 0x79, 0x71, 0
