import time

try:
    import serial
    HAS_SERIAL = True
except Exception:
    HAS_SERIAL = False
    print("pyserial no disponible: entrando en modo simulador (sin hardware).")

PORT = "COM3"      # ajustar
BAUD = 19200

def main():
    val = 0
    if HAS_SERIAL:
        try:
            ser = serial.Serial(PORT, BAUD)
        except Exception as e:
            print("No se pudo abrir puerto:", e)
            return
        try:
            while True:
                ser.write(bytes([val & 0xFF]))
                val = (val + 5) % 256
                time.sleep(0.01)
        except KeyboardInterrupt:
            ser.close()
    else:
        try:
            while True:
                # Simula envío mostrando en consola (o podrías escribir a archivo)
                print(f"Simulado byte: {val}")
                val = (val + 5) % 256
                time.sleep(0.01)
        except KeyboardInterrupt:
            print("Simulación terminada.")

if __name__ == "__main__":
    main()