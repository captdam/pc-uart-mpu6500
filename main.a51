;SFR - STC89C52RC
	XICON		EQU	0xC0
	T2CON		EQU	0xC8
	T2MOD		EQU	0xC9
	RCAP2L		EQU	0xCA
	RCAP2H		EQU	0xCB
	TL2		EQU	0xCC
	TH2		EQU	0xCD
	WDT_CONTR	EQU	0xE1
	ISP_DATA	EQU	0xE2
	ISP_ADDRH	EQU	0xE3
	ISP_ADDRL	EQU	0xE4
	ISP_CMD		EQU	0xE5
	ISP_TRIG	EQU	0xE6
	ISP_CONTR	EQU	0xE7
	P4		EQU	0xE8
	
	ET2		EQU	IE.5
	TF2		EQU	T2CON.7
	EXF2		EQU	T2CON.6
	RCLK		EQU	T2CON.5
	TCLK		EQU	T2CON.4
	EXEN2		EQU	T2CON.3
	TR2		EQU	T2CON.2
	C_T2		EQU	T2CON.1
	CP_RL2		EQU	T2CON.0

;App config
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
	WAIT100		EQU	100000-0x10000

;App const
	MPU_READ	EQU	0x80
	MPU_WRITE	EQU	0x00

;App global variables
	SENSOR_AXH	EQU	0x3B			;Address of sensor data on MPU6500 and this MCU is same
	SENSOR_AXL	EQU	0x3C			;so I won't get confuse
	SENSOR_AYH	EQU	0x3D
	SENSOR_AYL	EQU	0x3E
	SENSOR_AZH	EQU	0x3F
	SENSOR_AZL	EQU	0x40
	SENSOR_TEMPH	EQU	0x41
	SENSOR_TEMPL	EQU	0x42
	SENSOR_GXH	EQU	0x43
	SENSOR_GXL	EQU	0x44
	SENSOR_GYH	EQU	0x45
	SENSOR_GYL	EQU	0x46
	SENSOR_GZH	EQU	0x47
	SENSOR_GZL	EQU	0x48
	
	
;Interrupt vector map
ORG	0x0000
	JMP	INI
ORG	0x0003
	JMP	INT_0
ORG	0x000B
	JMP	TIMER_0
ORG	0x0013
	JMP	INT_1
ORG	0x001B
	JMP	TIMER_1
ORG	0x0023
	JMP	UART
ORG	0x002B
	JMP	TIMER_2

; MAIN CODE --------------------------------------------

INI:							;Boot setup
	MOV	SP, #0x7F
	
	MOV	SCON, #0x40				;UART mode1 (8-bit, flex baud), disable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	SETB	EA
	
	CALL	FUNC_WAIT100				;Wait for 500ms
	CALL	FUNC_WAIT100
	CALL	FUNC_WAIT100
	CALL	FUNC_WAIT100
	CALL	FUNC_WAIT100

MAIN:
	MOV	DPTR, #string_mcu_ready			;Pointer to string data: MCU Ready
	CALL	FUNC_UART_SEND_STRING
	
	MOV	A, #0x75|MPU_READ			;Check sensor ID, it should be 0x70; otherwise halt here
	CALL	FUNC_SPI
	CJNE	A, #0x70, $
	
	MOV	A, #0x6B|MPU_WRITE			;Reset sensor module
	MOV	B, #0x81
	CALL	FUNC_SPI
	CALL	FUNC_WAIT100
	
	MOV	A, #0x68|MPU_WRITE			;Reset sensors
	MOV	B, #0x07
	CALL	FUNC_SPI
	CALL	FUNC_WAIT100
	
;	MOV	A, #0x6A|MPU_WRITE			;Enable sensor FIFO
;	MOV	B, #0x40
;	CALL	FUNC_SPI
	
	
	
	MOV	DPTR, #string_sensor_ready		;Sensor ready
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL
	
	string_mcu_ready:	DB	"MCU Ready boot finished!",13,10,0
	string_sensor_ready:	DB	"Sensor MPU6500 reset finished!",13,10,0

IDEL:							;Wait for command
	MOV	DPTR, #string_system_ready
	CALL	FUNC_UART_SEND_STRING
	
	SETB	REN					;Enable UART Rx, idel
	JMP	$					;Wait input
	CLR	REN					;Stop listen, busy
	
	MOV	A, SBUF					;Instruction decode
	JB	ACC.7, SENSOR_ENABLE			;Input: 0x80
	JB	ACC.6, SENSOR_DISABLE			;Input: 0x40
	JB	ACC.5, SENSOR_SCAN			;Input: 0x20
	JB	ACC.4, SENSOR_CAPTURE			;Input: 0x10
	JB	ACC.3, SENSOR_PRINT			;Input: 0x08
	
	MOV	DPTR, #string_bad_command		;Unknown command
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL	

