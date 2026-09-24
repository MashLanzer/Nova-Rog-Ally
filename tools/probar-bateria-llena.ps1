# QUE "YA ESTA CARGADA DEL TODO" SE DIGA UNA VEZ, NO CUATRO AL DIA (22/09 por la noche).
#
# El aviso y -sobre todo- la regla 'bateriaLlena' colgaban de un ESTADO, no de un cruce:
#     if ($cargando -and $pc -ge 100) { Invoke-Reglas ...; Send-AvisoEntorno ... }
# dentro de un bloque que corre cada sesenta segundos. Con la consola enchufada, eso es
# cierto el dia entero. Medido en assistant.log: 19 avisos identicos, cuatro al dia desde
# el 19/09 (08:00, 12:00, 16:00, 20:02), y el ultimo "cargador: desenchufado" es del 19/09
# a las 09:24, o sea que los quince ultimos salieron sin un solo cambio de estado.
#
# El aviso era lo de menos: es de nivel 'bajo' y solo se ve en la capsula. Lo gordo es la
# linea de al lado, Invoke-Reglas 'bateriaLlena', que NO tiene plazo ninguno (el de 240 min
# vive dentro de Send-AvisoEntorno) y cuya rama del despacho es estado pelado, sin el
# $r.ultima que si tienen 'bateria' y 'disco'. reglas.json esta vacio hoy, pero el dia que
# braya diga "cuando termine de cargar, pon el modo trabajo" -frase que el codigo entiende-
# esa accion se ejecutaria CADA MINUTO hasta que desenchufara. Una orden que nadie dio,
# repetida toda la tarde, que es la unica cosa que aqui no se tolera.
#
# Lo que este banco vigila, y por eso mira lo que HACE y no como esta escrito:
#   - que un dia entero enchufada al 100 % dispare UNA vez y no 240;
#   - que arrancar con la consola ya llena no dispare (el guardia $null);
#   - que desenchufar y volver a llenar SI sea un episodio nuevo;
#   - y que la regla y el aviso sigan los dos DENTRO del mismo if, contando llaves y no
#     caracteres (ver la leccion de tools\probar-confirmaciones.ps1).
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# REGLA DEL BANCO: la funcion se trae del fichero de verdad, nunca se copia aqui. Si se
# copiara, esto probaria su propia copia y seguiria verde con el codigo roto (ya paso tres
# veces en este repo: el umbral de probar-juegos, el patron de probar-recetas y el de la
# capsula).
function Traer([string]$nombre) {
    $fn = $ast.Find({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $nombre }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro $nombre en assistant.ps1"; exit 1 }
    return $fn.Extent.Text
}
Invoke-Expression (Traer 'Test-BateriaLlenaFlanco')

Write-Host ''
Write-Host '-- un dia entero enchufada, que es lo que hace braya --'
# 08:00 del 19/09 en adelante: el log dice que no se desenchufo ni una vez en tres dias.
$script:llenaAntes = $null
$disparos = 0
$vueltas = 0
# primera lectura del arranque: ya esta llena, pero nadie sabe de donde viene
if (Test-BateriaLlenaFlanco $true) { $disparos++ }
$vueltas++
Comp 'arrancar con la consola ya llena no dispara' ($disparos -eq 0) 'el guardia $null'
# y ahora 24 horas de minutos, todas iguales
for ($i = 0; $i -lt 1440; $i++) { if (Test-BateriaLlenaFlanco $true) { $disparos++ }; $vueltas++ }
Comp '1.441 lecturas seguidas al 100 %: 0 disparos' ($disparos -eq 0) "$disparos en $vueltas vueltas"

Write-Host ''
Write-Host '-- y el episodio de verdad si se dice --'
$script:llenaAntes = $null
[void](Test-BateriaLlenaFlanco $false)          # la enchufa al 40 %: no esta llena
$d1 = Test-BateriaLlenaFlanco $false
Comp 'cargando y sin llegar al 100 %, callada' (-not $d1)
$d2 = Test-BateriaLlenaFlanco $true             # cruza el 100 %
Comp 'al cruzar el 100 %, UNA vez' $d2 'este es el aviso que sirve'
$d3 = $false
for ($i = 0; $i -lt 240; $i++) { if (Test-BateriaLlenaFlanco $true) { $d3 = $true } }
Comp 'y las cuatro horas siguientes, callada' (-not $d3) '240 vueltas mas'
[void](Test-BateriaLlenaFlanco $false)          # la desenchufa
$d4 = Test-BateriaLlenaFlanco $true             # la vuelve a enchufar llena
Comp 'desenchufar y volver a llenar SI es otro episodio' $d4 'o no avisaria nunca mas'

Write-Host ''
Write-Host '-- la regla va pegada al aviso, dentro del mismo if --'
# Contando llaves, NO por distancia en caracteres: una ventana de N caracteres alcanza el
# bloque de al lado y entonces el banco pasa en verde con el codigo roto.
$ini = $fuente.IndexOf('if (Test-BateriaLlenaFlanco')
$cuerpo = ''
if ($ini -ge 0) {
    $j = $fuente.IndexOf('{', $ini); $prof = 0
    for ($k = $j; $k -lt $fuente.Length; $k++) {
        if ($fuente[$k] -eq '{') { $prof++ }
        elseif ($fuente[$k] -eq '}') { $prof--; if ($prof -eq 0) { $cuerpo = $fuente.Substring($j, $k - $j + 1); break } }
    }
}
Comp 'el bloque del flanco existe y se delimita' ($cuerpo.Length -gt 0) "$($cuerpo.Length) caracteres"
Comp 'la REGLA esta dentro del flanco' ($cuerpo -match "Invoke-Reglas 'bateriaLlena'") 'lo unico que puede ejecutar algo'
Comp 'el aviso tambien' ($cuerpo -match "Send-AvisoEntorno 'bateria-llena'")
# y que nadie los haya dejado ademas sueltos por ahi fuera
$sueltas = ([regex]::Matches($fuente, "Invoke-Reglas 'bateriaLlena'")).Count
Comp 'y la regla se dispara desde un solo sitio' ($sueltas -eq 1) "$sueltas sitio(s)"

Write-Host ''
Write-Host '-- y el despacho de la regla sigue siendo el de un suceso --'
# Si algun dia 'bateriaLlena' pasara a mirar un estado con memoria propia ($r.ultima), esto
# habria que repensarlo; hoy el flanco es lo unico que lo separa de repetirse cada minuto.
Comp "la rama 'bateriaLlena' no lleva rearme propio" ($fuente -match "'bateriaLlena' \{ \`$dispara = \(\`$dato -eq 'llena'\) \}") 'por eso el flanco es obligatorio'

Write-Host ''
if ($fallos -gt 0) {
    Write-Host "  $fallos caso(s) MAL"
    exit 1
}
Write-Host '  la bateria llena se dice una vez por carga, no cuatro veces al dia'
exit 0
