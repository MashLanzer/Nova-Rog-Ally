# "CADA DOS HORAS DI QUE ESTIRE LA ESPALDA" (23/09, idea 4).
#
# NO se amplia recordatorios.json: eso seria una SEGUNDA lista de cosas periodicas al lado de
# reglas.json, y el propio codigo ya tiene escrita esa leccion ("dos listas distintas acabarian
# separandose"). Lo que se arregla es la regla 'cada', que existe desde hace dias y para su
# frase NO FUNCIONABA. Tres fallos, los tres comprobados en el fuente:
#
#  1. NO ENTRABA LA FRASE. El patron exige digitos y ConvertTo-Plain no convierte palabras;
#     ConvertTo-Digitos existia y no la llamaba nadie desde Invoke-ReglaVoz. Asi que "cada DOS
#     horas di que estire la espalda" no casaba con nada y se iba al modelo.
#
#  2. EL RELOJ ERA EL CRONOMETRO DEL PROCESO, Y SE PERSISTIA. $r.ultima guardaba
#     $sw.ElapsedMilliseconds y se escribia en reglas.json. Al reiniciar, $sw vuelve a cero y
#     $r.ultima sigue valiendo 7200000: la resta sale NEGATIVA y la regla NO VUELVE A HABLAR
#     NUNCA. Con 244 arranques en 15 dias -16,3 al dia- eso pasa el primer dia. Y es un fallo
#     MUDO: braya lo pide, Nova dice "Regla 1 guardada" y no dice nada nunca mas.
#
#  3. Aunque ultima estuviera a cero, la cuenta empezaba de cero en cada arranque, asi que
#     "cada dos horas" casi nunca llegaba a las dos horas: la sesion media no llega a hora y
#     media.
#
# Y lo que faltaba de la regla 2 (ningun modo sin salida): plazo de hoy salvo que diga
# "siempre", y una segunda salida por texto ademas de la del numero.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

foreach ($f in @('Test-CadaDispara', 'Test-ReglaCaducada', 'ConvertTo-Digitos', 'ConvertTo-Plain', 'ConvertTo-Suave')) {
    Invoke-Expression (Traer $f)
}
$NumerosPalabra = Invoke-Expression ([regex]::Match($fuente, '(?s)^\$NumerosPalabra = (@\{.*?\n\})', [Text.RegularExpressions.RegexOptions]::Multiline).Groups[1].Value)

Write-Host ''
Write-Host '-- 1. EL FALLO MUDO: el cronometro del proceso, persistido --'
# Esta es la que tiene que cantar. Con el codigo de antes, una regla con 'ultima' heredada de
# otra sesion se quedaba callada PARA SIEMPRE.
$ahora = [datetime]'2026-09-23 12:00:00'
$r1 = @{ id = 1; tipo = 'cada'; valor = '120'; accion = 'di estira la espalda'; ultima = '7200000'; hasta = '' }
$d1 = Test-CadaDispara $r1 $ahora
Comp 'con el formato viejo no dispara de golpe' (-not $d1) 'arranca la cuenta, no habla'
Comp 'pero se rearma con la hora de pared' ($r1.ultima -eq $ahora.ToString('s')) "$($r1.ultima)"
$d1b = Test-CadaDispara $r1 $ahora.AddMinutes(121)
Comp 'y al periodo siguiente SI habla' $d1b 'antes se quedaba muda para siempre'

Write-Host ''
Write-Host '-- 2. nada de avisos atrasados tras un apagon (regla 1) --'
# Nueve horas apagado con periodo de dos: tocaban cuatro. Se dispara UNA.
$r2 = @{ id = 2; tipo = 'cada'; valor = '120'; accion = 'di estira la espalda'; ultima = ([datetime]'2026-09-23 03:00:00').ToString('s'); hasta = '' }
$veces = 0
if (Test-CadaDispara $r2 $ahora) { $veces++ }
if (Test-CadaDispara $r2 $ahora) { $veces++ }
if (Test-CadaDispara $r2 $ahora.AddMinutes(1)) { $veces++ }
Comp 'tras nueve horas apagado, habla UNA vez' ($veces -eq 1) "$veces veces"
Comp 'y se rearma a ahora, no a la hora que tocaba' ($r2.ultima -eq $ahora.ToString('s')) "$($r2.ultima)"

