# EL REBOTE CHARLA <-> TRADUCIR (18/09), que se para a la primera vuelta.
#
# Del log del 18/09 (assistant.log, 23:35:34 -> 23:37:06, y otras tres rafagas ese mismo dia):
#   la charla devolvia "no era charla sino una orden -> 'Este estado es cargando en Steam'",
#   la traduccion contestaba "NO era una orden, pero es espanol tuyo" y se la devolvia a la
#   charla, y vuelta a empezar. 19 vueltas, 19 llamadas de pago a la API en 90 s, Nova ocupada
#   todo ese rato y sin hacer nada. Rafagas medidas ese dia: x4 (18:58), x15 (19:00), x3
#   (20:13) y x19 (23:35).
#
# Aqui se prueban las dos piezas que lo cortan, sacadas DEL ARCHIVO REAL:
#   1) Test-ReboteCharla en assistant.ps1: la segunda vez que la misma frase vuelve de la
#      charla como orden, se para (y caduca al minuto, para que repetirla luego valga).
#   2) el aviso 'sin_orden' que se le manda al worker, y que charla_worker.py lo obedece.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# --- la funcion de verdad, sacada del archivo real ---
$m = [regex]::Match($fuente, '(?ms)^function Test-ReboteCharla\(\$ev\) \{.*?^\}')
if (-not $m.Success) { Write-Host '  MAL  no encuentro Test-ReboteCharla en assistant.ps1'; exit 1 }
. ([scriptblock]::Create($m.Value))
. ([scriptblock]::Create(([regex]::Match($fuente, '(?ms)^function ConvertTo-Plain\(\[string\]\$s\) \{.*?^\}')).Value))

# el reloj que usa la funcion
$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host '-- sin nada marcado, nada rebota --'
$script:charlaRebote = ''
$script:charlaReboteHasta = 0
Comp 'una orden normal pasa' (-not (Test-ReboteCharla @{ texto = 'abre steam' }))

Write-Host '-- con la frase marcada (acaba de volver de la traduccion) --'
$script:charlaRebote = ConvertTo-Plain 'Este estado es cargando en Steam'
$script:charlaReboteHasta = $sw.ElapsedMilliseconds + 60000
Comp 'la misma frase se para' (Test-ReboteCharla @{ texto = 'Este estado es cargando en Steam' })
Comp 'con tildes y mayusculas, igual' (Test-ReboteCharla @{ texto = 'ESTE ESTADO ES CARGANDO EN STEAM' })
Comp 'reescrita por la charla, se mira el original' (Test-ReboteCharla @{ texto = 'mira las descargas'; original = 'Este estado es cargando en Steam' })
Comp 'otra orden distinta SI pasa' (-not (Test-ReboteCharla @{ texto = 'abre el navegador' }))
Comp 'y una parecida pero no igual, tambien pasa' (-not (Test-ReboteCharla @{ texto = 'que se esta descargando en steam' }))

Write-Host '-- caduca al minuto: repetirla mas tarde es un intento nuevo --'
$script:charlaRebote = ConvertTo-Plain 'pon musica'
$script:charlaReboteHasta = $sw.ElapsedMilliseconds - 1
Comp 'pasado el minuto, ya no se para' (-not (Test-ReboteCharla @{ texto = 'pon musica' }))
Comp 'y la marca se borra sola' ($script:charlaRebote -eq '')

Write-Host '-- las dos puntas del rebote en el archivo real --'
Comp 'al devolverla a la charla se marca' ($fuente -match [regex]::Escape('$script:charlaRebote = ConvertTo-Plain $original'))
Comp 'y se le avisa al worker con sin_orden' ($fuente.Contains('@{ sin_orden = $true }') -and $fuente.Contains('Send-Charla $original $false'))
Comp 'la rama que corta va delante de la de siempre' (
    $fuente.IndexOf('Test-ReboteCharla $ev') -gt 0 -and
    $fuente.IndexOf('Test-ReboteCharla $ev') -lt $fuente.IndexOf("charla: no era charla sino una orden"))
Comp 'cortar no encadena seguimiento' ($fuente -match '(?s)ya reboto entre la charla y la traduccion.{0,400}seguimientoPendiente = \$false')

Write-Host '-- y el worker obedece sin_orden --'
$w = [System.IO.File]::ReadAllText((Join-Path $raiz 'charla_worker.py'))
Comp 'charla_worker.py mira sin_orden' ($w -match [regex]::Escape('if p.get("sin_orden"):'))
Comp 'y contesta en vez de devolver la orden' ($w -match '(?s)if p\.get\("sin_orden"\):.{0,200}salida\("frase"')
$i1 = $w.IndexOf('if p.get("sin_orden"):')
$i2 = $w.IndexOf('salida("orden", idp, texto=reescrita, original=texto)')
Comp 'y lo mira ANTES de devolverla' ($i1 -gt 0 -and $i2 -gt 0 -and $i1 -lt $i2)

if ($fallos) { Write-Host "$fallos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto'
