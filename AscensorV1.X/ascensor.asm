;*------------------------------------------------------------------------------
;* Descripcion del Hardware: 
;* Display de 7 segmentos de catodo comun conectado
;* al puerto D. Motor conectado a los pines RC0 y RC1. Buzzer de llegada al piso
;* conectado al puerto RC2. Luz interna del ascensor al puerto RC3
;* Teclado matricial 4x4 conectado al puerto b.
;*------------------------------------------------------------------------------
; Autor: Franco Mamani
;*------------------------------------------------------------------------------
;*******************************************************************************

;****Encabezado****
    LIST P=16F887
    #INCLUDE "p16f887.inc"

;****Configuracion General****
	; CONFIG1
	; __config 0x2FF1
	    __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
	; CONFIG2
	; __config 0x3FFF
	    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;****Definicion de Variables****
	    
	CBLOCK	    0x20
	PISO_ACTUAL	
	PISO_OBJETIVO
	CONTADOR_PITS	
	ENDC
	
	CBLOCK	0x70
	W_TEMP
	STATUS_TEMP
	FLAGS_REG	;Registro de banderas para el ascensor. bit0: Funcionando; bit1: sonando; bit2: solo sensores; bit3: 
	SHIFTREG	;registro para rotar. nos sirve para hacer el pulling del teclado
	TECLA_PRESIONADA   
	PRESIONADO	;Bandera para verificar si se presiono un boton o no.
	DELAY1
	DELAY2
	DELAY3
	CONTADOR_TECLADO
	CONTADOR_TIMER
	ENDC
;****Inicio del Micro****
	ORG 0x00
	GOTO	INICIO
	ORG 0x04
	GOTO	ISR_INICIO
	ORG 0x05


INICIO	
	;Configuracion de puertos de salida
	;Configuracion del display
	BANKSEL	TRISD
	CLRF	TRISD
	;Configuracion puerto c como salida
	CLRF	TRISC
	;Configuracion TRANSMISION
	BANKSEL	SPBRG
	MOVLW	.25
	MOVWF	SPBRG
	MOVLW	b'00100100'	;trabajo con 9600 Baudios
	MOVWF	TXSTA
	BANKSEL	RCSTA
	MOVLW	b'10000000'
	MOVWF	RCSTA
	;configuracion de entradas
	BANKSEL	ANSEL
	CLRF	ANSELH
	MOVLW	b'11110000' ;(RB0,RB3) Como salida, (RB4,RB7 como como entrada)
	MOVWF	TRISB
	;configuracion general
	BANKSEL	WPUB
	MOVLW	b'00000111' ;habilito pullups, configuro prescaler a 256, y lo asigno al TMR0
	MOVWF	OPTION_REG
	MOVLW	b'11110000'
	MOVWF	WPUB
	;configuracion de interrupciones
	MOVLW	b'10001000'; habilito interrupciones globales, rb. AQUI HABILITAR INTERRPCIONES POR PUERTO SERIE SI SE PUEDE
	MOVWF	INTCON
	MOVLW	b'11110000' ;interrupcion por puerto b solo a RB4,RB5,RB6,RB7
	MOVWF	IOCB
	
;Programa principal
	 ;inicializaciones
	 BANKSEL PORTD
	 MOVLW	b'11110000'
	 MOVWF	PORTB
	 CLRF	PORTC
	 CLRF	PORTD
	 CLRF	PISO_ACTUAL
	 BSF	PISO_ACTUAL,0	;inicializo el piso actual en 1
	 CLRF	PISO_OBJETIVO
	 CLRF	FLAGS_REG
	 CLRF	SHIFTREG
	 CLRF	TECLA_PRESIONADA
	 CLRF	PRESIONADO
	 ;Transmito piso 1 al puerto serie
	 MOVLW	0x31
	 MOVWF	TXREG
	 
