FUNC_SPI:
; SPI Function (Start - Send cmd - Exchange data - end)
; MSB send first
; Input:	A: Send cmd;	B: Send data;
; Return:	A: Get data;
	
	MISO	EQU	P3.4
	MOSI	EQU	P3.5
	SCLK	EQU	P3.6
	SS	EQU	P3.7
	
	
	func_spi_ini:
	PUSH	PSW				;Save current working space
	CLR	RS1
	CLR	RS0
	USING	0
	PUSH	AR0
	PUSH	AR1
	PUSH	AR2
	
	SETB	SCLK				;Function ini
	CLR	SS				;Enable transmission (SS)
	
	
	func_spi_byte1:
	MOV	R0, #8
	MOV	R1, A
	
	func_spi1_loop1:
	CLR	SCLK				;CLK falling_edge
	
	CLR	MOSI				;By default, send low. Will be set to high depends on MSB
	MOV	A, R1
	RL	A
	MOV	R1, A				;Get next bit (MSB first)
	RR	A
	ANL	A, #0x80			;Check current MSB
	JZ	func_spi_loop1_send_low		;Current bit is low (default), no need to set MOSI
	SETB	MOSI
	func_spi_loop1_send_low:

	SETB	SCLK				;CLK rising_edge

	DJNZ	R0, func_spi1_loop1
	
	
	func_spi_byte2:
	MOV	R0, #8
	MOV	R1, B
	MOV	R2, #0x00
	
	func_spi_loop2:
	CLR	SCLK				;CLK falling_edge
	
	CLR	MOSI				;By default, send low. Will be set to high depends on MSB
	MOV	A, R1
	RL	A
	MOV	R1, A				;Get next bit (MSB first)
	RR	A
	ANL	A, #0x80			;Check current MSB
	JZ	func_spi_loop2_send_low		;Current bit is low (default), no need to set MOSI
	SETB	MOSI
	func_spi_loop2_send_low:
	
	SETB	SCLK				;CLK rising_edge
	
	MOV	A, R2				;Shift receiver buffer
	RL	A
	MOV	R2, A
	JNB	MISO, func_spi_loop2_get_low	;Check current input. If low, no need to set buffer
	INC	R2				;By default, this bit is 0. To set, inc 1.
	func_spi_loop2_get_low:

	DJNZ	R0, func_spi_loop2

	func_spi_end:
	SETB	SS				;Disable SS
	MOV	A, R2				;Save receiver buffer
	
	POP	AR2				;Restore past working space
	POP	AR1
	POP	AR0
	POP	PSW
	RET
