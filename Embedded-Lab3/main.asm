
; Embedded-Lab3.asm
;
; Created: 2/27/2023 8:20:33 PM
; Author : Kai Lindholm & James Ostrowski


.include "m328Pdef.inc"
;5555
.equ dp = 0x80
.equ underscore = 0x08
.equ firstcode = 5
.equ secondcode = 5
.equ thirdcode = 5
.equ fourthcode = 5
.equ fifthcode = 5
.def value = r20       ; r20 is the value of the display 0-0, A-F
.def sequence = r16    ; r16 is the value of the shift register to display a value
.def input = r19	   ; r18 is the value from the RPG 
.def prevInput = r21
.def temp = r18
.def passcode = r22	
.def passbool = r23
.def passIndex = r24
.def button = r25

.cseg 
.org	0x00
; Set SER (PB2), RCLK (PB3), and SRCLK (PB4) as outputs in PORTB
; pin A - PB0 pin B - PB1 
; Pushbutton - PB5
clr		temp
ldi		temp, (1<<DDB2) | (1<<DDB3) | (1<<DDB4)
out		DDRB, temp
nop
ldi		temp, LOW(RAMEND)
out		SPL, temp
ldi		temp, HIGH(RAMEND)
out		SPH, temp

reset: 
	clr		temp
	clr		sequence
	clr		passbool
	ldi		passIndex, 1 
	ldi		value, 0x00			; the digit to display first is 0
	ldi		temp, (1<<CS01) | (1<<CS00)
	out		TCCR0B, temp	; Timer clock = system clock / 64
	ldi		temp, 1 << TOV0
	out		TIFR0, temp		; CLear TOV0 / clear pending interrupts 
	ldi		temp, 1 << TOIE0
	sts		TIMSK0, temp	;Enable Timer/Counter0 Overflow interrrupt


	ldi		r30, low(digits<<1)
	ldi		r31, high(digits<<1)
	lpm		sequence, Z			; load 0 into sequence 
;-----------------------------------------------
	in		prevInput, PINB
	andi	prevInput, 0x01		; extract previous A bit
main:	

	in		input, PINB
	rcall	_delay10ms
	sbrs	input, PB5			; check the PB state	
	rcall	buttonPressed		; determine length of button press
	rcall	display				; display a 0 to the 7-seg

	in		input, PINB			; load in current state of RPG
	andi	input, 0x01			; extract new input values 
	cp		prevInput, input	 
	brne	direction			; if the current current state is not the same, determine the direction
rtn: 
	mov		prevInput, input
	rjmp	main		
			
buttonPressed:
	rcall _delay10ms
	checkReset: 
		in input, PINB
		sbrs input, PB5
		rjmp resetCounter	
	clr r28
	sbrc input, PB5
	rjmp check_pass
	rjmp main

resetchecksum:
	in input, PINB
	sbrc input, PB5
	rjmp reset
	rjmp resetchecksum

resetCounter: 
	rcall _delay10ms
	inc r28
	cpi R28, 200
	breq resetchecksum
	rjmp checkReset

direction: 
	in		temp, PINB
	andi	temp, 0x02
	lsr		temp
	cp		input, temp
	breq	increment 
	rjmp	decrement 

increment: 
	cpi		value, 0x11			; if the value is 16, we have reached the max value that can be displayed do nothing
	brge	main					

	inc		value
	lpm		sequence, Z+ 

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	rtn

decrement:
	cpi		value, 0x00
	breq	main

	dec		value				; else decrement the value
	sbiw	Z, 0x01				; decrement Z pointer by 1  
	lpm		sequence, Z

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	rtn

check_pass:						; only called once the pb has been pressed for less than a second 				
;--------------
	rcall getCode
	inc passIndex				; increment the number of digits inputted 
	cpi passIndex, 0x07			
	breq final					; branch to final if the passcount is equal to 

	cp passcode, value 
	breq equal
	nonequal: 
		rjmp main
	equal: 
		mov temp, sequence 
		ldi sequence, dp
		rcall display
		mov sequence, temp
		rcall _delay1second
		rcall display
		inc passbool
		rjmp main	
	final: 
		cpi passbool, 5		; if the passCount has a value of 0b0011 1110 that means each sequence matched thus password is correct
		breq correct_password 
		rjmp incorrect_password 

getCode: 
	cpi passIndex, 1
	breq first

	cpi passIndex, 2
	breq second
	
	cpi passIndex, 3
	breq third
	
	cpi passIndex, 4
	breq fourth
	
	cpi passIndex, 5
	breq fifth
 
first: 
	ldi passcode, firstcode
	ret 
second: 
	ldi passcode, secondcode
	ret 
third: 
	ldi passcode, thirdcode
	ret 
fourth: 
	ldi passcode, fourthcode
	ret 
fifth: 
	ldi passcode, fifthcode
	ret 


correct_password:
	cbi PORTB, PB5 
	rcall _delay10ms
	ldi sequence, dp
	rcall display
	sbi PORTB, PB5
	rcall _delay5second
	rjmp reset

incorrect_password: 
	ldi sequence, underscore
	rcall display
	rcall _delay9second
	rjmp reset

; prescalar: 64 start value: 6
_delay1ms: 
	push	temp
	ldi		temp, 6
	out		TCNT0, temp
	clr		temp
	wait: 
		in		temp, TCNT0
		cpi		temp, 0x00	; has the overflow bit been set
		brne	wait

	pop		temp
	ret 
		 
_delay10ms:
	push temp
	clr temp
	wait10ms: 
		rcall	_delay1ms 
		inc		temp
		cpi		temp, 10
		brne	wait10ms
	pop temp
	ret 
		
_delay1second: 
	push temp
	clr temp
	wait1sec: 
		rcall _delay10ms 
		inc temp
		cpi temp, 100
		brne wait1sec

	pop temp
	ret

_delay2second: 
	rcall _delay1second
	rcall _delay1second 
	ret 

_delay5second:
	push temp 
	clr temp 
	wait5sec: 
		rcall _delay1second
		inc temp
		cpi temp, 5 
		brne wait5sec

	pop temp
	ret

_delay9second: 
	push temp
	clr temp 
	wait9sec: 
		rcall _delay1second
		inc temp
		cpi temp, 9 
		brne wait9sec
	pop temp
	ret

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

digits: 
	.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, \
	0x6D, 0x7D, 0x07, 0x7F, 0x6F, \
	0x77, 0xFC, 0x39, 0x5E, 0x79, 0x79, 0x71, 0
;55969
pass: 
	.db 5,5,9,6,9,0