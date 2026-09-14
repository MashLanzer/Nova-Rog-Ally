# -*- coding: utf-8 -*-
r"""Cien grabaciones de TU voz, para calibrar a Nova con datos y no a ojo.

    python tools\grabar-100.py

Nova tiene que estar APAGADA: usa el mismo microfono y el mismo boton.

Cada pantalla dice QUE decir y EN QUE TONO. Tomate el tiempo que quieras:
  ≡ (el boton de las tres rayas)  empieza a grabar
  ≡ otra vez                      para, guarda y pasa a la siguiente
  B                               vuelve a la anterior para repetirla
  Teclado: Enter = ≡, R = repetir la anterior, Esc = salir

Se puede dejar a medias: al volver empieza por la primera que falte. Los audios
van a pruebas\audio\cien\ y NO se suben a GitHub. Despues, para sacar las cuentas:

    python tools\analizar-100.py
"""
import ctypes
import json
import os
import subprocess
import sys
import time
import wave

try:
    import numpy as np
    import sounddevice as sd
    import tkinter as tk
except Exception as e:  # pragma: no cover
    print("Falta un paquete: %s" % e)
    print("Instala con:  pip install sounddevice numpy")
    sys.exit(1)

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESTINO = os.path.join(RAIZ, "pruebas", "audio", "cien")
TASA = 16000
MAX_S = 20.0          # tope por grabacion, por si se olvida parar
XINPUT_START = 0x0010  # ≡, el mismo que usa assistant.ps1
XINPUT_B = 0x2000

TONOS = {
    "normal": "Normal, como le hablas a Nova siempre",
    "bajo": "En voz baja, casi susurrando",
    "fuerte": "Fuerte, como si hubiera ruido alrededor",
    "grito": "Gritando, como si quisieras cortarla YA",
    "rapido": "Deprisa, sin pararte",
    "despacio": "Despacio, vocalizando",
    "lejos": "Desde lejos: la Ally a un metro o mas de ti",
    "pausas": "Con una pausa de un segundo donde estan los puntos (…)",
    "cansado": "Con voz cansada, de pocas ganas",
    "animado": "Animado, con ganas",
}

# (lo que se enseña, tono, tipo, lo que tiene que entender)
#   tipo: orden | compuesta | charla | corte | nova
#   lo que tiene que entender: para "nova", la orden SIN el nombre; para
#   "compuesta", la frase sin las pausas; en el resto, lo mismo que se enseña.
def F(decir, tono, tipo, texto=None):
    return {"decir": decir, "tono": tono, "tipo": tipo, "texto": texto or decir.replace("…", "").replace("  ", " ").strip()}


