# EL HISTORIAL DE MUSICA GUARDABA LOS ANUNCIOS DE YOUTUBE (24/09, idea 10 de la tanda nueva).
#
# LA MEDICION: 5 de las 12 entradas de memoria\musica.json -el 41,7 %- son anuncios: Base44,
# Tripo AI, Firebase Brand Video, Copilot in Outlook e Introducing Grok Bot. El patron esta en
# el registro: 15/09 15:00:32 se abre YouTube, 15:00:39 suena "Copilot in Outlook", 15:00:49 la
# de Pitbull de verdad. Diez segundos de pre-roll.
#
# EL LISTON SE ELIGE SOLO, y eso es lo mejor de esta idea: los datos dejan un hueco limpio. De
# las 13 lineas "MUSICA:" del registro, los CINCO anuncios duraron 5 o 10 segundos y la cancion
# mas corta que sobrevivio duro 55. Entre 10 y 55 no hay NADA. Cualquier numero de ese hueco
# separa los cinco de las ocho sin un solo falso positivo; se puso 20, que es el doble del
# anuncio mas largo y menos de la mitad de la cancion mas corta.
#
# LO QUE MAS SE VIGILA: que no se pierda una cancion de verdad. Tirar un anuncio no cuesta
# nada; tirar una cancion rompe "como se llamaba esa cancion", que es para lo que existe esto.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }
Invoke-Expression (Traer 'Test-MusicaAsentada')
$espera = 20

Write-Host ''
Write-Host '-- 1. LA TARDE DEL 15/09, segundo a segundo --'
# Lo que sono de verdad: el anuncio de Copilot a las 15:00:39 y la cancion a las 15:00:49.
# Aqui se corre en milisegundos lo que entonces duro veinte segundos.
$script:musicaCandidato = $null
$t = 0
$apuntados = New-Object System.Collections.ArrayList
function Suena([string]$tit, [int]$seg) {
    for ($i = 0; $i -lt $seg; $i++) {
        $script:t += 1000
        if (Test-MusicaAsentada $tit 'x' $script:t $script:espera) { [void]$script:apuntados.Add($tit) }
    }
}
$script:t = 0; $script:espera = 20
Suena 'Copilot in Outlook helps Marcel' 10      # el anuncio, diez segundos
Suena 'Pitbull - Timber' 200                    # la cancion, tres minutos y pico
Comp 'el anuncio de 10 s NO se apunta' (@($apuntados | Where-Object { $_ -match 'Copilot' }).Count -eq 0) ''
Comp 'y la cancion si' (@($apuntados | Where-Object { $_ -match 'Timber' }).Count -eq 1) ''
Comp 'y solo una vez, no una por vuelta' ($apuntados.Count -eq 1) "$($apuntados.Count) apuntes"

Write-Host ''
Write-Host '-- 2. LOS CINCO ANUNCIOS REALES, con su duracion real --'
# Los cinco que hoy estan en memoria\musica.json, con los segundos que duraron segun el log.
$anuncios = @(
    @{ t = 'Base44 Superagents - Your Personal AI Agent'; seg = 10 },
    @{ t = 'Tripo AI Workflow'; seg = 10 },
    @{ t = 'Firebase Brand Video Skippable Version 2'; seg = 5 },
    @{ t = 'Copilot in Outlook helps Marcel personalize'; seg = 10 },
    @{ t = 'Introducing Grok Bot'; seg = 10 }
)
foreach ($a in $anuncios) {
    $script:musicaCandidato = $null; $script:t = 0
    $apuntados.Clear()
    Suena $a.t $a.seg
    Comp ("'$($a.t.Substring(0, [Math]::Min(34, $a.t.Length)))' ($($a.seg) s)") ($apuntados.Count -eq 0) 'fuera'
}

