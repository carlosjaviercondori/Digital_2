#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

; Programa: Contador binario de 0 a 255 con retardo de 1 segundo
; Descripción: Este programa implementa un contador binario que cuenta de 0 a 255
; mostrando los valores en el PORTD. Cada incremento ocurre cada segundo.

; Definición de variables y constantes
; contador - usado para el retardo de 1 segundo (bucle externo)
; contador2 - usado para el retardo de 1 segundo (bucle medio)
; contador3 - usado para el retardo de 1 segundo (bucle interno)
; binario - almacena el valor actual del contador binario
; bucle - controla el número de iteraciones del contador (255 veces)



contador EQU 0x20   ; posición de memoria general del primer banco
contador2 EQU 0x21   ; posición de memoria general del primer banco
contador3 EQU 0x22   ; posición de memoria general del primer banco
binario EQU 0x23
bucle  EQU 0x24

ORG 0x00
GOTO INICIO
ORG 0x05

INICIO: 
    BCF STATUS, RP1
    BSF STATUS, RP0                    
    CLRF TRISD          
    BCF STATUS, RP0 
    MOVLW b'11111111'
    MOVWF bucle
    MOVLW b'00000000' 
    CALL CICLO
    GOTO INICIO

CICLO:
    MOVWF binario
    MOVF binario, w
    MOVWF PORTD           
    CALL delay1s
    INCF binario, w
    DECFSZ bucle, f
    GOTO CICLO
    RETURN

delay1s:
    ; cont1 = 4
    MOVLW   .4
    MOVWF   contador
L1:
    ; cont2 = 249
    MOVLW   .249
    MOVWF   contador2
L2:
    ; cont3 = 250
    MOVLW   .250
    MOVWF   contador3

L3:
    NOP
    DECFSZ  contador3, f
    GOTO    L3

    DECFSZ  contador2, f
    GOTO    L2

    DECFSZ  contador, f
    GOTO    L1

    RETURN
END
