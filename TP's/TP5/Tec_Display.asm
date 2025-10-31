;-----------------------------------------------
    LIST P=16F887
    #include <p16f887.inc>

;---------------------------------bits de configuración------------------------
; CONFIG1
; __config 0xEFE2
    __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_ON & _FCMEN_ON & _LVP_OFF
; CONFIG2
; __config 0xFFFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; Variables
W_TEMP      EQU 0x70
STATUS_TEMP EQU 0x71
INDEX	    EQU 0x20      ; índice para display actual (0 a 3)
NUM0        EQU 0x21      ; valores a mostrar en displays
NUM1        EQU 0x22
NUM2        EQU 0x23
NUM3        EQU 0x24
INDEX_TECLADO EQU 0x25      ; índice para TECLADO (0 a 3)
CONTADOR_TECLA EQU 0X26
 
CONTADOR1 EQU 0X27	    ;CONTADOR PARA EL DELAY POR SOFTWARE
CONTADOR2 EQU 0X28	    ;CONTADOR PARA EL DELAY POR SOFTWARE
CONTADOR3 EQU 0X29	    ;CONTADOR PARA EL DELAY POR SOFTWARE
CONTADOR_COLUMNAS   EQU	0X30; CONTADOR PARA LLEVAR CUENTA DE LAS FILAS
CONTADOR_FILAS   EQU	0X31; CONTADOR PARA LLEVAR CUENTA DE LAS FILAS   
PORTB_AUX   EQU	0X32


;-----------------------------------------------
            ORG 0x00
            GOTO INICIO

            ORG 0x04
            GOTO ISR

;-----------------------------------------------
INICIO:
    MOVLW    0X00
    MOVWF   NUM0
    MOVWF   NUM1
    MOVWF   NUM2
    MOVWF   NUM3
    
    CLRF    PORTD
    CLRF    PORTC
    CLRF    INDEX_TECLADO

    ; --- Configuración de puertos ---
    
    BSF STATUS, 5
    BSF STATUS, 6 ; banco 3 ANSELH
    
    CLRF ANSELH ; Entradas digitales
    
    BSF     STATUS, RP0
    BCF     STATUS, RP1       ; Bank 1 OPTION_REG/TRISD/TRISC/TRISB/WPUB/IOCB

    CLRF    TRISD             ; RD0?RD7 como salida (DISPLAY)
    MOVLW   B'11110000'       ; RC0?RC3 como salida (TRANSISTORES), RC4?RC7 entrada
    MOVWF   TRISC
    
    ;CONFIG PUERTOS TECLADO
    
    MOVLW   b'11110000' 
    MOVWF   TRISB ; RB0-RB3 como SALIDA, el resto como ENTRADA
    MOVLW   b'11110000'
    MOVWF   WPUB  ; Habilitamos solo las resistencias de pull up DE RB4-RB7
    MOVLW   B'11110000'
    MOVWF   IOCB
    
    ; --- Configuración Timer0 ---
    MOVLW   B'00000111'       ; Prescaler 1:256 asignado a Timer0
    MOVWF   OPTION_REG
    
    BCF     STATUS, RP0	    ;BANCO 0
    
    MOVLW   D'237'
    MOVWF   TMR0              ; Inicializa TMR0 = 256-39
    
    CLRF PORTD
    CLRF PORTB	; COLOCAMOS CEROS EN LA PARTE BAJA
    MOVF    PORTB,F ; LEEMOS PUERTO B 
    
    ; --- Habilitación de interrupciones ---
    BSF	    INTCON, RBIE
    BSF     INTCON, TMR0IE
    BSF     INTCON, GIE

    ; --- Inicializa índice ---
    CLRF    INDEX

LOOP:
    GOTO    LOOP    ; acá esperamos interrupciones