FRASES = [
    # --- 30 ordenes en tono normal ---
    F("abre steam", "normal", "orden"), F("abre spotify", "normal", "orden"), F("cierra discord", "normal", "orden"),
    F("pon el volumen al cincuenta", "normal", "orden"), F("sube el volumen", "normal", "orden"),
    F("baja el volumen", "normal", "orden"), F("sube el brillo", "normal", "orden"), F("baja el brillo", "normal", "orden"),
    F("pon el brillo al treinta", "normal", "orden"), F("qué hora es", "normal", "orden"),
    F("cuánta batería queda", "normal", "orden"), F("pausa", "normal", "orden"), F("siguiente canción", "normal", "orden"),
    F("anterior canción", "normal", "orden"), F("qué canción es", "normal", "orden"), F("abre youtube", "normal", "orden"),
    F("busca recetas de pasta en youtube", "normal", "orden"), F("abre little nightmares tres en steam", "normal", "orden"),
    F("a qué estoy jugando", "normal", "orden"), F("dónde me quedé", "normal", "orden"), F("pon modo noche", "normal", "orden"),
    F("pon modo foco", "normal", "orden"), F("silencia el navegador", "normal", "orden"),
    F("qué se está descargando", "normal", "orden"), F("cuánto espacio me queda", "normal", "orden"),
    F("minimiza todo", "normal", "orden"), F("haz una captura", "normal", "orden"), F("lee la pantalla", "normal", "orden"),
    F("recuérdame en diez minutos que mire el horno", "normal", "orden"), F("no me escuches media hora", "normal", "orden"),
    # --- 10 en voz baja ---
    F("abre discord", "bajo", "orden"), F("sube el volumen", "bajo", "orden"), F("pausa", "bajo", "orden"),
    F("qué hora es", "bajo", "orden"), F("cierra steam", "bajo", "orden"), F("pon el juego al cuarenta", "bajo", "orden"),
    F("siguiente canción", "bajo", "orden"), F("baja el brillo", "bajo", "orden"), F("cuánta batería queda", "bajo", "orden"),
    F("cancela el temporizador", "bajo", "orden"),
    # --- 10 fuerte ---
    F("abre steam", "fuerte", "orden"), F("baja el volumen", "fuerte", "orden"), F("pausa", "fuerte", "orden"),
    F("pon el volumen al ochenta", "fuerte", "orden"), F("cierra discord", "fuerte", "orden"), F("qué hora es", "fuerte", "orden"),
    F("silencia el navegador", "fuerte", "orden"), F("abre youtube", "fuerte", "orden"), F("sube el brillo", "fuerte", "orden"),
    F("siguiente canción", "fuerte", "orden"),
    # --- 6 deprisa y 4 despacio ---
    F("abre steam y pon modo juego", "rapido", "orden"), F("pon el volumen al setenta", "rapido", "orden"),
    F("recuérdame en veinte minutos que saque la pizza", "rapido", "orden"), F("abre spotify", "rapido", "orden"),
    F("sube el volumen", "rapido", "orden"), F("qué se está descargando", "rapido", "orden"),
    F("abre little nightmares tres en steam", "despacio", "orden"), F("apunta leche en la lista de la compra", "despacio", "orden"),
    F("avísame en cinco minutos", "despacio", "orden"), F("pon el brillo al cincuenta", "despacio", "orden"),
    # --- 6 desde lejos ---
    F("abre steam", "lejos", "orden"), F("qué hora es", "lejos", "orden"), F("pausa", "lejos", "orden"),
    F("sube el volumen", "lejos", "orden"), F("cierra discord", "lejos", "orden"), F("cuánta batería queda", "lejos", "orden"),
    # --- 6 con pausas en medio (miden cuanto hay que esperar antes de cerrar la frase) ---
    F("abre steam… y pon modo juego", "pausas", "compuesta"), F("abre discord… y pon música", "pausas", "compuesta"),
    F("pon el volumen al… sesenta", "pausas", "compuesta"),
    F("recuérdame en… quince minutos que llame a mi madre", "pausas", "compuesta"),
    F("busca… gatos en youtube", "pausas", "compuesta"), F("cierra spotify… y abre steam", "pausas", "compuesta"),
    # --- 12 de charla: NO deben acabar en ninguna orden ---
    F("estoy muy cansado hoy", "normal", "charla"), F("qué opinas de hollow knight", "normal", "charla"),
    F("me gusta mucho jugar por la noche", "normal", "charla"), F("hoy ha sido un día largo", "normal", "charla"),
    F("cuéntame un chiste", "normal", "charla"), F("quién hizo hollow knight", "normal", "charla"),
    F("tengo hambre pero no sé qué cenar", "normal", "charla"), F("qué tal estás", "normal", "charla"),
    F("no tengo ganas de nada", "cansado", "charla"), F("qué sueño tengo", "cansado", "charla"),
    F("por fin me he pasado el jefe", "animado", "charla"), F("qué ganas tengo de jugar esta noche", "animado", "charla"),
    # --- 10 palabras para cortarla mientras habla (calibran el TONO del corte) ---
    F("cállate", "normal", "corte"), F("cállate", "grito", "corte"), F("espera", "normal", "corte"),
    F("espera", "fuerte", "corte"), F("para", "normal", "corte"), F("para", "grito", "corte"),
    F("basta", "normal", "corte"), F("basta", "fuerte", "corte"), F("silencio", "normal", "corte"),
    F("silencio", "grito", "corte"),
    # --- 6 con el nombre delante, como de verdad ---
    F("nova, abre steam", "normal", "nova", "abre steam"), F("nova, qué hora es", "normal", "nova", "qué hora es"),
    F("nova, pausa", "normal", "nova", "pausa"), F("oye nova, sube el volumen", "normal", "nova", "sube el volumen"),
    F("nova, cuánta batería queda", "normal", "nova", "cuánta batería queda"),
    F("nova, pon modo noche", "normal", "nova", "pon modo noche"),
]
assert len(FRASES) == 100, len(FRASES)


