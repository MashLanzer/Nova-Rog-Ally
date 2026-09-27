$ErrorActionPreference = 'Continue'
# LOS 470 ERRORES QUE NOVA SE TRAGA (27/09, idea 80 de las 121)
#
# EL DATO: 470 de los 897 catch de assistant.ps1 estan COMPLETAMENTE VACIOS -el 52,4 %-: cuando algo
# revienta, se lo traga y sigue, y no habia ni un dato de cuales disparan de verdad. Solo 171 escriben
# algo en el registro. Y no hace falta tocar ninguno para enterarse: PowerShell mete TODA excepcion
# capturada en la variable automatica $Error con su numero de linea, y no aparecia NI UNA vez en las
# 31.000 lineas del script.
#
# Y DE LOS 470, UNO YA SE SABIA QUE MUERDE: la lectura de corte.flag era un ReadAllText crudo dentro
# de un catch vacio, y ese fichero lo escribe el worker con la misma escribir() que ha fallado 36
# veces con "Acceso denegado". Si fallaba, la palabra quedaba VACIA y Resolve-Corte la resolvia como
# 'corta-y-calla' (en pausa) o 'tarde' (en sordina): decir "nova" para volver de la sordina se
# convertia en callarla, en silencio.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que se lean los errores NUEVOS y no se cuenten dos veces
#   2. que el tope de 256 de $Error no deje de contar
#   3. que una sola vez no sea noticia
#   4. que la lectura de corte.flag use FileShare::Delete y, si falla, NO decida nada
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('Watch-ErroresTragados', 'Get-PeorPete', 'Resolve-Corte', 'ConvertTo-Plain')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)
$PetesPorVez = 60
Comp 'se leen 60 por pasada como mucho' ($txt -match '\$PetesPorVez = 60') 'esto corre en el bucle'

function Reset {
    $script:erroresVistos = 0
    $script:petePeor = $null
    $script:peteTabla = @{}
    $Error.Clear()
}

Write-Host ''
Write-Host '-- 1. LOS ERRORES QUE SE TRAGA UN catch VACIO SI ESTAN EN $Error --'
Reset
# tres excepciones tragadas, como las que se traga Nova
try { 1 / 0 } catch { }
try { [int]'no soy un numero' } catch { }
try { Get-Item 'C:\esto-no-existe-de-verdad-12345' -ErrorAction Stop } catch { }
Comp '1a. los tres estan en $Error' (@($Error).Count -ge 3) ([string]@($Error).Count + ' capturados')
$n1 = Watch-ErroresTragados
Comp '1b. y se leen' ($n1 -ge 3) ([string]$n1 + ' leidos')
Comp '1c. agrupados por linea' ($script:peteTabla.Count -ge 1) ([string]$script:peteTabla.Count + ' lineas distintas')

Write-Host ''
Write-Host '-- 2. NO SE CUENTAN DOS VECES --'
$n2 = Watch-ErroresTragados
Comp '2a. una segunda pasada sin errores nuevos no lee nada' ($n2 -eq 0) ([string]$n2)
try { 1 / 0 } catch { }
$n3 = Watch-ErroresTragados
Comp '2b. y uno nuevo si' ($n3 -eq 1) ([string]$n3)

Write-Host ''
Write-Host '-- 3. UNA VEZ NO ES NOTICIA --'
Reset
try { 1 / 0 } catch { }
$null = Watch-ErroresTragados
Comp '3a. con una vez, no hay peor' ($null -eq (Get-PeorPete)) 'un pete suelto no dice nada'
# el mismo sitio dos veces: eso ya es un patron
$script:peteTabla = @{ 27119 = 2 }
$script:petePeor = @{ linea = 27119; veces = 2; que = 'Acceso denegado' }
$p3 = Get-PeorPete
Comp '3b. con dos, si' ($null -ne $p3 -and $p3.veces -eq 2) ([string]$p3.veces + ' veces en la linea ' + [string]$p3.linea)

Write-Host ''
Write-Host '-- 4. EL TOPE DE 256 NO PARA LA CUENTA --'
Reset
# se simula la lista topada: $Error.Count no crece pero siguen entrando errores
$script:erroresVistos = 256
$Error.Clear()
for ($i = 0; $i -lt 300; $i++) { try { 1 / 0 } catch { } }
Comp '4a. $Error se topa en 256' (@($Error).Count -le 256) ([string]@($Error).Count)
$n4 = Watch-ErroresTragados
Comp '4b. y aun asi se leen' ($n4 -gt 0) ([string]$n4 + ' leidos con la lista llena')
Comp '4c. sin pasarse del tope por pasada' ($n4 -le $PetesPorVez) ([string]$n4 + ' <= ' + [string]$PetesPorVez)

Write-Host ''
Write-Host '-- 5. LO QUE SE ARREGLA HOY: corte.flag --'
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '5a. la lectura usa FileShare::Delete' ($sinCom -match '(?s)rutaCorte.{0,400}FileShare\]::Delete') 'la unica forma de leer mientras el worker hace su os.replace'
Comp '5b. y ya no es un ReadAllText crudo' (-not ($sinCom -match 'ReadAllText\(\$rutaCorte\)')) ''
Comp '5c. si falla, se DICE' ($sinCom -match 'corte: no pude leer lo que dijiste') 'antes se lo tragaba un catch vacio'
Comp '5d. y se apunta para poder contarlo' ($sinCom -match "Add-Estadistica 'corte-ilegible'") ''
Comp '5e. y NO se decide nada' ($sinCom -match "if \(-not \`$corteLeido\) \{") 'una palabra que no se pudo leer no es una palabra vacia'

Write-Host ''
Write-Host '-- 6. Y POR QUE ESO IMPORTABA: lo que hacia Resolve-Corte con la palabra vacia --'
# EL FALLO, tal cual: con sordina puesta, una palabra vacia no se parece al nombre
$dSordina = Resolve-Corte '' 'nova' $false $false $true
Comp '6a. en sordina, la palabra vacia daba "tarde"' ($dSordina.accion -eq 'tarde') 'o sea: decir "nova" para volver no volvia'
$dNombre = Resolve-Corte 'nova' 'nova' $false $false $true
Comp '6b. con el nombre leido de verdad, vuelve' ($dNombre.accion -eq 'sordina-vuelve') 'esto es lo que se perdia'
$dPausa = Resolve-Corte '' 'nova' $false $true $false
Comp '6c. y en pausa, la vacia la CALLABA' ($dPausa.accion -eq 'corta-y-calla') 'un fallo de lectura se volvia callarla'

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
Comp '7a. se lee una vez por minuto, no en cada vuelta' ($sinCom -match '\$petes = Watch-ErroresTragados') ''
Comp '7b. y se cuenta como pete:<linea>' ($sinCom -match "Add-Estadistica \('pete:' \+ \`$peor\.linea\)") ''
Comp '7c. el parte lo dice' ($sinCom -match 'Por dentro se me rompio algo') ''
# SIN COMENTARIOS, que es la 17a manera de salir verde mintiendo aplicada al reves: el comentario de
# la propia funcion dice "NO usa Log para cada uno" y la palabra Log dentro de el ponia esto en rojo.
$cuerpoW = ((Traer 'Watch-ErroresTragados') -split "`n" | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7d. el lector no escribe una linea por error' (-not ($cuerpoW -match 'Log ')) 'serian cientos de lineas'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'los errores tragados se cuentan, y el que callaba a Nova esta arreglado' -ForegroundColor Green
exit 0
