# -*- coding: utf-8 -*-
# EL LOG ES DONDE BRAYA MIDE, Y SE ESTABA LLENANDO DE RUIDO (22/09).
#
# Tres cosas de la misma familia, las tres encontradas peinando el codigo y las tres
# confirmadas contando sobre assistant.log:
#
# A. EL AVISO DE RUIDO SE SALTABA EL FILTRO DEL LATIDO. wake_vosk.py llamaba a anota()
#    directo en la rama del ruido de fondo, mientras sus TRES hermanas del mismo bloque
#    llaman a anota_pulso(), que se anadio el 18/09 justo para esto ("el latido solo cuando
#    dice algo nuevo"). Medido: 2.451 lineas identicas en un solo dia, 392 KB, el 56,2 % de
#    todo lo que Nova escribio ese dia, una cada 15,0 s y hasta 1.054 seguidas. Las
#    hermanas van a 61,0 s. Y el log estaba en 4,62 MB de los 5,24 de maxLogBytes sin haber
#    rotado NUNCA: con keepLogs = 3 eso recortaba el historial de ~70 dias a ~31, y el
#    historial es de donde salen los numeros con los que se decide aqui.
#
# B. UNA CONDICION QUE NO PODIA DAR FALSO. nivel_salida() comparaba
#    '_medidor_creado == ahora' tres lineas despues de asignarle ahora. Lo que se escribio
#    como un aviso de arranque salia en cada refresco del medidor (300 s), porque el
#    medidor se rehace a proposito por si cambias de altavoces a cascos. 421 apariciones en
#    el log, 209 en un solo proceso en 23,8 h, cadencia mediana de 300 s clavados.
#
# C. EL VOCABULARIO QUE NADIE LEE, y sobre todo LOS COMENTARIOS QUE MENTIAN. Tres sitios
#    decian en presente que a Whisper se le pasan las apps y juegos como pistas. Whisper
#    dejo de recibirlas el 11/09 y la escucha dejo de abrir el fichero el 19/09. El codigo
#    NO se borra -su unico lector es tools\probar-audio.py, que compara Whisper con y sin
#    pistas-, pero los comentarios ya no mienten.
#    Y de paso quedo medido que quitarlas funciono: la firma de la alucinacion (tres o mas
#    nombres del catalogo en fila) sale 4 veces en todo el log, las CUATRO el 11/09, y ni
#    una en los once dias siguientes.
import io
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAKE = io.open(os.path.join(RAIZ, "wake_vosk.py"), encoding="utf-8").read()
ASIS = io.open(os.path.join(RAIZ, "assistant.ps1"), encoding="utf-8").read()

fallos = 0


def comp(etiqueta, ok, detalle=""):
    global fallos
    print("  %s  %-54s %s" % ("OK " if ok else "MAL", etiqueta, detalle))
    if not ok:
        fallos += 1


print("")
print("-- A. el aviso de ruido pasa por el filtro del latido --")
# El bloque entero de la rama del ruido, tal cual esta en el fichero.
m = re.search(r"anota_pulso\(\"pulso: esto no es voz, es ruido de fondo.{0,400}?ahora\)", WAKE, re.S)
comp("el aviso de ruido llama a anota_pulso", bool(m))
comp("y le pasa 'ahora', que es lo que el filtro compara", bool(m and m.group(0).rstrip().endswith("ahora)")))
comp("ya no queda ningun anota( directo en esa rama",
     "anota(\"pulso: esto no es voz" not in WAKE)
# LAS DEL LATIDO VAN CON FILTRO; LA DEL p90, NO, Y ESO ES A PROPOSITO. Escribi este banco
# exigiendo que las cinco fueran iguales y salio rojo, con razon: "pulso: p90=" lleva su
# propio comentario desde antes ("esta SI se escribe siempre: es el ajuste de ganancia de
# verdad, el dato con el que se decide si la escucha esta bien calibrada"). No es un
# latido, es un cambio real. Asi que el banco protege LAS DOS decisiones: que las cuatro
# del latido filtren, y que la del p90 siga sin filtrar por si alguien la "arregla".
ramas = dict((m.group(2), m.group(1) or "") for m in re.finditer(r"anota(_pulso)?\(\"pulso: (\w+)", WAKE))
delatido = {k: v for k, v in ramas.items() if k != "p90"}
comp("las ramas del latido van por anota_pulso",
     len(delatido) >= 4 and all(v == "_pulso" for v in delatido.values()),
     "%d de latido, %d con filtro" % (len(delatido), sum(1 for v in delatido.values() if v)))
comp("y la del p90 sigue escribiendose SIEMPRE", ramas.get("p90") == "",
     "es un ajuste de verdad, no un latido")
comp("con su motivo escrito al lado", "esta SI se escribe siempre" in WAKE)
# Y el filtro tiene que seguir existiendo y con su tope.
comp("anota_pulso sigue existiendo", "def anota_pulso(" in WAKE)
mtope = re.search(r"PULSO_REPETIDO_MAX\s*=\s*([0-9.]+)", WAKE)
comp("con su tope de repeticion", bool(mtope), "%s s" % (mtope.group(1) if mtope else "?"))