class XinputGamepad(ctypes.Structure):
    _fields_ = [("wButtons", ctypes.c_ushort), ("bLeftTrigger", ctypes.c_ubyte), ("bRightTrigger", ctypes.c_ubyte),
                ("sThumbLX", ctypes.c_short), ("sThumbLY", ctypes.c_short), ("sThumbRX", ctypes.c_short), ("sThumbRY", ctypes.c_short)]


class XinputState(ctypes.Structure):
    _fields_ = [("dwPacketNumber", ctypes.c_uint), ("Gamepad", XinputGamepad)]


def cargar_xinput():
    for nombre in ("xinput1_4", "xinput1_3", "xinput9_1_0"):
        try:
            return ctypes.WinDLL(nombre)
        except OSError:
            continue
    return None


XINPUT = cargar_xinput()


def botones():
    if XINPUT is None:
        return 0
    b = 0
    for u in range(4):
        st = XinputState()
        if XINPUT.XInputGetState(u, ctypes.byref(st)) == 0:
            b |= st.Gamepad.wButtons
    return b


def nova_encendida():
    try:
        r = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'assistant.ps1' -and $_.CommandLine -notmatch 'Probar' }).Count"],
                           capture_output=True, text=True, timeout=30)
        return int((r.stdout or "0").strip() or 0) > 0
    except Exception:
        return False


def ruta_de(i):
    return os.path.join(DESTINO, "%03d.wav" % (i + 1))


def guardar_wav(ruta, audio):
    pcm = (np.clip(audio.reshape(-1), -1.0, 1.0) * 32767.0).astype("<i2")
    tmp = ruta + ".tmp"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TASA)
        w.writeframes(pcm.tobytes())
    os.replace(tmp, ruta)


