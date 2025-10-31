#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


;------------------------------------------------------------------------------
; PROGRAMA: Display con pulsador (TP3)
; DESCRIPCIÓN:
; Este programa recorre una tabla de patrones para un display de 7 segmentos
; (valores 0-9) y presenta cada patrón en un puerto de salida. El avance al
; siguiente patrón se realiza al pulsar un pulsador conectado en RC0. Se
; implementa un retardo anti-rebote simple antes de aceptar la pulsación.
;
; ESTRUCTURA GENERAL:
; - Vector de reset: salta a INICIO.
; - INICIO: configura bancos, puertos y variables (TRISD salida, RC0 entrada).
; - LOOP: usa INDICE como índice en la tabla (TABLA) para obtener el patrón,
;         lo escribe a puerto (MOVWF PORD en el código; parece apuntar a PORTD),
;         espera la pulsación con ESPERAR (anti-rebote), incrementa INDICE y
;         decrementa el contador BUCLE para limitar el número de iteraciones.
; - TABLA (org 0x80): tabla de RETLW con los patrones de 7 segmentos para 0-9.
; - ESPERAR: espera que RC0 esté en 1 (pulsador), llama al retardo y confirma
;           que sigue presionado antes de retornar (anti-rebote).
; - delay10ms: bucle de retardo usando C1 y C2 como contadores.
;
; CONSTANTES / MEMORIA:
; - INDICE EQU 0x20 : índice actual para la tabla (incrementado en cada pulsación)
; - BUCLE  EQU 0x21 : contador de iteraciones (inicializado a 10)
; - C1     EQU 0x22 : registro temporal usado en delay10ms
; - C2     EQU 0x23 : registro temporal usado en delay10ms
;
; REGISTROS Y PUERTOS UTILIZADOS:
; - STATUS.RP1/RP0 : selección de banco para acceso a registros TRIS/PORT
; - TRISD  : configuración del puerto D como salida (control del display)
; - TRISC,0: bit para configurar RC0 como entrada (pulsador)
; - PORTD  : puerto de salida para mandar los segmentos al display
; - PORTC,0: entrada para el pulsador (RC0)
; - PCL    : usado por la rutina TABLA para hacer salto indirecto a RETLW
; - C1, C2 : registros temporales para los bucles de retardo
;
; RUTINAS PRINCIPALES:
; - TABLA (org 0x80):
;     Implementada con ADDWF PCL para indexar la tabla de RETLW. Cada RETLW
;     devuelve un patrón de 8 bits para el display (códigos para 0..9).
;
; - ESPERAR:
;     1) Bucle hasta que PORTC.0 sea 1 (espera pulsación).
;     2) CALL delay10ms para anti-rebote.
;     3) Verifica nuevamente PORTC.0; si dejó de estar presionado vuelve al
;        bucle esperando otra pulsación.
;     4) Retorna cuando la pulsación se considera válida (presionado tras delay).
;
; - delay10ms:
;     Doble bucle decreciente (C1 y C2) con NOPs para generar un retardo de
;     aproximadamente 10 ms (dependiente de la frecuencia de CPU).
;
; NOTAS Y OBSERVACIONES:
; - El código cambia a banco 1 para configurar TRISD y TRISC, luego vuelve al
;   banco 0 para operar con PORTD/PORTC.
; - El valor inicial de BUCLE (.10) limita el número de iteraciones del loop.
; - En el código se usa "MOVWF PORD" para escribir el patrón; parece ser un
;   error tipográfico y probablemente debería ser "MOVWF PORTD" para actualizar
;   el puerto D con el patrón obtenido de la tabla.
;
;------------------------------------------------------------------------------ 

INDICE EQU 0X20
BUCLE EQU 0X21
C1 EQU 0x22   ; posición de memoria general del primer banco
C2 EQU 0x23   ; posición de memoria general del primer banco

        org 0x00
        GOTO INICIO
        ORG 0x05

    INICIO:
        BCF STATUS, RP1
        BSF STATUS, RP0 ;selecciono banco 1
        CLRF TRISD      ;pongo el puerto D en salida
        BSF TRISC, 0
        BCF STATUS, RP0 ;vuelvo al banco 0
        CLRF PORTD
        CLRF INDICE
        MOVLW .10
        MOVWF BUCLE
        GOTO LOOP
       

    
    LOOP:
        MOVF INDICE, w
        CALL TABLA 
        MOVWF PORTD
        CALL ESPERAR
        INCF INDICE, F
        DECFSZ BUCLE, F
        GOTO LOOP
        GOTO INICIO



org 0X80
TABLA:
    ADDWF PCL, F

RETLW B'00111111' ;0  
RETLW B'00110000' ;1           __
RETLW B'01011011' ;2          |  | 
RETLW B'01001111' ;3           __
RETLW B'01100110' ;4          |  |
RETLW B'01101101' ;5           __ . 
RETLW B'01111101' ;6
RETLW B'00000111' ;7
RETLW B'01111111' ;8
RETLW B'01100111' ;9


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
