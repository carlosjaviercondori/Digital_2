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
SERIAL_PORT = "COM3"
BAUDRATE = 19200
SER_TIMEOUT = 0.01

# Configuración gráfica
WIDTH, HEIGHT = 1000, 600
FPS = 60

PLOT_MARGIN_X = 40
PLOT_TOP_MARGIN = 40
BOTTOM_RESERVED = 220  # espacio bajo la grafica para controles
BTN_W, BTN_H = 70, 36
BTN_GAP = 12
BTN_START_X = 40
STOP_BTN_WIDTH = 90
STOP_BTN_EXTRA_GAP = 40
WINDOW_MIN_WIDTH = 600
WINDOW_MIN_HEIGHT = 420

# Timebase multipliers mostrados por botones
TIMEBASE_OPTIONS = [1, 2, 5, 10]   # multiplicadores de velocidad
TIMEBASE_LABELS = ["1x", "2x", "5x", "10x"]
timebase_idx = 0

# Simulación si no hay serial
SIM_FREQ = 5.0
SIM_AMP = 1.0
_sim_t = 0.0

# referencia de tensión del ADC (ajustar según hardware: 5.0, 3.3, etc.)
VREF = 5.0

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

def compute_layout(width, height):
    usable_width = max(200, width - 2 * PLOT_MARGIN_X)
    usable_height = max(200, height - (PLOT_TOP_MARGIN + BOTTOM_RESERVED))
    plot_rect = pygame.Rect(PLOT_MARGIN_X, PLOT_TOP_MARGIN, usable_width, usable_height)

    y_btn = plot_rect.bottom + 20
    btns = []
    for i, lbl in enumerate(TIMEBASE_LABELS):
        x = BTN_START_X + i * (BTN_W + BTN_GAP)
        rect = pygame.Rect(x, y_btn, BTN_W, BTN_H)
        btns.append((rect, lbl))

    stop_x = BTN_START_X + len(TIMEBASE_LABELS) * (BTN_W + BTN_GAP) + STOP_BTN_EXTRA_GAP
    stop_rect = pygame.Rect(stop_x, y_btn, STOP_BTN_WIDTH, BTN_H)

    return {
        "plot_rect": plot_rect,
        "btns": btns,
        "stop_rect": stop_rect,
        "start_x": BTN_START_X,
        "btn_h": BTN_H,
        "y_btn": y_btn,
        "info_x": BTN_START_X,
        "info_y": y_btn + BTN_H + 8
    }

def adjust_buffer(buffer, new_len, fill_value=128):
    new_len = max(10, int(new_len))
    new_buffer = deque(buffer, maxlen=new_len)
    if len(new_buffer) < new_len:
        pad_val = new_buffer[-1] if new_buffer else fill_value
        new_buffer.extend([pad_val] * (new_len - len(new_buffer)))
    return new_buffer