Write-Host ''
Write-Host '-- 3. recien creada: cuenta desde que se crea --'
$r3 = @{ id = 3; tipo = 'cada'; valor = '120'; accion = 'di estira la espalda'; ultima = ''; hasta = '' }
Comp 'al crearla no habla' (-not (Test-CadaDispara $r3 $ahora))
Comp 'a los 119 minutos, tampoco' (-not (Test-CadaDispara $r3 $ahora.AddMinutes(119)))
Comp 'a los 120, si' (Test-CadaDispara $r3 $ahora.AddMinutes(120))
Comp 'y el siguiente sale a las cuatro horas' ((-not (Test-CadaDispara $r3 $ahora.AddMinutes(239))) -and (Test-CadaDispara $r3 $ahora.AddMinutes(240)))

Write-Host ''
Write-Host '-- 4. el plazo (regla 2: ni un modo sin salida) --'
$hoy = $ahora.ToString('yyyy-MM-dd')
$r4 = @{ id = 4; tipo = 'cada'; valor = '120'; accion = 'di estira'; ultima = ''; hasta = $hoy }
Comp 'hoy no ha caducado' (-not (Test-ReglaCaducada $r4 $ahora))
Comp 'a las 23:59 de hoy, tampoco' (-not (Test-ReglaCaducada $r4 ([datetime]'2026-09-23 23:59:00')))
Comp 'y manana si' (Test-ReglaCaducada $r4 $ahora.AddDays(1))
$r5 = @{ id = 5; tipo = 'cada'; valor = '120'; accion = 'di estira'; ultima = ''; hasta = '' }
Comp 'la que dijo "siempre" no caduca nunca' (-not (Test-ReglaCaducada $r5 $ahora.AddDays(400))) 'hasta vacio = sin plazo'
$r6 = @{ id = 6; tipo = 'cada'; valor = '120'; accion = 'di estira'; ultima = '' }
Comp 'y una regla vieja, sin el campo, tampoco' (-not (Test-ReglaCaducada $r6 $ahora.AddDays(400))) 'las de antes se portan igual'

Write-Host ''
Write-Host '-- 5. LAS FRASES, POR EL PATRON DE VERDAD --'
# Se saca el cuerpo entero de Invoke-ReglaVoz y se ejecuta: aqui no se copia ningun regex.
$VERBOS = Invoke-Expression ([regex]::Match($fuente, '(?m)^\$VERBOS = (.+)$').Groups[1].Value)
$script:reglas = $null
$script:guardadas = @()
$ReglasPath = Join-Path ([System.IO.Path]::GetTempPath()) ('rep-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.json')
function Log([string]$m) { }
function Add-Estadistica($a, $b) { }
function Save-Reglas { }
function Save-Corrupto($a, $b) { }
function Write-Atomico($a, $b) { }
function Test-FastCommand([string]$t) { return ($t -match '^(?:di|avisa|modo|pon|abre|cierra|sube|baja)\b') }
function Find-Juego([string]$n) { return $null }
function Test-Prop($o, $n) { return $false }
$cmds = $null
foreach ($f in @('Get-Reglas', 'Describe-Regla', 'Invoke-ReglaVoz', 'Resolve-SujetoRegla', 'Remove-Filler', 'Get-Veces')) {
    Invoke-Expression (Traer $f)
}
foreach ($v in @('FILLER_INI', 'FILLER_FIN', 'FILLER_GLOBAL')) {
    Invoke-Expression ('$' + $v + ' = ' + ([regex]::Match($fuente, '(?m)^\$' + $v + ' = (.+)$').Groups[1].Value))
}