Write-Host ''
Write-Host '-- 3. y las canciones de verdad, TODAS --'
# La mas corta que sobrevivio duro 55 s. Si alguna de estas se perdiera, la idea seria peor
# que el problema: "como se llamaba esa cancion" es justo para lo que existe el historial.
$canciones = @(
    @{ t = 'Ed Sheeran - Thinking Out Loud (Official Music Video)'; seg = 55 },
    @{ t = 'Dany Ome & Kevincito El 13 ft Michael Flores'; seg = 180 },
    @{ t = 'Pitbull - Fireball'; seg = 210 }
)
foreach ($c in $canciones) {
    $script:musicaCandidato = $null; $script:t = 0
    $apuntados.Clear()
    Suena $c.t $c.seg
    Comp ("'$($c.t.Substring(0, [Math]::Min(34, $c.t.Length)))' ($($c.seg) s)") ($apuntados.Count -eq 1) 'entra'
}

Write-Host ''
Write-Host '-- 4. el hueco de los datos, por los dos lados --'
# Entre 10 s (el anuncio mas largo) y 55 s (la cancion mas corta) no hay nada medido. El
# liston esta en 20, asi que tiene el doble de margen por abajo y casi el triple por arriba.
foreach ($seg in @(1, 5, 10, 15, 19)) {
    $script:musicaCandidato = $null; $script:t = 0; $apuntados.Clear()
    Suena 'lo que sea' $seg
    Comp ("lo que dura $seg s se queda fuera") ($apuntados.Count -eq 0) ''
}
foreach ($seg in @(21, 30, 55, 300)) {
    $script:musicaCandidato = $null; $script:t = 0; $apuntados.Clear()
    Suena 'lo que sea' $seg
    Comp ("lo que dura $seg s entra") ($apuntados.Count -eq 1) ''
}

Write-Host ''
Write-Host '-- 5. y cuando para la musica, se olvida el candidato --'
# Si no, un anuncio a medias se apuntaria al volver a sonar cualquier cosa veinte segundos
# despues, aunque fuera otra cancion distinta.
$script:musicaCandidato = $null; $script:t = 0; $apuntados.Clear()
Suena 'un anuncio a medias' 10
Comp 'un titulo vacio borra el candidato' (-not (Test-MusicaAsentada '' '' ($script:t + 1000) 20)) ''
Comp 'y el candidato se va' ($null -eq $script:musicaCandidato) ''
$script:t += 60000
$apuntados.Clear()
Suena 'un anuncio a medias' 25
Comp 'y al volver empieza a contar de cero' ($apuntados.Count -eq 1) 'los 25 s nuevos, no los 10 viejos'

Write-Host ''
Write-Host '-- 6. LO QUE NO SE TOCA --'
$tm = SinComentarios (Traer 'Test-MusicaAsentada')
Comp 'no escribe en disco' (($tm -notmatch 'WriteAllText') -and ($tm -notmatch 'Add-HistorialMusica')) 'decide; quien guarda es el otro'
Comp 'ni habla ni pinta la capsula' (($tm -notmatch '\bSay\b') -and ($tm -notmatch 'Set-UI')) ''
Comp 'ni mira el reloj por su cuenta' ($tm -notmatch 'Get-Date') 'todo por parametro'
$bloque = (($fuente -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
# LA LINEA DEL REGISTRO SIGUE AL INSTANTE: de ahi salieron los numeros con los que se eligio
# el liston. Si se retrasara, la proxima vez no se podria volver a medir.
Comp 'la linea MUSICA del registro sigue yendo al instante' ($bloque -match 'Log "MUSICA: \$\(\$mu\.titulo\) - \$\(\$mu\.artista\)"') 'hay otras dos lineas MUSICA: mas abajo'
Comp 'y la capsula sigue ensenando el titulo al cambiar' ($bloque -match "Set-UI 'hablando' \`$tM") 'ahi un anuncio no molesta: dura 3,5 s y no se guarda'
Comp 'el bucle usa Test-MusicaAsentada' ($bloque -match 'Test-MusicaAsentada \$mu\.titulo') ''
Comp 'y el liston se puede ajustar sin tocar el codigo' ($fuente -match "Get-Cfg 'musica' 'segundosParaApuntar' 20") ''

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  un anuncio de YouTube ya no entra en el historial de musica'
exit 0