class Grabadora:
    def __init__(self, raiz):
        self.raiz = raiz
        self.i = self.primera_que_falta()
        self.grabando = False
        self.trozos = []
        self.nivel = 0.0
        self.desde = 0.0
        self.aviso = ""
        self.antes = botones()
        self.ultima_pulsacion = 0.0
        self.flujo = sd.InputStream(samplerate=TASA, channels=1, dtype="float32", callback=self.al_oir)
        self.flujo.start()

        raiz.title("Nova: 100 grabaciones")
        raiz.configure(bg="#0b0f17")
        raiz.attributes("-fullscreen", True)
        raiz.bind("<Return>", lambda e: self.boton_principal())
        raiz.bind("<KP_Enter>", lambda e: self.boton_principal())
        raiz.bind("<Key-r>", lambda e: self.repetir_anterior())
        raiz.bind("<Key-R>", lambda e: self.repetir_anterior())
        raiz.bind("<Escape>", lambda e: self.salir())
        fondo = "#0b0f17"
        self.l_progreso = tk.Label(raiz, font=("Segoe UI", 20), fg="#8a93a6", bg=fondo)
        self.l_progreso.pack(pady=(30, 10))
        self.l_frase = tk.Label(raiz, font=("Segoe UI", 54, "bold"), fg="#ffffff", bg=fondo, wraplength=1500, justify="center")
        self.l_frase.pack(pady=(40, 20), expand=True)
        self.l_tono = tk.Label(raiz, font=("Segoe UI", 30), fg="#7cc4ff", bg=fondo, wraplength=1500, justify="center")
        self.l_tono.pack(pady=10)
        self.l_estado = tk.Label(raiz, font=("Segoe UI", 34, "bold"), fg="#ffd166", bg=fondo)
        self.l_estado.pack(pady=(30, 10))
        self.barra = tk.Canvas(raiz, width=900, height=26, bg="#1c2333", highlightthickness=0)
        self.barra.pack(pady=10)
        self.l_ayuda = tk.Label(raiz, font=("Segoe UI", 18), fg="#8a93a6", bg=fondo,
                                text="≡  empezar / terminar y pasar     ·     B  repetir la anterior     ·     Esc  salir (lo grabado se queda)")
        self.l_ayuda.pack(side="bottom", pady=30)
        self.pintar()
        self.raiz.after(30, self.vigilar)

    def primera_que_falta(self):
        for i in range(len(FRASES)):
            if not os.path.exists(ruta_de(i)):
                return i
        return len(FRASES)

    def al_oir(self, datos, frames, tiempo, estado):
        m = datos[:, 0].copy()
        self.nivel = float(np.sqrt(np.mean(m * m))) if m.size else 0.0
        if self.grabando:
            self.trozos.append(m)

    def boton_principal(self):
        ahora = time.time()
        if ahora - self.ultima_pulsacion < 0.35:     # un rebote del boton no es otra pulsacion
            return
        self.ultima_pulsacion = ahora
        if self.i >= len(FRASES):
            return
        if not self.grabando:
            self.trozos = []
            self.aviso = ""
            self.grabando = True
            self.desde = ahora
        else:
            self.terminar()
        self.pintar()

    def terminar(self):
        self.grabando = False
        audio = np.concatenate(self.trozos) if self.trozos else np.zeros(0, dtype=np.float32)
        dur = audio.size / float(TASA)
        pico = float(np.max(np.abs(audio))) if audio.size else 0.0
        if dur < 0.4:
            self.aviso = "Demasiado corta: vuelve a pulsar ≡ y dila"
            return
        if pico < 0.01:
            self.aviso = "Casi no se oye nada: repitela (≡)"
            return
        guardar_wav(ruta_de(self.i), audio)
        self.aviso = "Guardada la %d (%.1f s%s)" % (self.i + 1, dur, ", algo saturada" if pico > 0.98 else "")
        self.i = self.primera_que_falta() if self.i + 1 >= len(FRASES) else self.i + 1

    def repetir_anterior(self):
        if self.grabando:
            self.grabando = False
            self.trozos = []
        if self.i > 0:
            self.i -= 1
        self.aviso = "Repite esta y se sustituye la que habia"
        self.pintar()

    def salir(self):
        try:
            self.flujo.stop()
            self.flujo.close()
        except Exception:
            pass
        self.raiz.destroy()

    def vigilar(self):
        b = botones()
        nuevos = b & ~self.antes
        self.antes = b
        if nuevos & XINPUT_START:
            self.boton_principal()
        elif nuevos & XINPUT_B:
            self.repetir_anterior()
        if self.grabando and time.time() - self.desde > MAX_S:
            self.terminar()
        self.pintar()
        self.raiz.after(30, self.vigilar)

    def pintar(self):
        hechas = sum(1 for k in range(len(FRASES)) if os.path.exists(ruta_de(k)))
        if self.i >= len(FRASES):
            self.l_progreso.config(text="%d de %d grabadas" % (hechas, len(FRASES)))
            self.l_frase.config(text="¡Terminado!")
            self.l_tono.config(text="Ahora, con Nova apagada:  python tools\\analizar-100.py")
            self.l_estado.config(text=self.aviso, fg="#06d6a0")
        else:
            f = FRASES[self.i]
            self.l_progreso.config(text="Frase %d de %d   ·   %d grabadas   ·   %s" % (self.i + 1, len(FRASES), hechas, f["tipo"]))
            self.l_frase.config(text="«%s»" % f["decir"])
            self.l_tono.config(text=TONOS[f["tono"]])
            if self.grabando:
                self.l_estado.config(text="●  GRABANDO  %.1f s   —   ≡ para terminar" % (time.time() - self.desde), fg="#ef476f")
            else:
                self.l_estado.config(text=self.aviso or "Pulsa ≡ cuando estes listo", fg="#ffd166")
        ancho = int(min(1.0, self.nivel * 12) * 900)
        self.barra.delete("all")
        self.barra.create_rectangle(0, 0, ancho, 26, fill="#ef476f" if self.grabando else "#3a86ff", width=0)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    with open(os.path.join(DESTINO, "esperado.json"), "w", encoding="utf-8") as f:
        json.dump({"%03d.wav" % (i + 1): fr for i, fr in enumerate(FRASES)}, f, ensure_ascii=False, indent=1)
    if nova_encendida():
        print("Nova esta encendida: usa el mismo microfono y el mismo boton. Apagala y vuelve a lanzar esto.")
        return 1
    if XINPUT is None:
        print("No encuentro XInput: el mando no funcionara, pero puedes usar Enter (y R para repetir).")
    print("Micrófono: %s" % sd.query_devices(sd.default.device[0])["name"])
    raiz = tk.Tk()
    Grabadora(raiz)
    raiz.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