LOOP_MAIN	 
	 BTFSS	PRESIONADO,0		;verifica si se presiono una tecla del teclado. si no se presiono niguna, solo muestra el display.
	 GOTO	MOSTRAR
	 ;verifica si se presiono la tecla de emergencia (15)
	 MOVLW	.15
	 SUBWF	TECLA_PRESIONADA,W
	 BTFSC	STATUS,Z
	 GOTO	EMERGENCIA
	 BCF	PRESIONADO,0
	 ;verificamos si es una tecla de llamado, o un sensor
	 MOVLW	.5
	 SUBWF	TECLA_PRESIONADA,W
	 BTFSC	STATUS,C
	 GOTO	VERIF2
	 BSF	FLAGS_REG,2	    ;habilito la bandera de que se presiono un boton, no un sensor
	 GOTO	TESTEAR
VERIF2
	 BCF	FLAGS_REG,2	    ;deshabilito la bandera. esto significa que se presiono un sensor
	 MOVLW	.9
	 SUBWF	TECLA_PRESIONADA,W
	 BTFSC	STATUS,C	    ;si no es un sensor, y un llamado, no hago nada
	 GOTO	TESTEAR
	 GOTO	RESTAR
RESTAR
	 ;enviar piso actual antes de restar
	 MOVLW	.44
	 ADDWF	TECLA_PRESIONADA,W
	 MOVWF	TXREG
	 ;----------------------------
	 MOVLW	.4
	 SUBWF	TECLA_PRESIONADA,F
TESTEAR
	 BTFSS	FLAGS_REG,0	    ;si esta funcionando, solo actualizo el piso actual
	 GOTO	NO_FUNCIONANDO
	 BTFSC	FLAGS_REG,2
	 GOTO	MOSTRAR
	 MOVF	TECLA_PRESIONADA,W
	 MOVWF	PISO_ACTUAL
	 SUBWF	PISO_OBJETIVO,W
	 BTFSS	STATUS,Z
	 GOTO	MOSTRAR
	 BCF	PORTC,0
	 BCF	PORTC,1
	 BTFSC	FLAGS_REG,1
	 GOTO	MOSTRAR
	 BSF	FLAGS_REG,1
	 MOVLW	.61
	 MOVWF	TMR0
	 MOVLW	.10
	 MOVWF	CONTADOR_TIMER
	 MOVWF	CONTADOR_PITS
	 BCF	INTCON,T0IF
	 BSF	INTCON,T0IE
	 BSF	PORTC,2
	 GOTO	MOSTRAR
NO_FUNCIONANDO
	 MOVF	TECLA_PRESIONADA,W
	 MOVWF	PISO_OBJETIVO
	 SUBWF	PISO_ACTUAL,W
	 BTFSC	STATUS,Z
	 GOTO	MOSTRAR
	 BSF	FLAGS_REG,0
	 BTFSC	STATUS,C
	 GOTO	ARRIBA
	 GOTO	ABAJO
ARRIBA
	 BSF	PORTC,0
	 BCF	PORTC,1
	 GOTO	MOSTRAR
ABAJO
	 BCF	PORTC,0
	 BSF	PORTC,1
	 GOTO	MOSTRAR
	 
MOSTRAR	 CALL	MOSTRAR_DSPL
	 GOTO	LOOP_MAIN
EMERGENCIA
	 BSF	PORTC,2
	 BCF	PORTC,0
	 BCF	PORTC,1
	 MOVLW	0x45
	 MOVWF	TXREG
	 GOTO	$-1
MOSTRAR_DSPL
	 MOVF	PISO_ACTUAL,W
	 CALL	TABLA_DSPL
	 MOVWF	PORTD
	 RETURN

TABLA_DSPL
	 ADDWF	PCL,F
	 RETLW	0x3F
	 RETLW	0x06
	 RETLW	0x5B
	 RETLW	0x4F
	 RETLW	0x66 
	 RETLW	0x6D
	 RETLW	0x7D
	 RETLW	0x07
	 RETLW	0x7F
	 RETLW	0x6F
	 RETLW	0x77
	 RETLW	0x7C
	 RETLW	0x39
	 RETLW	0x5E
	 RETLW	0x79
	 RETLW	0x71

