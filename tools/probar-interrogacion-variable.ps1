# "SEGUIMOS CON " - LA PREGUNTA QUE SE COMIA EL NOMBRE (25/09)
#
# EN POWERSHELL 5.1 LA INTERROGACION ES UN CARACTER VALIDO DE NOMBRE DE VARIABLE. Asi que
# dentro de una cadena, "$jg?" no es "el valor de $jg y una interrogacion": es la variable
# $jg?, que no existe, y sale VACIA. La frase entera se queda en nada.
#
# NO ES TEORICO Y NO ES NUEVO. Ya mordio en la auditoria del 13/09 -de ahi viene el comentario
# de assistant.ps1 en la frase de "La ultima vez me dijiste que no era eso"-, y volvio a colarse
# en el saludo de vuelta. Salio en produccion: assistant.log:6458, 25/09 10:57:58,
#     VUELTA: 71 min fuera -> 'Seguimos con '   (con su interrogacion de apertura delante)
# De las tres variantes del saludo de vuelta esa es la UNICA que usa la continuidad -a que
# estabas jugando- y no habia funcionado NUNCA.
#
# Y LO PEOR NO FUE QUE SALIERA MAL UNA VEZ: la frase rota se guardo en memoria\habitos.json
# (presencia.frases), que es la lista con la que Nova evita repetirse. O sea que la frase vacia
# ocupaba una plaza y ademas le quitaba el turno a las que si funcionan.
#
# POR ESO ESTE BANCO NO MIRA UNA FRASE, MIRA EL PATRON: barre TODO el PowerShell del proyecto
# buscando $variable seguida de interrogacion fuera de los comentarios. Arreglar el caso y no
# la clase es como no arreglarlo: ya van dos.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}

Write-Host ''
Write-Host '-- 1. EL FALLO, DEMOSTRADO CON POWERSHELL Y NO CONTADO --'
# Sin esto, el resto del banco es una opinion sobre como cree uno que funciona PowerShell.
$jg = 'Elden Ring'
$malo = "Seguimos con $jg?"
$bueno = "Seguimos con $($jg)?"
Comp 'con $jg? la frase pierde el nombre' (-not $malo.Contains('Elden Ring')) "sale: '$malo'"
Comp 'y con $($jg)? sale entera' ($bueno -eq 'Seguimos con Elden Ring?') "sale: '$bueno'"

Write-Host ''
Write-Host '-- 2. LA FRASE DE VUELTA, SACADA DEL ARCHIVO --'
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))
$mV = [regex]::Match($fuente, '(?m)^\s*if \(\$jg\) \{ \$cands \+= (".*?") \}')
if (-not $mV.Success) { Write-Host '  MAL  no encuentro la frase de vuelta con el juego'; exit 1 }
$plantilla = $mV.Groups[1].Value
Write-Host ("       la plantilla del archivo: " + $plantilla)
$salida = [string](Invoke-Expression $plantilla)
Comp 'la frase de vuelta trae el nombre del juego' ($salida.Contains('Elden Ring')) "sale: '$salida'"
Comp 'y acaba en interrogacion' ($salida.TrimEnd().EndsWith('?')) "sale: '$salida'"

Write-Host ''
Write-Host '-- 3. Y QUE NO QUEDE NINGUNA MAS, EN NINGUN .ps1 DEL PROYECTO --'
# Se miran assistant.ps1, los .ps1 sueltos de la raiz y todos los de tools. Los comentarios se
# quitan antes: un "$var?" dentro de un comentario -como los de este mismo banco- no rompe nada.
# ESTE MISMO SE QUEDA FUERA, y por la misma razon que el detector de huerfanos se excluye a si
# mismo: aqui viven a proposito los ejemplos rotos con los que se demuestra el fallo y con los
# que se comprueba que el detector detecta. Si no, el banco se denunciaria a si mismo siempre.
$ficheros = @(@(Get-ChildItem -LiteralPath $raiz -Filter '*.ps1' -File) +
              @(Get-ChildItem -LiteralPath (Join-Path $raiz 'tools') -Filter '*.ps1' -File) |
              Where-Object { $_.Name -ne 'probar-interrogacion-variable.ps1' })
$sospechosas = @()
foreach ($f in $ficheros) {
    $n = 0
    foreach ($linea in ([System.IO.File]::ReadAllLines($f.FullName))) {
        $n++
        if ($linea -match '^\s*#') { continue }
        $codigo = $linea
        $iC = $codigo.IndexOf('#')
        if ($iC -ge 0 -and -not $codigo.Substring(0, $iC).Contains("'") -and -not $codigo.Substring(0, $iC).Contains('"')) {
            $codigo = $codigo.Substring(0, $iC)
        }
        # $nombre seguido de ? : el ? se lo come el nombre de la variable
        foreach ($m in [regex]::Matches($codigo, '\$[A-Za-z_][A-Za-z0-9_]*\?')) {
            $sospechosas += ("{0}:{1}  {2}" -f $f.Name, $n, $m.Value)
        }
    }
}
Comp 'ninguna variable se come la interrogacion' ($sospechosas.Count -eq 0) $(if ($sospechosas.Count) { ($sospechosas -join ' / ') } else { "$($ficheros.Count) ficheros mirados" })

Write-Host ''
Write-Host '-- 4. Y EL DETECTOR DETECTA --'
# Un barrido que no encuentra nada y uno que no sabe buscar se ven igual.
$deMentira = 'Write-Host "hola $nombre? que tal"'
$cazadas = @([regex]::Matches($deMentira, '\$[A-Za-z_][A-Za-z0-9_]*\?')).Count
Comp 'con una linea de mentira lo caza' ($cazadas -eq 1) "encontro $cazadas"
$buena = 'Write-Host "hola $($nombre)? que tal"'
Comp 'y no se queja de la forma buena' (@([regex]::Matches($buena, '\$[A-Za-z_][A-Za-z0-9_]*\?')).Count -eq 0)

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'ninguna pregunta se come el nombre de la variable'
exit 0
