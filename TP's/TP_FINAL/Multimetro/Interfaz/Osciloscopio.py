import pygame
import sys
import math
import time
from collections import deque

# intentar importar pyserial; si no está, cae a modo simulador
try:
    import serial
    HAS_SERIAL = True
except Exception:
    serial = None
    HAS_SERIAL = False

# Configuración serial (ajustar puerto)
SERIAL_PORT = "COM4"
BAUDRATE = 19200
SER_TIMEOUT = 0.01

# Configuración gráfica
WIDTH, HEIGHT = 1000, 600
PLOT_RECT = pygame.Rect(40, 40, 920, 320)
FPS = 60
BUFFER_LEN = PLOT_RECT.width

# Timebase multipliers mostrados por botones
TIMEBASE_OPTIONS = [1, 2, 5, 10]   # multiplicadores de velocidad
TIMEBASE_LABELS = ["1x", "2x", "5x", "10x"]
timebase_idx = 0

# Simulación si no hay serial
SIM_FREQ = 5.0
SIM_AMP = 1.0
_sim_t = 0.0

def bin8_to_dec3(val):
    tmp = int(val) & 0xFF
    num2 = 0
    num1 = 0
    num0 = 0
    while tmp >= 100:
        tmp -= 100
        num2 += 1
    while tmp >= 10:
        tmp -= 10
        num1 += 1
    num0 = tmp
    return num2, num1, num0

def open_serial(port, baud):
    try:
        ser = serial.Serial(port, baud, timeout=SER_TIMEOUT)
        return ser
    except Exception as e:
        print("No se pudo abrir puerto serial:", e)
        return None

def draw_scope_grid(surface, rect, cols=10, rows=8, minor_steps=5, color_major=(60,60,60), color_minor=(40,40,40)):
    # fondo
    pygame.draw.rect(surface, (10,10,20), rect)
    # líneas menores
    for c in range(cols * minor_steps + 1):
        x = rect.left + c * (rect.width / (cols * minor_steps))
        color = color_minor
        pygame.draw.line(surface, color, (x, rect.top), (x, rect.bottom), 1)
    for r in range(rows * minor_steps + 1):
        y = rect.top + r * (rect.height / (rows * minor_steps))
        color = color_minor
        pygame.draw.line(surface, color, (rect.left, y), (rect.right, y), 1)
    # líneas mayores
    for c in range(cols + 1):
        x = rect.left + c * (rect.width / cols)
        pygame.draw.line(surface, color_major, (x, rect.top), (x, rect.bottom), 2)
    for r in range(rows + 1):
        y = rect.top + r * (rect.height / rows)
        pygame.draw.line(surface, color_major, (rect.left, y), (rect.right, y), 2)
    # ejes centrales
    pygame.draw.line(surface, (80,80,140), (rect.left, rect.centery), (rect.right, rect.centery), 2)
    pygame.draw.line(surface, (80,80,140), (rect.centerx, rect.top), (rect.centerx, rect.bottom), 2)

def draw_trace(surface, rect, buffer, color=(0,255,0)):
    if len(buffer) < 2:
        return
    pts = []
    for i, v in enumerate(buffer):
        x = rect.left + i
        y = rect.bottom - int((v / 255.0) * rect.height)
        pts.append((x, y))
    if len(pts) > 1:
        pygame.draw.lines(surface, color, False, pts, 2)

def draw_button(surface, rect, label, active=False):
    color_bg = (200,200,60) if active else (60,60,60)
    color_text = (10,10,10) if active else (220,220,220)
    pygame.draw.rect(surface, color_bg, rect, border_radius=6)
    pygame.draw.rect(surface, (0,0,0), rect, 2, border_radius=6)
    font = pygame.font.SysFont('Consolas', 18)
    text = font.render(label, True, color_text)
    tx = rect.left + (rect.width - text.get_width())//2
    ty = rect.top + (rect.height - text.get_height())//2
    surface.blit(text, (tx, ty))

def generate_sim_sample(t, freq=SIM_FREQ, amp=SIM_AMP):
    return amp * math.sin(2 * math.pi * freq * t)

