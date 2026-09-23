# QUE EL AVISO DEL DISCO HABLE CUANDO EL DISCO SE LLENA (22/09 por la noche).
#
# El dato que lo destapo: el ultimo aviso de disco fue a las 08:33:55 -"Te quedan 11.1
# gigas"- y a las 22:50 quedaban 0,81 GB de 475, el 0,18 %, sin una sola palabra en medio.
# Catorce horas: doce son el plazo de 720 minutos del propio aviso y dos y media el silencio
# del modo juego. Y a las 23:00 entraba el silencio de la noche, asi que con el nivel 'medio'
# no habria vuelto a hablar hasta las 08:00 de la mañana siguiente, con el disco a cero.
#
# Un aviso que se calla justo cuando la cosa se pone grave no es prudente, es inutil. Por
# debajo del liston critico pasa a 'alto' -el unico nivel que se salta el juego, la noche y
# el tope por hora, igual que la bateria al 15 %- y con plazo de una hora.
#
# Lo que este banco vigila:
#   - que con el disco critico el nivel sea 'alto' y el plazo corto;
#   - que con poco disco (pero no critico) siga siendo el aviso suave de siempre;
#   - que los dos listones salgan de config.json y no esten escritos a mano;
#   - y que sean DOS claves distintas, o el sello de disco de una taparia a la otra.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# el bloque del disco, contando llaves y no caracteres (ver probar-confirmaciones.ps1)
$ini = $fuente.IndexOf('$discoCritico = [double]')
$cuerpo = ''
if ($ini -ge 0) {
    $fin = $fuente.IndexOf('} catch {}', $ini)
    if ($fin -gt $ini) { $cuerpo = $fuente.Substring($ini, $fin - $ini) }
}

Write-Host ''
Write-Host '-- con el disco a punto de llenarse, habla aunque sea de noche --'
Comp 'el aviso critico existe' ($cuerpo.Length -gt 0) "$($cuerpo.Length) caracteres"
Comp "y va con nivel 'alto'" ($cuerpo -match "'disco-critico'.{0,200}'alto'") 'el unico que se salta la noche y el juego'
$cada = [regex]::Match($cuerpo, "'disco-critico'.{0,220}'alto'\s+(\d+)")
Comp 'con plazo corto, no de doce horas' ($cada.Success -and [int]$cada.Groups[1].Value -le 120) $(if ($cada.Success) { "cada $($cada.Groups[1].Value) min" } else { 'no lo encuentro' })
Comp 'y dice que hacer, no solo que pasa' ($cuerpo -match 'borra algo|que ocupa mas')

Write-Host ''
Write-Host '-- y el de siempre sigue siendo suave --'
Comp "'disco-poco' sigue en 'medio'" ($cuerpo -match "'disco-poco'.{0,200}'medio'") 'con 11 gigas no hay prisa'
Comp 'y son dos claves distintas' (($cuerpo -match "'disco-critico'") -and ($cuerpo -match "'disco-poco'")) 'con una sola, el sello de una taparia a la otra'
Comp 'el critico va ANTES en la cadena' ($cuerpo.IndexOf("'disco-critico'") -lt $cuerpo.IndexOf("'disco-poco'")) 'si no, 0,8 gigas entraria por el suave'

Write-Host ''
Write-Host '-- y el liston lo puede tocar braya --'
Comp 'el liston critico sale de config' ($cuerpo -match "Get-Cfg 'entorno' 'discoCriticoGb'") 'no escrito a mano'
Comp 'con un valor por defecto sensato' ($cuerpo -match "'discoCriticoGb' 2\b") '2 gigas'

Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos caso(s) MAL"; exit 1 }
Write-Host '  el disco lleno se dice a tiempo, y se salta la noche'
exit 0
