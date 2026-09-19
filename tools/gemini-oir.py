# -*- coding: utf-8 -*-
"""SEGUNDA OPINION DEL OIDO, EN LA NUBE (16/09).

Recibe el WAV de la orden y devuelve lo que oye Gemini. Se usa como SEGUNDA opinion,
nunca como unico oido: medido con las 214 grabaciones leidas y las 130 de uso real,
gemini-3.5-flash-lite entiende 147 de 184 ordenes frente a las 144 del camino local,
y sobre todo acierta donde Parakeet falla (frases cortas y nombres de apps).

DOS COSAS QUE SE MIDIERON Y QUE MANDAN EN ESTE ARCHIVO:

1. NADA DE LISTA DE NOMBRES EN EL PROMPT. Con "Steam, Discord, Spotify, It Takes Two"
   dentro, el modelo la RECITA cuando el audio no es claro: devolvio "Steam, Discord,
   Spotify, It Takes Two" para un "cierra Steam", y "It Takes Two" por "Xbox". Es el
   mismo problema que la frase de ejemplo de Whisper. Sin lista, no inventa nombres.

2. TIENE COLAS LARGAS. La mediana es 1,2 s, pero 5 de cada 20 peticiones pasan de 3 s
   (hasta 26 s, y alguna sin respuesta). Por eso el asistente le pone un tope y sigue
   sin el; aqui se pone tambien el nuestro, mas corto que el suyo.

Uso:  python tools\\gemini-oir.py <audio.wav> <salida.txt> [tope_ms]

La clave se lee de GEMINI_API_KEY (del proceso o del entorno del usuario); NO se pasa
por argumentos, que se ven en la lista de procesos.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

MODELO = "gemini-3.5-flash-lite"
PROMPT = ("Transcribe literalmente esta orden de voz. Habla español latino y puede nombrar "
          "aplicaciones y juegos. Devuelve SOLO la transcripción, sin comillas ni comentarios. "
          "Si no hay voz clara, devuelve vacío.")
# la orden mas larga del uso real son 6 s; lo que pase de esto no es una orden
MAX_BYTES = 2_000_000


def clave():
    k = os.environ.get("GEMINI_API_KEY", "")
    if not k:
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = winreg.QueryValueEx(h, "GEMINI_API_KEY")[0]
        except Exception:
            k = ""
    return (k or "").strip()


def escribir(ruta, texto):
    # UTF-8 sin BOM y a mano: con Start-Process redirigido, PowerShell 5.1 vuelve a
    # codificar lo que sale y rompe las tildes (lo mismo que paso con claude-api.ps1)
    with open(ruta, "wb") as f:
        f.write((texto or "").encode("utf-8"))


def oir(wav, tope_s):
    k = clave()
    if not k:
        return "", "sin clave"
    datos = open(wav, "rb").read()
    if not datos or len(datos) > MAX_BYTES:
        return "", "audio vacio o demasiado largo (%d bytes)" % len(datos)
    cuerpo = {
        "contents": [{"role": "user", "parts": [
            {"inline_data": {"mime_type": "audio/wav", "data": base64.b64encode(datos).decode()}},
            {"text": PROMPT}]}],
        "generationConfig": {"temperature": 0, "thinkingConfig": {"thinkingLevel": "minimal"},
                             "maxOutputTokens": 64},
    }
    req = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % MODELO,
        data=json.dumps(cuerpo).encode(), method="POST",
        headers={"x-goog-api-key": k, "Content-Type": "application/json"})
    r = json.load(urllib.request.urlopen(req, timeout=tope_s))
    partes = r.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    texto = "".join(p.get("text", "") for p in partes if not p.get("thought")).strip()
    return texto, ""


def main():
    if len(sys.argv) < 3:
        print("uso: gemini-oir.py <audio.wav> <salida.txt> [tope_ms]")
        return 1
    wav, salida = sys.argv[1], sys.argv[2]
    tope_s = (int(sys.argv[3]) if len(sys.argv) > 3 else 2500) / 1000.0
    t0 = time.time()
    # DOS INTENTOS DENTRO DEL MISMO PLAZO (19/09). Medido con 376 respuestas reales:
    # la mediana es 2,69 s pero la cola es larguisima (p90 10,6 s, maximo 21 s). Y esa
    # cola NO es audio dificil, es la red: los tres unicos clips del uso real que se
    # pasaban del tope -5,0 / 18,2 / 14,6 s- contestaron en 1,5-2,2 s al repetirlos.
    # Asi que en vez de esperar mucho una vez, se pide dos veces con la mitad del plazo
    # cada una. Con el tope en 7 s eso sube la probabilidad de tener respuesta del 87 %
    # (un intento de 7 s) al 92 % (dos de 3,5 s). Por debajo de 6 s de tope NO compensa
    # partir: un solo intento largo gana. Si se vuelve a tocar el tope, rehacer la cuenta.
    intentos = 2 if tope_s >= 6.0 else 1
    cada = tope_s / intentos - 0.1   # margen para no pasarse del plazo del asistente
    texto, fallo = "", ""
    for i in range(intentos):
        try:
            texto, fallo = oir(wav, cada)
        except urllib.error.HTTPError as e:
            texto, fallo = "", "HTTP %d" % e.code
            if 400 <= e.code < 500 and e.code != 429:
                break   # clave mala o peticion mal formada: reintentar no arregla nada
        except Exception as e:  # noqa: BLE001
            texto, fallo = "", repr(e)[:120]
        if texto:
            break
        if i + 1 < intentos:
            sys.stderr.write("gemini-oir: intento %d sin respuesta en %.1f s; lo pido otra vez" % (i + 1, cada) + chr(10))
    # SIEMPRE se escribe el archivo, aunque sea vacio: el asistente lo espera y, si no
    # llega, se queda esperando al plazo entero para nada
    escribir(salida, texto)
    sys.stderr.write("gemini-oir: %.2f s -> %r %s\n" % (time.time() - t0, texto, fallo))
    return 0


if __name__ == "__main__":
    sys.exit(main())