SENSOR_ENABLE:
	MOV	DPTR, #string_sensor_enable		;command name
	CALL	FUNC_UART_SEND_STRING
	
	CALL	FUNC_SENSOR_ENABLE
	
	MOV	DPTR, #string_done			;Done!
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL

SENSOR_DISABLE:
	MOV	DPTR, #string_sensor_disable		;command name
	CALL	FUNC_UART_SEND_STRING
	
	CALL	FUNC_SENSOR_DISABLE
	
	MOV	DPTR, #string_done			;Done!
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL

SENSOR_SCAN:
	MOV	DPTR, #string_scan_sensor		;command name
	CALL	FUNC_UART_SEND_STRING
	
	CALL	FUNC_SENSOR_SCAN
	
	MOV	DPTR, #string_done			;Done!
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL

SENSOR_CAPTURE:
	MOV	DPTR, #string_capture_sensor		;command name
	CALL	FUNC_UART_SEND_STRING
	
	CALL	FUNC_SENSOR_CAPTURE
	
	MOV	DPTR, #string_done			;Done!
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL

SENSOR_PRINT:
	MOV	DPTR, #string_print_data		;command name
	CALL	FUNC_UART_SEND_STRING
	
	CALL	FUNC_SENSOR_PRINT
	
	MOV	DPTR, #string_done			;Done!
	CALL	FUNC_UART_SEND_STRING
	
	JMP	IDEL
	
IDEL_STRING_TABLE:
	string_system_ready:	DB	13,10,"System ready",9,"Stand by...",13,10,"Console> ",0
	string_sensor_enable:	DB	"Sensor enable",13,10,0
	string_sensor_disable:	DB	"Sensor disable",13,10,0
	string_scan_sensor:	DB	"Scan sensor data",13,10,0
	string_capture_sensor:	DB	"Sensor data capture",13,10,0
	string_print_data:	DB	"Print sensor data",13,10,0
	string_bad_command:	DB	"Unknown command",13,10,0
	string_done:		DB	13,10,"Done!",13,10,0

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	
	POP	B					;Return address + 2
	POP	ACC
	ADD	A, #0x02				;Length of JMP$ = 2
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI

INT_1:
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:
	JMP	FUNC_UART_INT				;Go to the handler

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------

FUNC_WAIT100:						;In fact, a little bit longer than 100ms :P
	MOV	TH0, #HIGH WAIT100			;Reset timer2 to ini value
	MOV	TL0, #LOW WAIT100
	SETB	TR0					;Enable timer2
	JMP	$					;100ms-2^16us passed, pc moved to next line in interrupt subroutine
	JMP	$					;2^16us passed
	CLR	TR0					;Stop timer
	RET

FUNC_SENSOR_ENABLE:
	MOV	A, #0x6B|MPU_WRITE			;Disable sleep mode
	MOV	B, #0x00
	CALL	FUNC_SPI
	
	RET

FUNC_SENSOR_DISABLE:
	MOV	A, #0x6B|MPU_WRITE			;Enable sleep mode
	MOV	B, #0x40
	CALL	FUNC_SPI
	
	RET

FUNC_SENSOR_SCAN:
	MOV	R0, #SENSOR_AXH				;Address A-X high, first data
	
	func_sensor_fetch_loop:
	MOV	A, #MPU_READ				;Generate command, based on target address saved in R0
	ORL	A, R0
	CALL	FUNC_SPI				;Execute SPI function, get data from sensor
	MOV	@R0, A					;Save data in local RAM
	INC	R0					;Get next address
	CJNE	R0, #SENSOR_GZL+1, func_sensor_fetch_loop
	
	RET

FUNC_SENSOR_CAPTURE:
	CALL	FUNC_SENSOR_DISABLE			;TODO	Read from FIFO instead scan in sleeping mode
	CALL	FUNC_SENSOR_SCAN
	CALL	FUNC_SENSOR_ENABLE
	RET

FUNC_SENSOR_PRINT:
	MOV	DPTR, #template_print			;Template, first string
	MOV	R0, #SENSOR_AXH
	
	func_sensor_print_loop:
	CALL	FUNC_UART_SEND_STRING			;Print string in the template (the template is a string set)
	INC	DPTR
	
	MOV	A, @R0					;Get data and print
	CALL	FUNC_UART_SEND_CHAR
	
	INC	R0
	CJNE	R0, #SENSOR_GZL+1, func_sensor_print_loop
	
	RET
	
	template_print:		DB	"AX: ",0," - ",0,13,10,"AY: ",0," - ",0,13,10,"AZ: ",0," - ",0,13,10,"TE: ",0," - ",0,13,10,"GX: ",0," - ",0,13,10,"GY: ",0," - ",0,13,10,"GZ: ",0," - ",0


; EXTERNAL FUNCTIONS -----------------------------------

$INCLUDE(func_spi.a51)
$INCLUDE(func_uart.a51)


; CONSTANT DATA TABLES ---------------------------------



END;