print("")
print("-- B. el aviso del medidor sale una vez, no 421 --")
comp("existe la bandera de 'ya lo dije'", "_medidor_avisado = False" in WAKE)
comp("y esta declarada como global en nivel_salida",
     bool(re.search(r"global _medidor_fallos, _medidor_creado, _medidor_reintento, _medidor_avisado", WAKE)))
# SOBRE EL CODIGO, NO SOBRE LOS COMENTARIOS: el comentario nuevo CITA la condicion vieja
# para explicar que se quito, y sin quitar comentarios esto salia rojo por su propia
# explicacion. Es el mismo tropiezo que ya me costo un rojo con la palabra "Say".
WAKE_CODIGO = "\n".join(re.sub(r"#.*$", "", l) for l in WAKE.split("\n"))
comp("la condicion ya no se compara consigo misma",
     "elif _medidor_creado == ahora" not in WAKE_CODIGO)
comp("ahora mira la bandera", "elif not _medidor_avisado and not _medidor_valor:" in WAKE)
comp("y la levanta al avisar",
     bool(re.search(r"_medidor_avisado = True\s*\n\s*anota\(\"medidor de altavoces activo", WAKE)))
# LO QUE NO DEBE CAMBIAR: el medidor se SIGUE rehaciendo cada 300 s (por si cambias de
# altavoces a cascos). Lo unico que se calla es el aviso.
comp("el medidor se sigue rehaciendo cada tanto",
     "ahora - _medidor_creado > REFRESCO_MEDIDOR" in WAKE)
comp("y el aviso de recuperado tras fallos sigue",
     "medidor de altavoces recuperado tras" in WAKE)

# Y SE EJECUTA, no solo se lee: 300 refrescos con los altavoces callados.
_avisado, _valor, avisos = False, 0.0, 0
for _ in range(300):
    if not _avisado and not _valor:
        _avisado = True
        avisos += 1
comp("300 refrescos dan 1 aviso", avisos == 1, "%d aviso(s)" % avisos)
# la condicion de antes, para que se vea la diferencia
viejos = 0
for i in range(300):
    ahora = 1000.0 + i * 300
    _creado = ahora
    if _creado == ahora and not 0.0:
        viejos += 1
comp("y con la de antes daban 300", viejos == 300, "%d avisos" % viejos)

print("")
print("-- C. los comentarios del vocabulario ya no mienten --")
# El fichero se SIGUE escribiendo a proposito: su unico lector es la herramienta que mide
# Whisper con y sin pistas, y borrarlo dejaria esa medicion coja.
comp("el fichero se sigue escribiendo", "WriteAllText($RutaVocabulario" in ASIS)
pa = os.path.join(RAIZ, "tools", "probar-audio.py")
comp("y su lector real sigue ahi", os.path.exists(pa) and "vocabulario.txt" in io.open(pa, encoding="utf-8").read(),
     "tools/probar-audio.py")
# Los tres sitios que decian en presente lo que no es.
comp("ya no dice 'se le pasan ... como pistas' en presente",
     "A Whisper se le pasan tus apps y juegos como pistas" not in ASIS)
comp("ni 'para que Whisper acierte los nombres'",
     "# vocabulario (apps, sitios, juegos) para que Whisper acierte los nombres" not in ASIS)
comp("y los tres dicen desde cuando no es verdad",
     ASIS.count("11/09") >= 1 and ASIS.count("19/09") >= 1 and "leer_vocabulario" in ASIS)
# La escucha ya lo dejaba escrito; que siga.
comp("la escucha sigue explicando que no lo lee", "AQUI NO SE LEE" in WAKE)
comp("y que su initial_prompt no tiene nombres propios",
     bool(re.search(r'PROMPT_ORDENES = "[^"]*"', WAKE)) and "Hollow" not in re.search(r'PROMPT_ORDENES = "([^"]*)"', WAKE).group(1))
# La red de la alucinacion se queda aunque ya no dispare.
comp("Test-CatalogoRecitado se queda de red", "function Test-CatalogoRecitado" in ASIS)
comp("y se dice que sale gratis en el 99 % de las frases",
     "-notmatch ','" in ASIS or "notmatch ','" in ASIS)

print("")
print("-- y lo que NO puede cambiar en ningun caso --")
# Nada de esto toca una decision: son lineas de log y comentarios.
for aguja, que in (("def umbral_actividad", "la puerta de actividad sigue"),
                   ("ganancia_buena = ", "la ganancia calibrada se sigue guardando"),
                   ("RUTA_ESTADO", "el fichero de estado sigue escribiendose")):
    comp(que, aguja in WAKE)
# Y la recuperacion de ganancia -las 9 "vuelvo a la x" del log- sigue pudiendo salir: es el
# unico texto que anota_pulso podria tragarse de mas, y por eso se mira aparte.
comp("la recuperacion de ganancia sigue escribiendose", "vuelvo a la x" in WAKE)
# El aviso HABLADO del ruido es otro artefacto y no se ha tocado.
comp("el aviso hablado del ruido no se toca", "Send-AvisoEntorno" in ASIS)

print("")
if fallos:
    print("  %d caso(s) MAL" % fallos)
    sys.exit(1)
print("  el log deja de llenarse de lo mismo, y los comentarios dicen la verdad")
sys.exit(0)
