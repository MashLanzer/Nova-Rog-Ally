# NOVA ESCRIBE SUS PROPIOS FALLOS EN EL REGISTRO Y NO LOS LEE NUNCA (26/09, idea 40 de las 121).
#
# El 25/09 a las 21:33 el bucle del oido fallo TRES veces seguidas con el mismo texto ("name
# 'callado' is not defined"); las tres rehizo el reconocedor y lo que llego un segundo despues
# fue "8 s sin oir nada". Braya la habia llamado cuatro veces y la orden se perdio ENTERA y en
# silencio. Esos fallos quedaban escritos en assistant.log y no los leia nadie.
#
# Ahora el worker cuenta el mismo fallo repetido (el mismo "_mismo" de la idea 5, sin umbral
# nuevo), lo publica en escucha-estado.txt, y el asistente lo APUNTA en el diario cuando va >= 2.
# Y de paso: la idea 5 habia dejado su canal PERDIDO muerto -escribia en RUTA_DICTADO, que no
# existe- dentro de un except mudo; aqui se resucita (escribir(TEXTO, "PERDIDO")).
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PS 5.1 con -File sale con codigo 0 aunque muera a mitad.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$rutaP = Join-Path $raiz 'wake_vosk.py'
$aTxt = [IO.File]::ReadAllText($rutaA, [Text.Encoding]::UTF8)
$pTxt = [IO.File]::ReadAllText($rutaP, [Text.Encoding]::UTF8)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
function EnOrden([string]$t, [string]$a, [string]$b) {
    $ma = [regex]::Match($t, $a); if (-not $ma.Success) { return $false }
    return [regex]::Match($t.Substring($ma.Index + $ma.Length), $b).Success
}
$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}
$pSin = (($pTxt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '  -- 1. el canal escribe en un nombre que EXISTE --'
# TODOS los nombres en MAYUSCULAS dentro de escribir( tienen que estar definidos. Esto es lo que
# caza el bug de hoy: escribir(RUTA_DICTADO, ...) con RUTA_DICTADO sin definir daba NameError.
$nombres = @([regex]::Matches($pSin, 'escribir\(([A-Z_][A-Z0-9_]*)\s*,')) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$sinDef = @()
foreach ($nom in $nombres) {
    $def = ($pSin -match ("(?m)^" + [regex]::Escape($nom) + " = ")) -or ($pSin -match ([regex]::Escape($nom) + " = sys\.argv"))
    if (-not $def) { $sinDef += $nom }
}
Comp 'todo nombre en escribir(...) esta definido' ($sinDef.Count -eq 0) $(if ($sinDef.Count) { "SIN DEFINIR: " + ($sinDef -join ', ') } else { ($nombres -join ', ') })
Comp '  y el turno perdido va al fichero del dictado (TEXTO)' ($pSin -match 'escribir\(TEXTO, "PERDIDO"\)') 'no a RUTA_DICTADO, que no existe'

Write-Host ''
Write-Host '  -- 2. el fallo al marcarlo no se traga --'
Comp 'el except de esa escritura llama a anota()' (EnOrden $pSin 'escribir\(TEXTO, "PERDIDO"\)' 'anota\("no pude marcar el turno como perdido') 'antes era except: pass'

Write-Host ''
Write-Host '  -- 3. el contador cuenta por MENSAJE, no por linea --'
Comp 'suma dentro de la rama del mismo fallo' (EnOrden $pSin 'if _mismo:' '_fallo_bucle\[1\] \+= 1') ''
Comp '  y se reinicia a 1 con un fallo nuevo' ($pSin -match '_fallo_bucle\[1\] = 1') 'dos json rotos distintos no suman'

Write-Host ''
Write-Host '  -- 4. no se inventa umbral nuevo (regla 3) --'
Comp 'el campo sale de _fallo_bucle[1] >= 2' ($pSin -match '_fallo_bucle\[1\] >= 2') 'el mismo caso que ya dispara PERDIDO'
Comp '  y no hay ninguna constante FALLO_AVISO_* / FALLO_MINIMO nueva' (-not ($pSin -match '(?m)^FALLO_(?:AVISO|MINIMO|MIN)')) 'ningun numero inventado'

Write-Host ''
Write-Host '  -- 5. el campo va AL FINAL y sin barras --'
Comp 'el prefijo de decir_estado llega hasta el undecimo campo' ($pSin -match '\|%d\|%d\|%s" %') 'el nuevo %s va detras de los diez de antes'
Comp '  repaso_perdido sigue delante del nuevo' (EnOrden $pSin 'repaso_perdido or "-"' 'ram_justa_pct\(\), fallo_b') ''
Comp '  y se le quitan las barras al texto' ($pSin -match '_fallo_bucle\[0\]\[:60\]\.replace\("\|", " "\)') 'el separador es | y una excepcion puede traerlo'

Write-Host ''
Write-Host '  -- 6. el asistente lo lee con las cuatro guardas de siempre --'
$gFB = Traer 'Get-FalloBucle'
Comp 'Get-FalloBucle mira Test-Path' ($gFB -match 'Test-Path -LiteralPath \$RutaEstado') ''
Comp '  y Test-EstadoFresco' ($gFB -match 'Test-EstadoFresco') 'con el estado rancio avisaria del worker anterior'
Comp '  y exige el campo 11 (Count -lt 11)' ($gFB -match '\$st\.Count -lt 11') ''
Comp '  y trata el guion como nada' ($gFB -match "-eq '-'") ''

Write-Host ''
Write-Host '  -- 7. parte por el PRIMER dos puntos (un mensaje de Python trae varios) --'
Comp 'Get-FalloBucle usa IndexOf(:), no -split' (($gFB -match "\.IndexOf\(':'\)") -and ($gFB -notmatch "-split ':'")) '"KeyError: x" cortaria mal con -split'

Write-Host ''
Write-Host '  -- 8. no avisa con una sola vez, ni sin texto, ni ya avisado --'
Invoke-Expression (Traer 'Test-AvisarFalloBucle')
Comp 'con una sola vez, NO' (-not (Test-AvisarFalloBucle 1 'x' $false)) ''
Comp 'con dos, SI' (Test-AvisarFalloBucle 2 'x' $false) ''
Comp 'sin texto, NO (el diario no apunta algo vacio)' (-not (Test-AvisarFalloBucle 2 '' $false)) ''
Comp 'ya avisado, NO' (-not (Test-AvisarFalloBucle 2 'x' $true)) ''

Write-Host ''
Write-Host '  -- 9, 10 y 11. la bandera, sin doble voz, y escrito para manana --'
$aSin = (($aTxt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
# el bloque entero del aviso, acotado por su try/catch (no [\s\S]{0,N}): del inicio del try a su
# cierre, para que entren tanto el 'if (Send-AvisoEntorno' como la bandera de dentro
$iBl = $aSin.IndexOf('$fb = Get-FalloBucle')
$iFinBl = if ($iBl -ge 0) { $aSin.IndexOf('} catch {}', $iBl) } else { -1 }
$bl = if ($iBl -ge 0 -and $iFinBl -gt $iBl) { $aSin.Substring($iBl, $iFinBl - $iBl) } else { '' }
Comp '9. la bandera solo se marca si el aviso SALIO' (EnOrden $bl 'if \(Send-AvisoEntorno' 'falloBucleAvisado = \$true') 'jugando el medio se calla y se reintenta al cerrar'
# Get-NivelAviso y Get-ReaccionesAviso entran desde el 1/10/2026 (idea 9 de las 20 nuevas):
# Send-AvisoEntorno decide el nivel en su PRIMERA linea, asi que sin ellas este banco revienta con un
# CommandNotFoundException y todo sale a cero. Se traen de verdad y no dobladas: doblar justo la pieza
# que decide el nivel seria la manera 15 de los bancos que mienten.
$AvisoReaccionMin = 8; $AvisoReaccionCeroMin = 5; $AvisoMudoCeros = 8; $AvisoEsperaTope = 6
Invoke-Expression (Traer 'Get-ReaccionesAviso')
Invoke-Expression (Traer 'Get-NivelAviso')
Comp '10. el bloque no habla dos veces del mismo turno' (($bl -notmatch 'Say ') -and ((@([regex]::Matches($bl, 'Send-AvisoEntorno')).Count) -eq 1)) 'el turno ya se contesta por PERDIDO'
Comp '   y la rama PERDIDO sigue con su aviso oido-roto' ($aSin -match "'oido-roto'") 'no se toca'
Comp '11. queda escrito para la tanda siguiente (Add-Memoria)' ($bl -match 'Add-Memoria') 'sin esto solo se habla y se olvida'
Comp '   y el aviso va por Send-AvisoEntorno (aparcado, tope por hora, silencio jugando)' ($bl -match "Send-AvisoEntorno 'oido-fallo-bucle'") ''
Comp '   con clave PROPIA, no fallo-racha (que taparia la de la idea 29)' ($bl -notmatch "'fallo-racha'") ''

Write-Host ''
Write-Host '  -- 12. contra el registro de verdad --'
$logs = @()
foreach ($lf in @('assistant.log', 'assistant.log.1')) {
    $ruta = Join-Path $raiz $lf
    if (Test-Path -LiteralPath $ruta) { $logs += @(Get-Content -LiteralPath $ruta -ErrorAction SilentlyContinue | Where-Object { $_ -match 'fallo en una vuelta del bucle' }) }
}
Write-Host ("       lineas 'fallo en una vuelta del bucle' en el registro: " + $logs.Count)
# no es un fallo del codigo si el registro se rota; el banco lo DICE, no se cae
if ($logs.Count -eq 0) { Write-Host '       (ninguna hoy: el unico caso conocido lo arreglo la idea 5)' }

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'el oido apunta sus propios fallos' -ForegroundColor Green
exit 0