;-----------------------------------------------
; --- Tabla de segmentos para 0?F ---
TABLA_DISPLAY:
    ADDWF   PCL, F
    RETLW   B'00111111' ; 0
    RETLW   B'00000110' ; 1
    RETLW   B'01011011' ; 2
    RETLW   B'01001111' ; 3
    RETLW   B'01100110' ; 4
    RETLW   B'01101101' ; 5
    RETLW   B'01111101' ; 6
    RETLW   B'00000111' ; 7
    RETLW   B'01111111' ; 8
    RETLW   B'01101111' ; 9
    RETLW   B'01110111' ; A
    RETLW   B'01111100' ; b
    RETLW   B'00111001' ; C
    RETLW   B'01011110' ; d
    RETLW   B'01111001' ; E
    RETLW   B'01110001' ; F

;-----------------------------------------------
    
;-----------------------------------------------
; Rutina para activar un display según índice
; Entrada: W = 0 a 3 ? RC0 a RC3

HABILITACION_DISPLAY:
    ADDWF   PCL, F
    RETLW   B'00000001' ; RC0
    RETLW   B'00000010' ; RC1
    RETLW   B'00000100' ; RC2
    RETLW   B'00001000' ; RC3

;-----------------------------------------------
    
    
    
ISR:

GUARDAR_CONTEXTO:    
    ; Guardado de contexto
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
    
    
DISCRIMINAR_INTERRUPCION:
    BTFSC   INTCON, RBIF
    GOTO    ISR_RBIE_TECLADO
    BTFSC   INTCON, T0IF
    GOTO    ISR_TMR0

;--------INICIO INTERRUPCIÓN DE TIMER0-------
ISR_TMR0
    
    MOVLW   D'237'	; RECARCAR TMR0 
    MOVWF   TMR0

    ; Apaga todos los selectores (RC0?RC3)
    CLRF    PORTC
    
    MOVLW   NUM0
    ADDWF   INDEX, W
    MOVWF   FSR
    MOVF    INDF, W
    ANDLW   0x0F       ; nos aseguramos que es 0?15
    CALL    TABLA_DISPLAY
    MOVWF   PORTD
    

    ; Activa el display correspondiente
    MOVF    INDEX, W
    CALL    HABILITACION_DISPLAY
    MOVWF   PORTC


    ; Incrementa índice (0?3)
    INCF    INDEX, F
    MOVF    INDEX, W
    XORLW   0x04
    BTFSC   STATUS, Z
    CLRF    INDEX
    
FIN_ISR_TMR0:
    ; Limpia interrupción Timer0
    BCF     INTCON, TMR0IF
    GOTO    FIN_ISR
;--------FINAL INTERRUPCIÓN DE TIMER0-------

;--------INICIO INTERRUPCIÓN DE RBIE-------    
ISR_RBIE_TECLADO:
    CLRF    CONTADOR_TECLA
;    CALL DELAY
BARRIDO_TECLADO:
    MOVLW   B'11111110'
    MOVWF   PORTB
    MOVLW   D'4'
    MOVWF   CONTADOR_COLUMNAS
    MOVWF   CONTADOR_FILAS
FILA
    BTFSS   PORTB, 4		;COLUMNA1
    GOTO    FIN_BARRIDO		;COLUMNA1
    INCF    CONTADOR_TECLA, F	;COLUMNA1
    BTFSS   PORTB, 5		;COLUMNA2
    GOTO    FIN_BARRIDO		;COLUMNA2
    INCF    CONTADOR_TECLA, F	;COLUMNA2
    BTFSS   PORTB, 6		;COLUMNA3
    GOTO    FIN_BARRIDO		;COLUMNA3
    INCF    CONTADOR_TECLA, F	;COLUMNA3
    BTFSS   PORTB, 7		;COLUMNA4
    GOTO    FIN_BARRIDO		;COLUMNA4
    INCF    CONTADOR_TECLA, F	;COLUMNA4
    RLF	    PORTB, F
    DECFSZ  CONTADOR_COLUMNAS
    GOTO    FILA
    GOTO    FIN_ISR_RBIE