function Reset { $script:reglas = $null; [void](Get-Reglas) }
Reset
$res = Invoke-ReglaVoz 'recuerdame cada dos horas que estire la espalda'
$g = Get-Reglas
Comp 'SU frase crea una regla' ($g.Count -eq 1) "$res"
Comp 'y es de tipo cada' ($g.Count -eq 1 -and $g[0].tipo -eq 'cada') $(if ($g.Count) { $g[0].tipo } else { '' })
Comp 'con dos horas en minutos' ($g.Count -eq 1 -and $g[0].valor -eq '120') $(if ($g.Count) { $g[0].valor } else { '' })
Comp 'y la accion es hablar, no otra cosa' ($g.Count -eq 1 -and $g[0].accion -eq 'di estire la espalda') $(if ($g.Count) { $g[0].accion } else { '' })
Comp 'nace con plazo de hoy' ($g.Count -eq 1 -and $g[0].hasta -eq (Get-Date).ToString('yyyy-MM-dd')) $(if ($g.Count) { $g[0].hasta } else { '' })
Comp 'y Nova dice las dos salidas en voz alta' ($res -match "siempre" -and $res -match "borra la regla 1") "$res"

Reset
$res2 = Invoke-ReglaVoz 'cada 2 horas di que estire la espalda'
$g2 = Get-Reglas
Comp 'la forma que YA existia sigue dando lo mismo' ($g2.Count -eq 1 -and $g2[0].valor -eq '120' -and $g2[0].accion -eq 'di que estire la espalda') "$($g2[0].valor) / $($g2[0].accion)"

Reset
[void](Invoke-ReglaVoz 'cada media hora avisame')
$g3 = Get-Reglas
Comp '"cada media hora" son 30 minutos' ($g3.Count -eq 1 -and $g3[0].valor -eq '30') $(if ($g3.Count) { $g3[0].valor } else { 'no entro' })

Reset
[void](Invoke-ReglaVoz 'cada 5 minutos di hola')
$g4 = Get-Reglas
Comp '"cada 5 minutos" son 5' ($g4.Count -eq 1 -and $g4[0].valor -eq '5') $(if ($g4.Count) { $g4[0].valor } else { 'no entro' })

Reset
$res5 = Invoke-ReglaVoz 'recuerdame cada dos horas que estire la espalda, siempre'
$g5 = Get-Reglas
Comp 'con "siempre" no nace con plazo' ($g5.Count -eq 1 -and $g5[0].hasta -eq '') "hasta='$(if ($g5.Count) { $g5[0].hasta } else { '' })'"

Write-Host ''
Write-Host '-- 6. no le roba la frase al aviso del tiempo de juego --'
# "avisame cada hora" es del aviso de juego (idea 11-B) y vive en Resolve-Fragment, que se
# mira DESPUES de las reglas. Si el patron nuevo se la comiera, esa funcion moriria muda.
Reset
$resJ = Invoke-ReglaVoz 'avisame cada hora'
Comp '"avisame cada hora" no crea ninguna regla' ($null -eq $resJ -and (Get-Reglas).Count -eq 0) "$resJ"
Reset
$resJ2 = Invoke-ReglaVoz 'avisame cada 30 minutos'
Comp 'ni "avisame cada 30 minutos"' ($null -eq $resJ2 -and (Get-Reglas).Count -eq 0) "$resJ2"
Reset
$resJ3 = Invoke-ReglaVoz 'avisame cada 30 minutos que beba agua'
Comp 'pero con una accion detras, si' ((Get-Reglas).Count -eq 1) "$resJ3"
# Y LA OTRA MITAD: apagarlo. "quita el aviso de cada hora" tambien es del aviso del tiempo de
# juego, y esta funcion se mira ANTES que Resolve-Fragment, asi que la salida por texto se lo
# comio y dejo aquel patron en codigo muerto. Lo canto probar-tiempo-juego. Van aqui las
# cinco formas cerradas, para que no vuelva a pasar por el otro lado.
$bienQ = 0
foreach ($fQ in @('quita el aviso de cada hora', 'quita el aviso de juego', 'quita el aviso del tiempo',
                  'quita el aviso de rato', 'quita el aviso de tiempo de juego')) {
    Reset
    $rQ = Invoke-ReglaVoz $fQ
    if ($null -eq $rQ) { $bienQ++ } else { Write-Host "       se lo quedo: '$fQ' -> $rQ" }
}
Comp 'y no le roba ninguna de las cinco de apagarlo' ($bienQ -eq 5) "$bienQ de 5"
Reset
[void](Invoke-ReglaVoz 'recuerdame cada 30 minutos que beba agua')
$rQ2 = Invoke-ReglaVoz 'quita el aviso del agua'
Comp 'pero "quita el aviso del agua" si es suyo' ((Get-Reglas).Count -eq 0) "$rQ2"