TABLA_TECLADO
	 ADDWF	PCL,F
	 RETLW	.4
	 RETLW	.4
	 RETLW	.8
	 RETLW	.12
	 RETLW	.3
	 RETLW	.3
	 RETLW	.7
	 RETLW	.13
	 RETLW	.2
	 RETLW	.2
	 RETLW	.6
	 RETLW	.14
	 RETLW	.1
	 RETLW	.1
	 RETLW	.5
	 RETLW	.15
RETARDO
	MOVLW	D'210'
	MOVWF	DELAY1
LOOP1	MOVLW	D'3'
	MOVWF	DELAY2
LOOP2	MOVLW	D'1'
	MOVWF	DELAY3
LOOP3	DECFSZ	DELAY3,F
	GOTO	LOOP3
	DECFSZ	DELAY2,F
	GOTO	LOOP2
	DECFSZ	DELAY1,F
	GOTO	LOOP1
	RETURN
ISR_INICIO
	;GUARDAR CONTEXTO
	MOVWF	W_TEMP
	SWAPF	STATUS,W
	MOVWF	STATUS_TEMP
	;INTERRUPCION
	BTFSC	INTCON,T0IF
	GOTO	ISR_TIMER
	BTFSS	INTCON,RBIF
	GOTO	FIN_INTE
	;Interrupcion por Puerto B
	CLRF	CONTADOR_TECLADO
	MOVLW	b'00001111'
	MOVWF	SHIFTREG
LOOPI	BCF	STATUS,C
	RLF	SHIFTREG,F
	MOVF	SHIFTREG,W
	MOVWF	PORTB
	BTFSS	PORTB,RB4
	GOTO	FIN_RB
	INCF	CONTADOR_TECLADO
	BTFSS	PORTB,RB5
	GOTO	FIN_RB
	INCF	CONTADOR_TECLADO
	BTFSS	PORTB,RB6
	GOTO	FIN_RB
	INCF	CONTADOR_TECLADO
	BTFSS	PORTB,RB7
	GOTO	FIN_RB
	INCF	CONTADOR_TECLADO
	MOVLW	0x10
	SUBWF	CONTADOR_TECLADO,W
	BTFSS	STATUS,Z
	GOTO	LOOPI
	GOTO	NINGUNA_TECLA
FIN_RB	CALL	RETARDO
	BSF	PRESIONADO,0
	MOVF	CONTADOR_TECLADO,W
	CALL	TABLA_TECLADO
	MOVWF	TECLA_PRESIONADA
NINGUNA_TECLA
	BANKSEL	INTCON
	BCF	INTCON,RBIF
	GOTO	FIN_INTE
	;Interrupcion por timer 0
ISR_TIMER
	BCF	INTCON,T0IF
	BTFSS	FLAGS_REG,1
	GOTO	FIN_INTE
	DECFSZ	CONTADOR_TIMER,F
	GOTO	CONTINUE
	GOTO	SONAR
CONTINUE
	MOVLW	.61
	MOVWF	TMR0
	GOTO	FIN_INTE
SONAR
	DECFSZ	CONTADOR_PITS,F
	GOTO	SETEAR_BUZZER
	GOTO	FIN_TMR0
SETEAR_BUZZER
	MOVLW	.10
	MOVWF	CONTADOR_TIMER
	BTFSS	PORTC,2
	GOTO	$+3
	BCF	PORTC,2
	GOTO	$+2
	BSF	PORTC,2
	GOTO	FIN_INTE
FIN_TMR0
	BCF	PORTC,2
	BCF	INTCON,T0IE
	CLRF	FLAGS_REG
	
	;--------rutina por timer0----------------
FIN_INTE	;RECUPERAR CONTEXTO
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W
	RETFIE
	END