def main():
    global _sim_t, timebase_idx
    pygame.init()
    screen_w, screen_h = WIDTH, HEIGHT
    screen = pygame.display.set_mode((screen_w, screen_h), pygame.RESIZABLE)
    pygame.display.set_caption("Osciloscopio - Lectura ADRESH por Serial")
    clock = pygame.time.Clock()

    layout = compute_layout(screen_w, screen_h)
    initial_width = layout["plot_rect"].width
    buffer = deque([128]*initial_width, maxlen=initial_width)
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

    # --- botón STOP/REANUDAR (no borra la señal, solo congela la adquisición) ---
    stopped = False

    last_time = time.time()
    sample_acc = 0.0
    base_sample_rate = 1000.0  # muestras por segundo de referencia para simulación/visualización

    while running:
        dt = clock.tick(FPS) / 1000.0
        layout_dirty = False
        btns_for_events = layout["btns"]
        stop_rect_for_events = layout["stop_rect"]
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                running = False
            elif ev.type == pygame.VIDEORESIZE:
                screen_w = max(WINDOW_MIN_WIDTH, ev.w)
                screen_h = max(WINDOW_MIN_HEIGHT, ev.h)
                screen = pygame.display.set_mode((screen_w, screen_h), pygame.RESIZABLE)
                layout_dirty = True
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_SPACE:
                    paused = not paused
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                mx,my = ev.pos
                # timebase buttons
                for i,(r,lbl) in enumerate(btns_for_events):
                    if r.collidepoint(mx,my):
                        timebase_idx = i
                # stop button toggle: sólo cambia el estado de stopped
                if stop_rect_for_events.collidepoint(mx,my):
                    stopped = not stopped
                    # no borrar buffer; detener la adquisición en el momento exacto
                    # paused se mantiene independiente (tecla SPACE)
                    # cuando stopped==True la adquisición se congela; al volver a False se reanuda

        if layout_dirty:
            layout = compute_layout(screen_w, screen_h)
            buffer = adjust_buffer(buffer, layout["plot_rect"].width, current_adresh)

        plot_rect = layout["plot_rect"]
        btns = layout["btns"]
        stop_rect = layout["stop_rect"]
        info_x = layout["info_x"]
        info_y = layout["info_y"]

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
        draw_scope_grid(screen, plot_rect, cols=10, rows=8, minor_steps=5)
        draw_trace(screen, plot_rect, list(buffer), color=(0,200,0))

        # indicadores y texto
        font = pygame.font.SysFont('Consolas', 18)

        # --- CÁLCULO DE Vmax, Vmin, Vpp y FRECUENCIA ESTIMADA ---
        vals = list(buffer)
        if vals:
            # convertir ADC(0..255) a voltaje
            v_vals = [ (b / 255.0) * VREF for b in vals ]
            v_max = max(v_vals)
            v_min = min(v_vals)
            v_pp = v_max - v_min
            v_avg = sum(v_vals) / len(v_vals)

            # estimación de frecuencia por cruces ascendentes del nivel medio
            mid = (v_max + v_min) / 2.0
            crossings = []
            for i in range(1, len(v_vals)):
                if v_vals[i-1] < mid and v_vals[i] >= mid:
                    crossings.append(i)
            if len(crossings) >= 2 and sample_rate > 0:
                diffs = [crossings[i] - crossings[i-1] for i in range(1, len(crossings))]
                avg_period_samples = sum(diffs) / len(diffs)
                freq_est = sample_rate / avg_period_samples
            else:
                freq_est = 0.0
        else:
            v_max = v_min = v_pp = v_avg = 0.0
            freq_est = 0.0
        # --- FIN CÁLCULOS ---

        # Mover ADRESH y NUMs debajo de los botones para que sean visibles
        # Recuadro izquierdo para ADRESH y NUMs
        left_box_w = 360
        left_box_h = 32
        left_box = pygame.Rect(info_x, info_y, left_box_w, left_box_h)
        pygame.draw.rect(screen, (28,28,36), left_box, border_radius=6)               # fondo
        pygame.draw.rect(screen, (70,70,90), left_box, 2, border_radius=6)           # borde

        txt_color = (200,255,200)
        small_color = (200,200,255)
        pad = 8
        # ADRESH a la izquierda
        screen.blit(font.render(f"ADRESH: {current_adresh:03d}", True, txt_color), (left_box.left + pad, left_box.top + 4))

        # Tres recuadros pequeños a la derecha para NUM2, NUM1 y NUM0 (asegura que NUM0 esté en recuadro)
        digit_w = 48
        digit_h = left_box_h - 8
        digit_gap = 6
        # calcular posición X para alinear los tres dígitos al borde derecho del left_box
        digits_x = left_box.right - (digit_w*3 + digit_gap*2) - pad
        digits_y = left_box.top + 4

        for i, val in enumerate((num2, num1, num0)):
            r = pygame.Rect(digits_x + i*(digit_w + digit_gap), digits_y, digit_w, digit_h)
            pygame.draw.rect(screen, (20,20,30), r, border_radius=4)
            pygame.draw.rect(screen, (70,70,90), r, 2, border_radius=4)
            txt = font.render(str(val), True, small_color)
            tx = r.left + (r.width - txt.get_width())//2
            ty = r.top + (r.height - txt.get_height())//2
            screen.blit(txt, (tx, ty))

        tb_label = f"Timebase: {TIMEBASE_LABELS[timebase_idx]}  (mul x{TIMEBASE_OPTIONS[timebase_idx]})"
        screen.blit(font.render(tb_label, True, (220,220,180)), (plot_rect.left, plot_rect.bottom + 6))

        # Recuadros para Vmax, Vpp y Frecuencia (apilados, derecha)
        info2_x = plot_rect.right - 300
        info2_y = plot_rect.bottom + 8
        metric_w = 160
        metric_h = 28
        spacing = 6

        metrics = [
            (f"Vmax: {v_max:.3f} V", txt_color),
            (f"Vmin: {v_min:.3f} V", txt_color),
            (f"Vmed: {v_avg:.3f} V", txt_color),
            (f"Vpp:  {v_pp:.3f} V", txt_color),
            (f"Frec: {freq_est:.2f} Hz", txt_color)
        ]

        for i, (label, color) in enumerate(metrics):
            r = pygame.Rect(info2_x, info2_y + i*(metric_h + spacing), metric_w, metric_h)
            pygame.draw.rect(screen, (28,28,36), r, border_radius=6)
            pygame.draw.rect(screen, (70,70,90), r, 2, border_radius=6)
            screen.blit(font.render(label, True, color), (r.left + 8, r.top + 4))

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
        screen.blit(small.render("Click botones para cambiar velocidad. Espacio pausa. Ajustar SERIAL_PORT si se usa hardware.", True, (180,180,180)), (40, screen_h-30))

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