Write-Host ''
Write-Host '-- 7. nada destructivo se queda guardado --'
Reset
$resD = Invoke-ReglaVoz 'cada 10 minutos cierra todo'
Comp '"cada 10 minutos cierra todo" se rechaza' ((Get-Reglas).Count -eq 0) "$resD"
Reset
[void](Invoke-ReglaVoz 'cada 10 minutos di ya esta todo listo')
Comp 'pero "di ya esta todo listo" se guarda' ((Get-Reglas).Count -eq 1) 'la excepcion del "di"'

Write-Host ''
Write-Host '-- 8. LAS DOS SALIDAS --'
Reset
[void](Invoke-ReglaVoz 'recuerdame cada dos horas que estire la espalda')
[void](Invoke-ReglaVoz 'recuerdame cada 30 minutos que beba agua')
[void](Invoke-ReglaVoz 'cada 45 minutos di mira por la ventana')
$gs = Get-Reglas
Comp 'tres reglas puestas' ($gs.Count -eq 3) "$($gs.Count)"
$resB = Invoke-ReglaVoz 'deja de recordarme lo de la espalda'
$gs2 = Get-Reglas
Comp 'la salida por texto borra la que era' ($gs2.Count -eq 2) "$resB"
Comp 'y deja las otras dos intactas' (@($gs2 | Where-Object { $_.accion -match 'espalda' }).Count -eq 0)
Comp 'y dice el numero, por si acaso' ($resB -match 'regla 1') "$resB"
$resB2 = Invoke-ReglaVoz 'borra la regla 2'
Comp 'la salida por numero sigue funcionando' ((Get-Reglas).Count -eq 1) "$resB2"
$resB3 = Invoke-ReglaVoz 'deja de recordarme lo de la siesta'
Comp 'y si no hay ninguna, lo dice sin borrar nada' ((Get-Reglas).Count -eq 1 -and $resB3 -match 'ningun') "$resB3"
# LAS DOS SALIDAS NO SE PISAN, y no es por el orden: se probo cambiandolas de sitio y no
# pasaba nada. Lo que las separa es que la de texto exige la palabra "recordatorio", "aviso"
# o "recordarme", que la de numero no lleva.
$reTexto = [regex]::Match($fuente, "(?m)^\s*if \(\`$p -match '(\^\(\?:deja.+?)'\) \{").Groups[1].Value
if (-not $reTexto) { Write-Host '  MAL  no encuentro la salida por texto'; exit 1 }
Comp '"borra la regla 2" no entra por la de texto' ('borra la regla 2' -notmatch $reTexto) 'por eso el orden no decide nada'
Comp 'ni "borra todas las reglas"' ('borra todas las reglas' -notmatch $reTexto)
Comp 'pero "borra el recordatorio del agua" si' ('borra el recordatorio del agua' -match $reTexto)

Write-Host ''
Write-Host '-- 9. SI HAY DOS QUE ENCAJAN NO SE BORRA NINGUNA (regla 1) --'
Reset
[void](Invoke-ReglaVoz 'recuerdame cada dos horas que estire la espalda')
[void](Invoke-ReglaVoz 'recuerdame cada 30 minutos que estire las piernas')
$resE = Invoke-ReglaVoz 'deja de recordarme lo de estire'
Comp 'con dos candidatas no borra nada' ((Get-Reglas).Count -eq 2) "$resE"
Comp 'y las lee con su numero para elegir' ($resE -match 'regla 1' -and $resE -match 'regla 2') "$resE"