;FILA
;    SWAPF   PORTB, W
;    MOVWF   PORTB_AUX
;COLUMNA
;    BTFSS   PORTB_AUX, 0		;COLUMNA1
;    GOTO    FIN_BARRIDO		;COLUMNA1
;    INCF    CONTADOR_TECLA, F	;COLUMNA1
;    RRF	    PORTB_AUX, F
;    DECFSZ  CONTADOR_FILAS, F	;eSTOY BARRIENDO LA FILA
;    GOTO    COLUMNA
;    MOVLW   D'4'
;    MOVWF   CONTADOR_FILAS
;    RLF	    PORTB, F
;    DECFSZ  CONTADOR_COLUMNAS
;    GOTO    FILA
;    GOTO    FIN_ISR_RBIE
    
    
FIN_BARRIDO:
    
    
    MOVLW   NUM0
    ADDWF   INDEX_TECLADO, W
    MOVWF   FSR
    MOVF    CONTADOR_TECLA, W
    MOVWF   INDF
    
    
    ; Incrementa índice DEL TECLADO (0?3)
    INCF    INDEX_TECLADO, F
    MOVF    INDEX_TECLADO, W
    XORLW   0x04
    BTFSC   STATUS, Z
    CLRF    INDEX_TECLADO

    GOTO    FIN_ISR_RBIE
    
FIN_ISR_RBIE:
    MOVLW   0X00
    MOVWF   PORTB   ; DEJAMOS PUERTO EN 0 PARA ESPERAR PRÓXIMA TECLA
    MOVF    PORTB, F	;REALIZAMOS UNA LECTURA DEL PUERTO PARA ACTUALIZAR VALOR
			;IOCB
    BCF     INTCON, RBIF   ; BAJAMOS BANDERA RBIE
    GOTO    FIN_ISR
;--------FINAL INTERRUPCIÓN DE RBIE-------    
    
FIN_ISR:
    
RECUPERAR_CONTEXTO:
    
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE


    
DELAY
    MOVLW   0X10
    MOVWF   CONTADOR1
    MOVWF   CONTADOR2
    MOVLW   0X05
    MOVWF   CONTADOR3

RETARDO1
    DECFSZ  CONTADOR1,1
    GOTO    RETARDO1
    MOVLW   0XFF
    MOVWF   CONTADOR1

RETARDO2
    DECFSZ  CONTADOR2,1
    GOTO    RETARDO1
    MOVLW   0XFF
    MOVWF   CONTADOR2

RETARDO3
    DECFSZ  CONTADOR3,1
    GOTO    RETARDO1
    RETURN
    END


;
;    MOVLW   B'11111110'
;    MOVWF   PORTB
;    
;    BTFSS   PORTB, 4		
;    GOTO    FIN_BARRIDO		
;    INCF    CONTADOR_TECLA, F	
;    BTFSS   PORTB, 5		
;    GOTO    FIN_BARRIDO		
;    INCF    CONTADOR_TECLA, F	
;    BTFSS   PORTB, 6		
;    GOTO    FIN_BARRIDO		
;    INCF    CONTADOR_TECLA, F	
;    BTFSS   PORTB, 7		
;    GOTO    FIN_BARRIDO		
;    INCF    CONTADOR_TECLA, F	
;    
;    
;    MOVLW   B'11111101'
;    MOVWF   PORTB
;    
;    BTFSS   PORTB, 4
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 5
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 6
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 7
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    
;    MOVLW   B'11111011'
;    MOVWF   PORTB
;    
;    BTFSS   PORTB, 4
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 5
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 6
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 7
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F   
;    
;    MOVLW   B'11110111'
;    MOVWF   PORTB
;    
;    BTFSS   PORTB, 4
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 5
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 6
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    BTFSS   PORTB, 7
;    GOTO    FIN_BARRIDO
;    INCF    CONTADOR_TECLA, F
;    GOTO    FIN_ISR_RBIE
