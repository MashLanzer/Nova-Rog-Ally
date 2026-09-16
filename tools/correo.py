# -*- coding: utf-8 -*-
"""EL CORREO DE BRAYA, POR VOZ (16/09). Leer y enviar.

El 15/09 "revisa mi correo" se pidio tres veces y las tres acabaron en el agente
(37-93 s) sin conseguir nada util. Esto lo hace en 1-3 segundos.

POR QUE IMAP/SMTP Y NO LA API DE GMAIL: con una contrasena de aplicacion se monta en
cinco minutos, sin proyectos en Google Cloud ni pantallas de consentimiento, y se puede
revocar desde la cuenta con un clic. La clave NO se guarda aqui: vive en la variable de
entorno NOVA_CORREO_CLAVE del usuario de Windows.

LO QUE MANDA EN ESTE ARCHIVO:
- LEER no cambia nada, asi que no pregunta. Se devuelven remitente, asunto y fecha; el
  cuerpo SOLO si se pide expresamente (leer <id>), y recortado.
- ENVIAR sale de la maquina y no se puede deshacer, asi que este script NO envia nunca
  sin --confirmado. Quien pregunta es Nova, en voz alta, antes de llamar aqui.
- Nada se escribe en el log salvo cuantos correos habia: ni asuntos, ni direcciones,
  ni cuerpos. Lo que se dice en voz alta ya lo oyes tu.

Uso:
    python tools\\correo.py no-leidos [n] <salida.json>
    python tools\\correo.py ultimos   [n] <salida.json>
    python tools\\correo.py leer <n>      <salida.json>
    python tools\\correo.py enviar <destino> <asunto> <cuerpo> <salida.json> --confirmado
    python tools\\correo.py responder <n> <cuerpo> <salida.json> --confirmado
"""
import email
import email.header
import email.utils
import imaplib
import json
import os
import re
import smtplib
import sys
from email.message import EmailMessage

IMAP = os.environ.get("NOVA_CORREO_IMAP", "imap.gmail.com")
SMTP = os.environ.get("NOVA_CORREO_SMTP", "smtp.gmail.com")
TOPE_CUERPO = 1500          # lo que se lee en voz alta, no un correo entero
TOPE_ASUNTO = 120


def credenciales():
    usuario = os.environ.get("NOVA_CORREO_USUARIO", "")
    clave = os.environ.get("NOVA_CORREO_CLAVE", "")
    if not usuario or not clave:
        try:
            import winreg
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                if not usuario:
                    usuario = winreg.QueryValueEx(h, "NOVA_CORREO_USUARIO")[0]
                if not clave:
                    clave = winreg.QueryValueEx(h, "NOVA_CORREO_CLAVE")[0]
        except Exception:
            pass
    return (usuario or "").strip(), (clave or "").strip()


def escribir(ruta, datos):
    # UTF-8 a mano: con Start-Process redirigido, PowerShell 5.1 vuelve a codificar lo
    # que sale y rompe las tildes (lo mismo que paso con claude-api.ps1)
    with open(ruta, "wb") as f:
        f.write(json.dumps(datos, ensure_ascii=False).encode("utf-8"))


def limpiar(texto, tope):
    t = re.sub(r"\s+", " ", (texto or "")).strip()
    return t[:tope]


def descifrar(cabecera):
    """Las cabeceras vienen codificadas (=?UTF-8?B?...?=) y hay que decodificarlas."""
    if not cabecera:
        return ""
    partes = []
    for trozo, codec in email.header.decode_header(cabecera):
        if isinstance(trozo, bytes):
            partes.append(trozo.decode(codec or "utf-8", "replace"))
        else:
            # SIN CODIFICAR: email lo da como str pero con los bytes crudos metidos uno
            # a uno (latin-1). Asi salia "estÃ¡" por "está". Se rehace y se prueba utf-8.
            try:
                partes.append(trozo.encode("latin-1").decode("utf-8"))
            except (UnicodeEncodeError, UnicodeDecodeError):
                partes.append(trozo)
    return "".join(partes)


def quien(cabecera):
    """'Banco X <no-reply@banco.com>' -> 'Banco X'. Es lo que se dice en voz alta."""
    nombre, direccion = email.utils.parseaddr(descifrar(cabecera))
    nombre = limpiar(nombre, 60)
    if nombre:
        return nombre
    # sin nombre, el dominio dice mas que la direccion entera
    if "@" in direccion:
        return direccion.split("@")[1]
    return limpiar(direccion, 60)


def cuerpo_de(msg):
    """El texto plano del correo; si solo hay HTML, se le quitan las etiquetas."""
    texto = ""
    if msg.is_multipart():
        for parte in msg.walk():
            if parte.get_content_type() == "text/plain" and "attachment" not in str(parte.get("Content-Disposition", "")):
                try:
                    texto = parte.get_payload(decode=True).decode(parte.get_content_charset() or "utf-8", "replace")
                    break
                except Exception:
                    continue
        if not texto:
            for parte in msg.walk():
                if parte.get_content_type() == "text/html":
                    try:
                        crudo = parte.get_payload(decode=True).decode(parte.get_content_charset() or "utf-8", "replace")
                        texto = re.sub(r"<[^>]+>", " ", crudo)
                        break
                    except Exception:
                        continue
    else:
        try:
            texto = msg.get_payload(decode=True).decode(msg.get_content_charset() or "utf-8", "replace")
        except Exception:
            texto = ""
    # las citas del correo anterior no se leen en voz alta
    texto = re.sub(r"(?m)^\s*>.*$", " ", texto)
    return limpiar(texto, TOPE_CUERPO)