Write-Host ''
Write-Host '-- 10. LAS DOS PUERTAS DICEN LO MISMO --'
# Si se arregla el patron de Invoke-ReglaVoz y se olvida el de Test-FastCommand, la regla se
# crea pero la capsula no asiente y el banco la da por no reconocida: verde aqui, rojo en la
# realidad. Es la leccion del commit e1ab4dc.
$rePuerta = [regex]::Match($fuente, "(?m)^\s*if \(\`$plD4 -match '(.+)'\) \{").Groups[1].Value
if (-not $rePuerta) { Write-Host '  MAL  no encuentro el ancla de Test-FastCommand'; exit 1 }
# Y LA LINEA QUE PREPARA EL TEXTO, tambien del fuente: sin esto el banco probaria el regex
# con SU propia normalizacion y no veria que alguien le ha quitado ConvertTo-Digitos a la
# puerta. Es justo la mitad del fallo que se quiere vigilar.
$asigPuerta = [regex]::Match($fuente, '(?m)^\s*\$plD4 = (.+)$').Groups[1].Value
if (-not $asigPuerta) { Write-Host '  MAL  no encuentro como prepara el texto Test-FastCommand'; exit 1 }
$frasesP = @(
    @('recuerdame cada dos horas que estire la espalda', $true),
    @('recuerdame cada 30 minutos que beba agua', $true),
    @('cada 2 horas di que estire la espalda', $true),
    @('cada media hora avisame', $true),
    @('cada 5 minutos di hola', $true),
    @('pon musica', $false),
    @('que hora es', $false),
    @('abre steam', $false)
)
$igual = 0
foreach ($par in $frasesP) {
    Reset
    $porRegla = ($null -ne (Invoke-ReglaVoz $par[0]))
    $porPuerta = & { $pl = (ConvertTo-Plain $par[0]); Invoke-Expression ('$plD4 = ' + $asigPuerta); return ([bool]($plD4 -match $rePuerta)) }
    if ($porRegla -eq $par[1] -and $porPuerta -eq $par[1]) { $igual++ }
    else { Write-Host "       no coinciden: '$($par[0])'  regla=$porRegla puerta=$porPuerta (tenia que ser $($par[1]))" }
}
Comp 'las ocho frases dicen lo mismo en las dos puertas' ($igual -eq 8) "$igual de 8"

Write-Host ''
Write-Host '-- 11. y la voz de un video no puede dejar una regla puesta --'
$anclaVoz = [regex]::Match($fuente, "(?m)^\s*if \(-not \`$script:confirmado -and \(ConvertTo-Plain \`$text\) -match '(.+?)' -and \(Test-VozExtrana\)\) \{").Groups[1].Value
if (-not $anclaVoz) { Write-Host '  MAL  no encuentro el ancla de VOZ EXTRANA'; exit 1 }
Comp 'el ancla de voz extrana cubre "recuerdame cada"' ('recuerdame cada dos horas que estire la espalda' -match $anclaVoz) "$anclaVoz"
Comp 'y "avisame cada"' ('avisame cada 30 minutos que beba agua' -match $anclaVoz)
Comp 'sin tocar lo que ya cubria' ('cuando abra steam pon modo juego' -match $anclaVoz)

Write-Host ''
Write-Host '-- 12. el reloj de pared, no el cronometro --'
$tc = SinComentarios (Traer 'Test-CadaDispara')
Comp 'Test-CadaDispara no toca $sw' ($tc -notmatch 'ElapsedMilliseconds') 'el cronometro nace con el proceso'
Comp 'y el disparo de Invoke-Reglas la llama a ella' ((SinComentarios (Traer 'Invoke-Reglas')) -match 'Test-CadaDispara')
Comp 'y ya no usa el cronometro para "cada"' ((SinComentarios (Traer 'Invoke-Reglas')) -notmatch "ultima = \[string\]\`$sw.ElapsedMilliseconds")
Comp 'el campo hasta se lee y se escribe' (((SinComentarios (Traer 'Get-Reglas')) -match 'hasta') -and ((SinComentarios (Traer 'Save-Reglas')) -match "'hasta'")) 'en los dos sitios o no sirve'

try { Remove-Item -LiteralPath $ReglasPath -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  lo que se repite, ya se repite de verdad'
exit 0
