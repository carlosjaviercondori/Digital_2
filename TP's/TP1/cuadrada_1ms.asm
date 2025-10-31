#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

contvalor EQU .249  ; el punto me dice que es decimal
contador EQU 0x20   ; posicion de memoria general del primer banco
 
ORG 0x0000 
MOVLW   HIGH(MainApplication)	;esto me lo pidio el flasher pora no romper el bootloader
MOVWF   PCLATH
GOTO    MainApplication	


MainApplication: 
BCF STATUS, RP1 ;selecciono banco rp1 en cero
BSF STATUS, RP0	;selecciono banco 1 con el 01
BCF TRISC, 0  ;pongo el pin rc4 en salida
BCF STATUS, RP0 ;vuelvo al banco cero porque necesito usar el registro PORTC
    
INICIO: 
    BCF PORTC, 0 ;prendo el puerto c4
    call delay1ms
    BSF PORTC, 0 ;apago el puerto c4
    call delay1ms
    GOTO INICIO 


    
    
delay1ms:
    MOVLW contvalor
    MOVWF contador  
LOOP:
    NOP
    DECFSZ contador, f
    GOTO LOOP
    RETURN
    
    END