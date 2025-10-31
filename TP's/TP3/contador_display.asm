#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


;------------------------------------------------------------------------------
; PROGRAMA: Contador_display
; DESCRIPCIÓN: Este programa muestra en un display de 7 segmentos los dígitos
;              del 0 al 9 de forma secuencial en PORTD. 
;              - Al reset salta a INICIO donde configura PORTD como salida.
;              - Usa una tabla de constantes localizada en memoria (ORG 0x80)
;                para obtener los patrones de segmentos (RETLW) mediante una
;                llamada calculada (ADDWF PCL) en la rutina TABLA.
;              - Recorre los 10 dígitos mediante el índice INDICE y un bucle
;                controlado por BUCLE (inicializado en 10). Para cada dígito:
;                carga el patrón desde la tabla hacia PORTD, ejecuta un
;                retardo y avanza al siguiente dígito.
;              - El retardo lo realiza la rutina RETARDO con tres contadores
;                anidados (contador, contador2, contador3) para obtener un
;                retardo perceptible entre cambios de dígito.
;
; PUNTOS CLAVE:
; - Vector de reset: org 0x00 -> GOTO INICIO
; - Tabla de patrones: org 0x80, TABLA usa ADDWF PCL para indexar y RETLW
;   devuelve los patrones de segmentos para los dígitos 0..9.
; - El flujo principal está en la etiqueta LOOP que itera BUCLE veces.
;
; REGISTROS / MEMORIA UTILIZADOS:
; - PORTD   : Salida hacia el display de 7 segmentos (patrones de segmentos).
; - TRISD   : Dirección del puerto D (configurado a 0 en banco 1 para salida).
; - STATUS (RP0, RP1) : Bits usados para seleccionar banco de registros al
;                      configurar TRISD y al volver al banco 0.
; - PCL     : Usado implícitamente por TABLA (ADDWF PCL) para salto relativo
;            dentro de la tabla de RETLW.
; - W       : Registro de trabajo, usado para cálculos y llamadas.
;
; VARIABLES DEFINIDAS:
; - INDICE  (0x20) : Índice actual del dígito mostrado (0..9).
; - BUCLE   (0x21) : Contador de iteraciones del bucle principal (inicializado a 10).
; - contador (0x22) : Contador más externo para el retardo (carga inicial .4).
; - contador2 (0x23) : Contador intermedio para el retardo (carga inicial .249).
; - contador3 (0x24) : Contador más interno para el retardo (carga inicial .250).
;
; RUTINAS PRINCIPALES:
; - INICIO:
;     - Selecciona banco 1 (BSF STATUS, RP0) para escribir TRISD = 0.
;     - Vuelve a banco 0, limpia PORTD, INDICE y carga BUCLE con 10.
;     - Salta a LOOP.
; - LOOP:
;     - Usa INDICE como índice para llamar a TABLA (MOVF INDICE, W; CALL TABLA).
;     - Escribe el patrón devuelto en PORTD.
;     - Llama a RETARDO para mantener el dígito visible un tiempo.
;     - Incrementa INDICE e decrementa BUCLE; repite hasta agotar BUCLE.
; - TABLA:
;     - Usa ADDWF PCL para realizar un salto relativo en la tabla de RETLW.
;     - RETLW devuelve el patrón de segmentos (bits) para los dígitos 0..9.
; - RETARDO:
;     - Implementa un retardo por software con tres bucles anidados:
;       contador = 4, contador2 = 249, contador3 = 250 (valores cargados con MOVLW).
;     - Los DECFSZ/GOTO proporcionan la temporización acumulada hasta retornar.
;
; OBSERVACIONES:
; - Los patrones RETLW especifican los bits a poner en PORTD para cada dígito.
;   Dependiendo del tipo de display (ánodo/cátodo) puede requerirse inversión
;   de los bits o hardware adicional.
; - No se manejan interrupciones ni reinicios de INDICE cuando BUCLE finaliza;
;   el código vuelve a INICIO tras agotar el bucle (según la estructura de salto).
;------------------------------------------------------------------------------


INDICE EQU 0X20
BUCLE EQU 0X21
contador EQU 0x22   ; posición de memoria general del primer banco
contador2 EQU 0x23   ; posición de memoria general del primer banco
contador3 EQU 0x24   ; posición de memoria general del primer banco

        org 0x00
        GOTO INICIO
        ORG 0x05

    INICIO:
        BCF STATUS, RP1
        BSF STATUS, RP0 ;selecciono banco 1
        CLRF TRISD      ;pongo el puerto D en salida
        BCF STATUS, RP0 ;vuelvo al banco 0
        CLRF PORTD
        CLRF INDICE
        MOVLW .10
        MOVWF BUCLE
        GOTO LOOP
       

    
    LOOP:
        MOVF INDICE,w
        CALL TABLA
        MOVWF PORTD
        CALL RETARDO
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


RETARDO:
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
