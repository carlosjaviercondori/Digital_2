#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF


; ==============================================================================
; DOCUMENTACIÓN: "Interrupción con display"
;
; Propósito:
;   - Mostrar dígitos (0..9) en un display de 7 segmentos conectado a PORTD.
;   - Avanzar al siguiente dígito cuando ocurra una interrupción externa en RB0/INT.
;   - Contar hasta 10 pulsos (BUCLE) y reiniciar cuando se alcanza el límite.
;
; Hardware esperado:
;   - PORTD -> líneas del display de 7 segmentos (8 bits: a..g + punto opcional).
;   - RB0/INT -> pulsador o señal externa para generar la interrupción.
;   - Resistencias pull-up/pull-down según diseño del pulsador (posible uso de pull-ups).
;
; Comportamiento:
;   - Al iniciar:
;       * Se configuran los pines como digitales (CLRF ANSEL/ANSELH).
;       * Se pone TRISD como salida y RB0 como entrada.
;       * INDICE se inicializa a 0; BUCLE se inicializa en 10.
;       * Se habilitan interrupciones globales y la interrupción externa (INTE).
;   - Bucle principal:
;       * Lee INDICE, llama a TABLA (org 0x80) que devuelve el patrón de segmentos
;         mediante RETLW; carga el patrón en PORTD y repite.
;   - Rutina de interrupción (ISR):
;       * Guarda W y STATUS en variables temporales.
;       * Ejecuta delay20ms (anti-rebote).
;       * Verifica que INTF esté activa; si fue por INT:
;           - Incrementa INDICE.
;           - Decrementa BUCLE; si BUCLE llega a 0, se reinicia el programa.
;       * Limpia la bandera INTF y restaura contexto antes de RETFIE.
;
; Detalles de implementación:
;   - Tabla de patrones (org 0x80) ofrece los valores para 0..9 con RETLW.
;   - delay20ms: bucle de software aproximado (dos bloques) para anti-rebote.
;   - Uso de bancos: el código selecciona bancos con BCF/BSF STATUS, RP0/RP1.
;   - Guardado/restaurado en ISR: se usa SWAPF para mover STATUS a W y salvarlo.
;
; Variables (resumen):
;   INDICE       EQU 0x20  ; índice actual en la tabla (0..9)
;   BUCLE        EQU 0x21  ; contador límite (inicial 10)
;   C1, C2       EQU 0x22, 0x23 ; contadores temporales para delay
;   W_TEMP       EQU 0x24  ; guarda W en ISR
;   STATUS_TEMP  EQU 0x25  ; guarda STATUS en ISR
;
; Consideraciones / mejoras:
;   - Ajustar patrones según si el display es ánodo común o cátodo común.
;   - Ajustar tiempos de anti-rebote según el pulsador.
;   - Evaluar uso de pull-ups internos (OPTION_REG) si corresponde.
;   - Revisar restauración de STATUS/W si se observan fallos en la ISR.
; ==============================================================================

INDICE EQU 0X20
BUCLE EQU 0X21
C1 EQU 0x22   ; posición de memoria general del primer banco
C2 EQU 0x23   ; posición de memoria general del primer banco
W_TEMP EQU 0x24
STATUS_TEMP EQU 0x25

        org 0x00
        GOTO INICIO
        org 0x04
        GOTO ISR
        
        
        ORG 0x05    
    INICIO:
        banksel ANSEL
        CLRF ANSEL      ; Configuro todos los pines como digitales
        CLRF ANSELH 
        BCF STATUS, RP1
        BSF STATUS, RP0 ;selecciono banco 1
        CLRF TRISD      ;pongo el puerto D en salida
        BSF TRISB, 0
        BCF STATUS, RP0 ;vuelvo al banco 0
        CLRF INDICE
        MOVLW .10
        MOVWF BUCLE
        BSF INTCON, GIE ; Habilito interrupciones globales
        BCF INTCON, INTF ; Limpio la bandera de interrupción externa
        BSF INTCON, INTE ; Habilito la interrupción externa       
    
    LOOP:
        MOVF INDICE, w
        CALL TABLA 
        MOVWF PORTD
        GOTO LOOP


ISR:
        MOVWF W_TEMP ; Guardo el valor del registro W
        SWAPF STATUS, W ; Guardo el valor del registro STATUS
        MOVWF STATUS_TEMP
        CALL delay20ms
        BTFSS INTCON, INTF ; Verifico que la interrupción fue por INT
        GOTO EXIT_ISR ; Si no fue por INT, salgo de la ISR
        INCF INDICE, F
        DECFSZ BUCLE, F
        GOTO EXIT_ISR
        CLRF BUCLE
        GOTO INICIO

    EXIT_ISR:
        BCF INTCON, INTF ; Limpio la bandera de interrupción externa
        SWAPF STATUS_TEMP, W ; Restaura el valor del registro STATUS
        MOVWF STATUS_TEMP
        SWAPF W_TEMP, F ; Restaura el valor del registro W
        SWAPF W_TEMP, W
        RETFIE

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


    delay20ms:
            MOVLW   .200
            MOVWF   C1
d1_l2:      MOVLW   .500
            MOVWF   C2
d1_l3:      NOP
            DECFSZ  C2, F
            GOTO    d1_l3
            DECFSZ  C1, F
            GOTO    d1_l2
            ; repetir para ~20 ms
            MOVLW   .200
            MOVWF   C1
d2_l2:      MOVLW   .500
            MOVWF   C2
d2_l3:      NOP
            DECFSZ  C2, F
            GOTO    d2_l3
            DECFSZ  C1, F
            GOTO    d2_l2
            RETURN
END
