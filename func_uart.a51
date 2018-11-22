FUNC_UART_SEND_STRING:
; UART Function, send a string
; Input:	DPTR: String pointer
; Output:	void
	CLR	A
	MOVC	A, @A+DPTR				;Get current char
	JZ	func_uart_send_string_end		;Break loop if string end (\0).
	MOV	SBUF, A
	INC	DPTR					;Pointer++
	JMP	$					;This is a WAI instruction, see UART.
	JMP	FUNC_UART_SEND_STRING
	func_uart_send_string_end:
	RET

FUNC_UART_SEND_CHAR:
; UART Function, send the value stored in ACC, in ascii
; Input:	ACC: The value
; Output:	void
	MOV	B, #100
	DIV	AB					;Get x00
	PUSH	B					;Reminder is 0xx
	ADD	A, #0x30				;Get ASCII, Dec 0~9 = ASCII 0x30~0x39
	MOV	SBUF, A					;Send, this will take a while. Calculate next char before WAIT(JMP$)
	
	POP	ACC					;Get 0xx
	MOV	B, #10
	DIV	AB					;Get 0x0
	PUSH	B
	ADD	A, #0x30				;Get ASCII
	PUSH	ACC
	JMP	$					;Wait x00 to be send (sending one char takes more than 1000 cycles)
	POP	SBUF					;Send 0x0
	
	POP	ACC					;get 00x
	ADD	A, #0x30
	PUSH	ACC
	JMP	$					;Wait 0x0 to be finish
	POP	SBUF					;Send 00x
	JMP	$					;Wait 00x finish
	
	RET
	

FUNC_UART_INT:
; UART interrupthandler
	JB	RI, func_uart_int_rx			;Check interrupt source
	
	func_uart_int_tx:
	CLR	TI					;Clear flag. Notice: the int subroutine will modify return PC. JMP $ is now WAI.
	
	POP	B					;Return address + 2
	POP	ACC
	ADD	A, #0x02				;Length of JMP$ = 2
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI
	
	func_uart_int_rx:
	
	CLR	RI
	
	POP	B
	POP	ACC
	ADD	A, #0x02
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI
