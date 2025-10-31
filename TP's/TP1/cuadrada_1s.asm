#include "p16f887.inc"
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

contador EQU 0x20   ; posicion de memoria general del primer banco
contador2 EQU 0x21
contador3 EQU 0x22



ORG 0x0000 
MOVLW   HIGH(MainApplication)	;esto me lo pidio el flasher pora no romper el bootloader
MOVWF   PCLATH
GOTO    MainApplication	


MainApplication: 
BCF STATUS, RP1 ;selecciono banco rp1 en cero
BSF STATUS, RP0	;selecciono banco 1 con el 01
BCF TRISD, 0  ;pongo el pin RD0 en salida
BCF STATUS, RP0 ;vuelvo al banco cero porque necesito usar el registro PORTD
    
INICIO: 
    BCF PORTD, 0 ;apago el puerto RD0
    call delay1s
    BSF PORTD, 0 ;prendo el puerto RD0
    call delay1s
    GOTO INICIO 
    
    
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