def main():
    global _sim_t, timebase_idx
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Osciloscopio - Lectura ADRESH por Serial")
    clock = pygame.time.Clock()

    buffer = deque([128]*BUFFER_LEN, maxlen=BUFFER_LEN)
    running = True
    paused = False

    ser = None
    if HAS_SERIAL:
        ser = open_serial(SERIAL_PORT, BAUDRATE)
        if ser:
            print("Puerto serial abierto:", SERIAL_PORT, BAUDRATE)
        else:
            print("No serial: modo simulador")
    else:
        print("pyserial no disponible: modo simulador")

    current_adresh = 128
    num2, num1, num0 = bin8_to_dec3(current_adresh)

    # botones de timebase
    btns = []
    btn_w, btn_h = 70, 36
    gap = 12
    start_x = 40
    y_btn = PLOT_RECT.bottom + 20
    for i, lbl in enumerate(TIMEBASE_LABELS):
        r = pygame.Rect(start_x + i*(btn_w+gap), y_btn, btn_w, btn_h)
        btns.append((r, lbl))

    # --- botón STOP/REANUDAR (no borra la señal, solo congela la adquisición) ---
    stopped = False
    stop_w = 90
    stop_rect = pygame.Rect(start_x + len(TIMEBASE_LABELS)*(btn_w+gap) + 40, y_btn, stop_w, btn_h)

    last_time = time.time()
    sample_acc = 0.0
    base_sample_rate = 1000.0  # muestras por segundo de referencia para simulación/visualización

    while running:
        dt = clock.tick(FPS) / 1000.0
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                running = False
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_SPACE:
                    paused = not paused
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx,my = ev.pos
                # timebase buttons
                for i,(r,lbl) in enumerate(btns):
                    if r.collidepoint(mx,my):
                        timebase_idx = i
                # stop button toggle: sólo cambia el estado de stopped
                if stop_rect.collidepoint(mx,my):
                    stopped = not stopped
                    # no borrar buffer; detener la adquisición en el momento exacto
                    # paused se mantiene independiente (tecla SPACE)
                    # cuando stopped==True la adquisición se congela; al volver a False se reanuda

        # calcular sample rate actual (ajustado por timebase)
        multiplier = TIMEBASE_OPTIONS[timebase_idx]
        sample_rate = base_sample_rate * multiplier

        # Solo adquirir nuevos datos si no está paused y no está stopped
        if not paused and not stopped:
            # si hay serial: leer todos los bytes disponibles y agregarlos
            if ser:
                try:
                    n = ser.in_waiting if hasattr(ser, 'in_waiting') else 0
                    if n:
                        data = ser.read(n)
                        for b in data:
                            buffer.append(b)
                            current_adresh = b
                            num2, num1, num0 = bin8_to_dec3(current_adresh)
                    else:
                        # si no llegan bytes, mantener última muestra; para evitar quedarse sin movimiento
                        # añadir una copia ocasional según sample_rate para desplazar horizonte
                        sample_acc += dt * sample_rate
                        while sample_acc >= 1.0:
                            buffer.append(current_adresh)
                            sample_acc -= 1.0
                except Exception as e:
                    # si falla el serial, pasar a modo simulador
                    ser = None
                    print("Error serial, entrando en modo simulador:", e)
            else:
                # simulación: generar muestras según sample_rate
                sample_acc += dt * sample_rate
                while sample_acc >= 1.0:
                    s = generate_sim_sample(_sim_t, freq=SIM_FREQ*multiplier, amp=1.0)
                    _sim_t += 1.0 / sample_rate
                    ad = int(round((s + 1.0) / 2.0 * 255)) & 0xFF
                    buffer.append(ad)
                    current_adresh = ad
                    num2, num1, num0 = bin8_to_dec3(current_adresh)
                    sample_acc -= 1.0

        # DIBUJO
        screen.fill((15,15,25))
        draw_scope_grid(screen, PLOT_RECT, cols=10, rows=8, minor_steps=5)
        draw_trace(screen, PLOT_RECT, list(buffer), color=(0,200,0))

        # indicadores y texto
        font = pygame.font.SysFont('Consolas', 18)

        # Mover ADRESH y NUMs debajo de los botones para que sean visibles
        info_x = start_x
        info_y = y_btn + btn_h + 8

        screen.blit(font.render(f"ADRESH: {current_adresh:03d}", True, (200,255,200)), (info_x, info_y))
        # Mostrar en el orden correcto: NUM0=unidades, NUM1=decenas, NUM2=centenas
        screen.blit(font.render(f"NUM2: {num2}, NUM1: {num1}, NUM0: {num0}", True, (200,200,255)), (info_x + 200, info_y))

        tb_label = f"Timebase: {TIMEBASE_LABELS[timebase_idx]}  (mul x{TIMEBASE_OPTIONS[timebase_idx]})"
        screen.blit(font.render(tb_label, True, (220,220,180)), (PLOT_RECT.left, PLOT_RECT.bottom + 6))

        # dibujar botones de timebase
        for i,(r,lbl) in enumerate(btns):
            draw_button(screen, r, lbl, active=(i==timebase_idx))

        # dibujar botón STOP/REANUDAR (label indica acción disponible)
        stop_label = "RUN" if not stopped else "STOP"
        # si stopped==True -> botón muestra "STOP" (significa está detenido y al pulsar volverá a RUN)
        # para que sea más intuitivo mostramos la acción siguiente (RUN) cuando detenido
        draw_button(screen, stop_rect, stop_label, active=stopped)
        # indicador de estado
        state_text = "STOPPED" if stopped else ("PAUSED" if paused else "RUNNING")
        small_font = pygame.font.SysFont('Consolas', 14)
        screen.blit(small_font.render(state_text, True, (240,180,180) if stopped else (180,180,180)), (stop_rect.left, stop_rect.top - 22))

        # leyenda de ayuda
        small = pygame.font.SysFont('Consolas', 14)
        screen.blit(small.render("Click botones para cambiar velocidad. Espacio pausa. Ajustar SERIAL_PORT si se usa hardware.", True, (180,180,180)), (40, HEIGHT-30))

        pygame.display.flip()

    if ser:
        ser.close()
    pygame.quit()
    sys.exit()

if __name__ == '__main__':
    main()
#-----------------------------------------------------------------------------------------------    
# para ejecutar el script usar:
# python "C:\Users\cjcar\Documents\Digital_2\TP's\TP_FINAL\Multimetro\Interfaz\Osciloscopio.py"
#-----------------------------------------------------------------------------------------------