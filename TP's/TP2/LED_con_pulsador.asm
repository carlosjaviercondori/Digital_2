#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;------------------------------------------------------------------------------
; PROGRAMA: LED con pulsador
; DESCRIPCIÓN: Este programa controla un LED alternando su estado entre
;             encendido y apagado cada vez que se presiona un pulsador
;             conectado a RC0. Incluye un retardo anti-rebote.
; 
; REGISTROS UTILIZADOS:
; - PORTD: Puerto de salida para controlar el LED
; - PORTC.0: Entrada para el pulsador
; - C1, C2: Registros para el retardo anti-rebote
;------------------------------------------------------------------------------

C1       EQU   0x22
C2       EQU   0x23

        ORG 0x00
        GOTO INICIO
        ORG 0x05

    INICIO: 
        BCF STATUS, RP1
        BSF STATUS, RP0 ;selecciono banco 1        
        CLRF TRISD      ;pongo el puerto D en salida        
        BSF TRISC, 0    ;pongo el pin RC0 en entrada        
        BCF STATUS, RP0 ;vuelvo al banco 0

        CLRF PORTD
        CALL ESPERAR
        MOVLW b'11111111'
        MOVWF PORTD
        CALL ESPERAR
        GOTO INICIO


    ESPERAR:
        BTFSS PORTC, 0
        GOTO ESPERAR
        CALL delay10ms
        BTFSS PORTC, 0
        GOTO ESPERAR
        RETURN
        
    delay10ms:
            MOVLW   .100
            MOVWF   C1
d1_l2:      MOVLW   .250
            MOVWF   C2
d1_l3:      NOP
            DECFSZ  C2, F
            GOTO    d1_l3
            DECFSZ  C1, F
            GOTO    d1_l2
            RETURN

    END