def conectar(usuario, clave):
    c = imaplib.IMAP4_SSL(IMAP, timeout=20)
    c.login(usuario, clave)
    c.select("INBOX")
    return c


def listar(c, solo_no_leidos, cuantos, con_cuerpo=False):
    criterio = "(UNSEEN)" if solo_no_leidos else "ALL"
    ok, datos = c.search(None, criterio)
    if ok != "OK":
        return []
    ids = datos[0].split()
    ids = ids[-cuantos:] if cuantos else ids
    salida = []
    for n in reversed(ids):
        # BODY.PEEK: mirar un correo NO lo marca como leido. Que Nova te lo cuente no
        # puede hacer que desaparezca de "no leidos" en tu movil.
        ok, cruda = c.fetch(n, "(BODY.PEEK[])")
        if ok != "OK" or not cruda or not cruda[0]:
            continue
        msg = email.message_from_bytes(cruda[0][1])
        fecha = ""
        try:
            d = email.utils.parsedate_to_datetime(msg.get("Date"))
            fecha = d.strftime("%d/%m %H:%M")
        except Exception:
            pass
        item = {"n": int(n), "de": quien(msg.get("From")), "asunto": limpiar(descifrar(msg.get("Subject")), TOPE_ASUNTO), "fecha": fecha}
        if con_cuerpo:
            item["cuerpo"] = cuerpo_de(msg)
            item["responder_a"] = email.utils.parseaddr(descifrar(msg.get("Reply-To") or msg.get("From")))[1]
            item["asunto_crudo"] = descifrar(msg.get("Subject"))
            item["message_id"] = msg.get("Message-ID", "")
        salida.append(item)
    return salida


def enviar(usuario, clave, destino, asunto, cuerpo, responde_a=None):
    msg = EmailMessage()
    msg["From"] = usuario
    msg["To"] = destino
    msg["Subject"] = asunto
    if responde_a:
        msg["In-Reply-To"] = responde_a
        msg["References"] = responde_a
    msg.set_content(cuerpo)
    with smtplib.SMTP_SSL(SMTP, 465, timeout=25) as s:
        s.login(usuario, clave)
        s.send_message(msg)


def main():
    if len(sys.argv) < 3:
        print("faltan argumentos")
        return 1
    orden = sys.argv[1]
    salida = sys.argv[-1] if sys.argv[-1].lower().endswith(".json") else ""
    if not salida:
        # el ultimo argumento puede ser --confirmado
        for a in reversed(sys.argv):
            if a.lower().endswith(".json"):
                salida = a
                break
    usuario, clave = credenciales()
    if not usuario or not clave:
        if salida:
            escribir(salida, {"ok": False, "error": "sin credenciales"})
        print("faltan NOVA_CORREO_USUARIO / NOVA_CORREO_CLAVE")
        return 2
    try:
        if orden in ("no-leidos", "ultimos", "leer"):
            cuantos = 5
            if len(sys.argv) > 2 and sys.argv[2].isdigit():
                cuantos = max(1, min(20, int(sys.argv[2])))
            c = conectar(usuario, clave)
            try:
                if orden == "leer":
                    lista = listar(c, False, cuantos, con_cuerpo=True)
                    lista = lista[:1] if cuantos == 1 else lista
                else:
                    lista = listar(c, orden == "no-leidos", cuantos)
            finally:
                try:
                    c.logout()
                except Exception:
                    pass
            escribir(salida, {"ok": True, "cuantos": len(lista), "correos": lista})
            sys.stderr.write("correo: %d mensajes\n" % len(lista))
            return 0

        if orden in ("enviar", "responder"):
            # NUNCA sin confirmar: enviar sale de la maquina y no se deshace
            if "--confirmado" not in sys.argv:
                escribir(salida, {"ok": False, "error": "falta la confirmacion"})
                return 3
            if orden == "enviar":
                destino, asunto, cuerpo = sys.argv[2], sys.argv[3], sys.argv[4]
                enviar(usuario, clave, destino, asunto, cuerpo)
                escribir(salida, {"ok": True, "enviado_a": destino})
            else:
                n = int(sys.argv[2])
                cuerpo = sys.argv[3]
                c = conectar(usuario, clave)
                try:
                    lista = [x for x in listar(c, False, 20, con_cuerpo=True) if x["n"] == n]
                finally:
                    try:
                        c.logout()
                    except Exception:
                        pass
                if not lista:
                    escribir(salida, {"ok": False, "error": "no encuentro ese correo"})
                    return 4
                orig = lista[0]
                asunto = orig["asunto_crudo"] or ""
                if not asunto.lower().startswith("re:"):
                    asunto = "Re: " + asunto
                enviar(usuario, clave, orig["responder_a"], asunto, cuerpo, orig.get("message_id"))
                escribir(salida, {"ok": True, "enviado_a": orig["responder_a"]})
            sys.stderr.write("correo: enviado\n")
            return 0
    except imaplib.IMAP4.error:
        escribir(salida, {"ok": False, "error": "la cuenta no acepta la contrasena"})
        return 5
    except Exception as e:  # noqa: BLE001
        # el mensaje puede traer la direccion; se recorta y no se registra en el log
        escribir(salida, {"ok": False, "error": type(e).__name__})
        sys.stderr.write("correo: fallo %s\n" % type(e).__name__)
        return 6
    escribir(salida, {"ok": False, "error": "no se que hacer"})
    return 7


if __name__ == "__main__":
    sys.exit(main())
