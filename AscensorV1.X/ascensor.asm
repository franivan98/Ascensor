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
	CBLOCK	0x70
	W_TEMP
	STATUS_TEMP
	PISO_ACTUAL	
	PISO_OBJETIVO
	FUNCIONANDO   ;Bandera para controlar si el Ascensor esta subiendo
	SETEO	      ;Bandera para controlar si esta en modo seteo de piso
	SHIFTREG     ;registro auxiliar para controlar el teclado
	TECLA_PRESIONADA    
	DELAY1
	DELAY2
	DELAY3
	CONTADOR_TECLADO
	
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
	;Configuracion puerto c. RC6 como salida por TX, y RC7 como entrada 
	MOVLW	b'10000000'
	MOVWF	TRISC
	;configuracion de entradas
	BANKSEL	ANSEL
	CLRF	ANSELH
	MOVLW	b'11110000' ;(RB0,RB3) Como salida, (RB4,RB7 como como entrada)
	MOVWF	TRISB
	;configuracion general
	BANKSEL	WPUB
	MOVLW	b'00001111' ;habilito pullups, configuro prescaler a 256, y lo asigno al TMR0
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
	 CLRF	PISO_OBJETIVO
	 CLRF	FUNCIONANDO
	 CLRF	SETEO
	 CLRF	SHIFTREG
	 CLRF	TECLA_PRESIONADA
	 ;queda mostrando el display
	 CALL	MOSTRAR_DSPL
	 GOTO	$-1

MOSTRAR_DSPL
	 MOVF	TECLA_PRESIONADA,W
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
	 RETLW	.10
	 RETLW	.0
	 RETLW	.11
	 RETLW	.12
	 RETLW	.1
	 RETLW	.2
	 RETLW	.3
	 RETLW	.13
	 RETLW	.4
	 RETLW	.5
	 RETLW	.6
	 RETLW	.14
	 RETLW	.7
	 RETLW	.8
	 RETLW	.9
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
	;BTFSC	INTCON,T0IF
	;GOTO	TIMER0_ISR
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
	MOVF	CONTADOR_TECLADO,W
	CALL	TABLA_TECLADO
	MOVWF	TECLA_PRESIONADA
	;aca empezamos la logica para ver que hacemos
	MOVLW	.15
	SUBWF	TECLA_PRESIONADA,W
	BTFSC	STATUS,Z
	GOTO	RUTINA_EMERGENCIA
	MOVLW	.10
	SUBWF	TECLA_PRESIONADA,W
	BTFSC	STATUS,Z
	BSF	PORTC,3
	MOVLW	.11
	SUBWF	TECLA_PRESIONADA,W
	BTFSC	STATUS,Z
	BCF	PORTC,3
	GOTO	NINGUNA_TECLA
RUTINA_EMERGENCIA
	BCF	INTCON,T0IE
	BCF	INTCON,T0IF
	CLRF	TMR0
	BCF	PORTC,0
	BCF	PORTC,0
	BSF	PORTC,2
	BSF	PORTC,3
NINGUNA_TECLA
	BANKSEL	INTCON
	BCF	INTCON,RBIF
FIN_INTE	;RECUPERAR CONTEXTO
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W
	RETFIE
	END


