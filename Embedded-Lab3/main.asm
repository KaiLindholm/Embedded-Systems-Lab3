
; Embedded-Lab3.asm
;
; Created: 2/27/2023 8:20:33 PM
; Author : Kai Lindholm & James Ostrowski


.include "m328Pdef.inc"
;5555
.equ dp = 0x80
.equ underscore = 0x08
.equ dash = 0x40
.equ firstcode = 5
.equ secondcode = 5
.equ thirdcode = 9
.equ fourthcode = 6
.equ fifthcode = 9

.def value = r20		; A current number in the shift register
.def sequence = r16		; value of a sequence to be sent to Shift Register
.def input = r18		; r18 is the value from the RPG 
.def prevInput = r21	
.def temp = r18			
.def passDigit = r22	; the digit at passIndex
.def passbool = r23		; the number of correct indices in the password 
.def passIndex = r24	; the index the password is at in the program. 

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

	ldi		sequence, dash 
	rcall	display
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
	rcall	buttonPressed		; determine length of button pressed			; display a 0 to the 7-seg

	in		input, PINB			; load in current state of RPG
	andi	input, 0x01			; extract new input values 
	cp		prevInput, input	 
	brne	direction			; if the current current state is not the same, determine the direction
rtn: 
	mov		prevInput, input	; store current value of input, in previnput for next iteration 
	in		input, pinb			
	andi 	input, 0x03	
	cpi		input, 0x03			; check if the RPG is back at a non moving state
	brne	rtn					; if not, stay in rtn until true 
	rjmp	main		
			
buttonPressed:
	rcall _delay10ms		; 10ms button debounce
	checkReset: 			; checks if the button is still held down after 10ms 
		in input, PINB		
		sbrs input, PB5		
		rjmp resetCounter	; if so head to the reset counter to see if the button is held down for at least 2 seconds
	clr r28
	sbrc input, PB5
	rjmp check_pass
	rjmp main

resetCounter: 
	rcall _delay10ms			
	inc r28
	cpi R28, 200			; determines if the button has been held down for exactly 2 seconds. 
	breq resetchecksum		; once the counter reaches 2 seconds of delay, go to resetchecksum
	rjmp checkReset				

// only boots out of the subroutine once the button has been depressed. 
// user is locked into reset at this point
resetchecksum:		
	in input, PINB
	sbrc input, PB5			; if pin has been depressed. IE pin high, go to reset subroutine
	rjmp reset
	rjmp resetchecksum		; else stay in checksum 

direction: 
	in		temp, PINB
	andi	temp, 0x02
	lsr		temp
	cp		input, temp		; compares previous pin A state to current pin B state. 
	breq	increment 		; if the states are equal, RPG is moving CW; Increment
	rjmp	decrement 		; else states are not equal, RPG is moving CCW; Decrement

increment: 
	cpi		value, 0x10			; if the value is 16, we have reached the max value that can be displayed do nothing
	breq	rtn					
	
	inc		value
	adiw	Z, 1
	lpm		sequence, Z 

	rcall   display

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	rtn

decrement:
	cpi		value, 0x00
	breq	rtn					; if value has reached 0, do not allow shift reg to change states
	; ----------------
	dec		value				; if value is not zero, decrement value in register
	sbiw	Z, 0x01				 
	lpm		sequence, Z			; and decrement the location in program memory to the sequence of the SR
	
	rcall	display

	mov		prevInput, temp		; store current input in prev input for next iteration 
	rjmp	rtn

check_pass:						; only called once the pb has been pressed for less than a second 				
	rcall getPassDigit			
	inc passIndex				; increment the number of digits inputted 
	cpi passIndex, 0x06				
	breq final					; the user and inputted 5 digits, goto final to determine validity 

	cp passDigit, value 		; if the current digit of the password is equal to the value on the display 
	breq equal
	nonequal: 					; do nothing 
		rjmp main
	equal: 						; increment number of correct digits
		inc passbool
		rjmp main	
	final: 						; check if the number of correct digits is equal to the length of the passcode
		cpi passbool, 4			
		breq correct_password 	; if equal the user entered the correct password 
		rjmp incorrect_password ; else incorrect password 

getPassDigit: 					; maps the current passIndex to the corresponding value of the passcode
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

// loads the passcode digit into pass digit for comparison 
first: 
	ldi passDigit, firstcode
	ret 
second: 
	ldi passDigit, secondcode
	ret 
third: 
	ldi passDigit, thirdcode
	ret 
fourth: 
	ldi passDigit, fourthcode
	ret 
fifth: 
	ldi passDigit, fifthcode
	ret 

correct_password:		; turn on the decimal point for 5 seconds 
	cbi PORTB, PB5		; toggless PB5, which is light L on the arduino 
	rcall _delay10ms	

	ldi sequence, dp	
	rcall display
	sbi PORTB, PB5
	rcall _delay5second	

	rjmp reset			

incorrect_password: 	; display an underscore for 9 seconds, then reset. 
	ldi sequence, underscore
	rcall display
	rcall _delay9second

	rjmp reset

; prescalar: 64 start value: 6
; temp is used through the delay subroutines. pushing temp to the stack, stores the previous calls 
; value of temp. Used to keep the number of registers used in these subroutines to 1. 
_delay1ms: 
	push	temp				
	ldi		temp, 6
	out		TCNT0, temp
	clr		temp
	wait: 
		in		temp, TCNT0
		cpi		temp, 0x00		; has the overflow bit been set
		brne	wait			; if not wait. 

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

; digits from 0-f 
digits: 
	.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, \
	0x6D, 0x7D, 0x07, 0x7F, 0x6F, \
	0x77, 0x7C, 0x39, 0x5E, 0x79, 0x79, 0x71, 0