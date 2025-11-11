# Voltímetro PIC16F887 — Voltimetro_1.0.asm 🔋🔍

Descripción 💡  
- Programa en ensamblador para PIC16F887 que mide una tensión en AN0 (RA0) y la muestra en un display 3×7 segmentos multiplexado.  
- Escala 0..5.00 V → se muestra como NUM2.NUM1NUM0 (ej. 2.54 V → 2 . 5 4).  
- Envía por UART (RC6 TX) el valor bruto de ADRESH en cada conversión (útil para depuración). 📶

Características principales ✨  
- ADC en AN0, justificación izquierda (uso de ADRESH como 8‑bit).  
- Conversión aritmética a V*100 (0..500) y separación en 3 dígitos.  
- Multiplexado de displays por Timer0 (refresco periódico). ⏱️  
- Punto decimal (RD7) activo en el primer dígito (se ve "siempre encendido" por el refresco). 🔸  
- UART TX a ~19200 bps (Fosc = 4 MHz). 🔁

Mapa de pines (resumen) 📌
| PIC16F887 pin (port) | Función                        | Nota |
|----------------------|--------------------------------|------|
| RA0 (AN0)            | Entrada analógica              | 0..5 V (usar divisor/protección) ⚠️ |
| RD0..RD6             | Segmentos a..g del 7‑seg       | resistencias serie ≈ 330 Ω 🔧 |
| RD7                  | Punto decimal (dp)             | Encendido para primer dígito 🔸 |
| RB7                  | Enable dígito unidades (act. 0)| Driver recomendado (NPN) ✅ |
| RB6                  | Enable dígito decenas (act.0)  | Driver recomendado (NPN) ✅ |
| RB5                  | Enable dígito centenas (act.0) | Driver recomendado (NPN) ✅ |
| RC6 (TX)             | UART TX                        | 19200 bps aprox. 📡 |
| Vdd, Vss             | +5V, GND                       | Desacoplar con 0.1 µF 🧾 |

Ejemplo de lectura 📈  
- Entrada: 2.54 V en AN0  
- ADRESH → ADC8 ≈ 254  
- Conversión interna → NUM2 = 2, NUM1 = 5, NUM0 = 4  
- Visual: 2 . 5 4 (RD7 encendido en primer dígito) 🔢

![imagine alt]("https://github.com/user-attachments/assets/854c3ebe-9c36-40da-9c79-3c837e6b2496")

Variables importantes (direcciones) 📎  
- INDEX (0x20) — índice de dígito activo (0..2)  
- NUM0 (0x21) — centésimas (mostrar en dígito 0)  
- NUM1 (0x22) — décimas (mostrar en dígito 1)  
- NUM2 (0x23) — volts enteros (0..5)  
- ADC8 (0x24) — ADRESH leída (0..255)  

Montaje rápido 🛠️  
1. Conectar segmentos RD0..RD7 a las líneas del display con resistencias serie (~330 Ω).  
2. Conectar comunes de cada dígito a transistores NPN controlados por RB7, RB6, RB5 (base con ~4.7 kΩ).  
3. Conectar AN0 a la fuente a medir mediante divisor/limitador (0..5 V). ⚠️  
4. Alimentar PIC a +5V y GND; añadir condensador 0.1 µF entre Vdd y Vss cerca del PIC.  
5. Programar el PIC con multimetro_1.0.asm (usar MPASM / MPLAB X y programador compatible). 💾

![Image](https://github.com/user-attachments/assets/20be2f11-74ca-4afc-b5c9-34b89127170f)

Compilación y programación 📦  
- Usar MPLAB X / MPASM para ensamblar.  
- Usar Visual Studio Code para un mejor manejo del proyecto

https://github.com/user-attachments/assets/22327214-83bf-4930-a8ff-de8b4e1789cc

- Archivo fuente: TP's\TP_FINAL\Multimetro\multimetro_1.0.asm




