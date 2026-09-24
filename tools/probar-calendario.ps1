# "REVISA MI CALENDARIO Y DIME SI TENGO ALGO ANOTADO PARA MANANA" (23/09, idea 5).
#
# NO se hace un calendario nuevo. El alias ya existe -se escribio el 18/09 porque braya lo
# pidio tres veces y acabo en el agente (23 s) o en la charla- y contesta bien. Lo que falla
# es su COBERTURA: Nova apunta cosas con fecha en TRES sitios y el alias miraba uno.
#
# EL FALLO, con los datos que hay hoy en el disco: fechas.json tiene una entrada de verdad
# (el cumple de Ana, 09-15) y el alias no la mira nunca, asi que la vispera de un cumple
# "dime si tengo algo anotado para manana" contesta "No tienes nada apuntado para manana"
# TENIENDO el cumple guardado. Nova miente con datos que ella misma guardo, en silencio y con
# una frase que suena perfectamente correcta: el peor fallo que puede tener una agenda.
# Y como recordatorios.json esta hoy en [] y reglas.json ni existe, ese es el caso NORMAL.
#
# Un calendario de verdad -fichero nuevo, gramatica de alta, gramatica de baja- seria un
# CUARTO sitio con cosas con fecha al lado de los otros tres, que es la leccion que ya esta
# escrita en el codigo: dos listas distintas acaban separandose.
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

# --- el andamio: los tres ficheros en un temporal. NUNCA se toca memoria\ ----
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('cal-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $tmp -Force
$RecordatoriosPath = Join-Path $tmp 'recordatorios.json'
$FechasPath = Join-Path $tmp 'fechas.json'
$ReglasPath = Join-Path $tmp 'reglas.json'
$script:reglas = $null
$script:invitado = $false
function Log([string]$m) { }
function Add-Estadistica($a, $b) { }
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$ruta, [string]$txt) { [System.IO.File]::WriteAllText($ruta, $txt, (New-Object System.Text.UTF8Encoding($false))) }
function Send-UIEvento($e) { }
function Say([string]$t, [string]$e = '') { }
function Test-FastCommand([string]$t) { return $true }
function Get-Veces([string]$t) { return 1 }
$DIAS_SEMANA = @{ 'lunes' = 1; 'martes' = 2; 'miercoles' = 3; 'jueves' = 4; 'viernes' = 5; 'sabado' = 6; 'domingo' = 0 }
foreach ($v in @('MESES', 'FILLER_INI', 'FILLER_FIN', 'FILLER_GLOBAL', 'NumerosPalabra')) {
    # una linea, o un @{ que sigue abajo hasta un } solo en su linea
    $m = [regex]::Match($fuente, '(?m)^\$' + $v + ' = (.+)$')
    if (-not $m.Success) { Write-Host "  MAL  no encuentro $v"; exit 1 }
    $val = $m.Groups[1].Value
    if ($val.Trim() -eq '@{') {
        $m2 = [regex]::Match($fuente, '(?ms)^\$' + $v + ' = (@\{.*?^\})')
        if (-not $m2.Success) { Write-Host "  MAL  no se donde acaba $v"; exit 1 }
        $val = $m2.Groups[1].Value
    }
    Invoke-Expression ('$' + $v + ' = ' + $val)
}
foreach ($f in @('ConvertTo-Plain', 'ConvertTo-Suave', 'ConvertTo-Digitos', 'Get-Reglas', 'Get-Fechas',
                 'Get-Recordatorios', 'Save-Recordatorios', 'Get-AgendaDe', 'Remove-RecordatorioTexto',
                 'Invoke-RecordatorioVoz', 'Remove-Filler', 'Describe-Regla')) {
    Invoke-Expression (Traer $f)
}

$hoy = (Get-Date).Date
function PonRecordatorios($lista) { Save-Recordatorios @($lista) }
function PonFechas($lista) {
    $json = if (@($lista).Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 3 }
    Write-Atomico $FechasPath $json
}
function PonReglas($lista) {
    $json = if (@($lista).Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($lista) -Depth 4 }
    Write-Atomico $ReglasPath $json
    $script:reglas = $null
}
function Vacia { PonRecordatorios @(); PonFechas @(); PonReglas @() }

Write-Host ''
Write-Host '-- 1. lo que ya funcionaba sigue funcionando --'
Vacia
$r0 = Invoke-RecordatorioVoz 'revisa mi calendario y dime si tengo algo anotado para manana'
Comp 'la frase entra por el alias, no se va a nadie' ($null -ne $r0) "$r0"
Comp 'y sin nada apuntado lo dice, y ensena a crear uno' ($r0 -match 'No tienes nada apuntado para manana' -and $r0 -match 'recuerdame manana') "$r0"

Write-Host ''
Write-Host '-- 2. LA MENTIRA: el cumple que ella misma guardo --'
# Con el codigo de antes esto contestaba "No tienes nada apuntado para manana".
Vacia
PonFechas @(@{ md = $hoy.AddDays(1).ToString('MM-dd'); texto = 'el cumple de Ana' })
$r1 = Invoke-RecordatorioVoz 'dime si tengo algo anotado para manana'
Comp 'ya NO dice que no hay nada' ($r1 -notmatch 'No tienes nada apuntado') "$r1"
Comp 'y nombra el cumple' ($r1 -match 'cumple de Ana') "$r1"
Comp 'y lo lee SIN hora (un cumple no tiene hora)' ($r1 -notmatch 'a las') "$r1"

Write-Host ''
Write-Host '-- 3. las tres fuentes juntas y en orden --'
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(1).AddHours(17).ToString('s'); texto = 'llamar al medico' })
PonFechas @(@{ md = $hoy.AddDays(1).ToString('MM-dd'); texto = 'el cumple de Ana' })
PonReglas @(@{ id = 1; tipo = 'hora'; valor = '08:00'; accion = 'di tomate la pastilla'; ultima = ''; cond = ''; hasta = '' },
            @{ id = 2; tipo = 'hora'; valor = '23:00'; accion = 'pon modo noche'; ultima = ''; cond = ''; hasta = '' })
$ag = Get-AgendaDe $hoy.AddDays(1) $hoy.AddDays(1)
Comp 'salen las tres cosas, no las cuatro' ($ag.Count -eq 3) "$($ag.Count)"
Comp 'un modo nocturno NO es una cita' (@($ag | Where-Object { $_.texto -match 'modo noche' }).Count -eq 0)
Comp 'pero la pastilla si, y sin el "di"' (@($ag | Where-Object { $_.texto -eq 'tomate la pastilla' }).Count -eq 1) "$(($ag | ForEach-Object { $_.texto }) -join ' | ')"
Comp 'y van en orden de hora' ($ag[0].texto -eq 'tomate la pastilla' -and $ag[2].texto -eq 'llamar al medico') "$(($ag | ForEach-Object { $_.texto }) -join ' -> ')"
$r2 = Invoke-RecordatorioVoz 'que tengo apuntado para manana'
Comp 'y la frase las nombra las tres' (($r2 -match 'medico') -and ($r2 -match 'Ana') -and ($r2 -match 'pastilla')) "$r2"

Write-Host ''
Write-Host '-- 4. el rango: semana, fin de semana y dia de la semana --'
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(3).AddHours(12).ToString('s'); texto = 'dentista' },
                   @{ cuando = $hoy.AddDays(10).AddHours(12).ToString('s'); texto = 'revision del coche' })
$sem = Get-AgendaDe $hoy $hoy.AddDays(6)
Comp '"esta semana" coge el de dentro de tres dias' (@($sem | Where-Object { $_.texto -eq 'dentista' }).Count -eq 1)
Comp 'y NO el de dentro de diez' (@($sem | Where-Object { $_.texto -match 'coche' }).Count -eq 0) "$($sem.Count) cosas"
$r3 = Invoke-RecordatorioVoz 'que tengo esta semana en la agenda'
Comp 'la frase de la semana entra y lo dice' ($r3 -match 'dentista' -and $r3 -notmatch 'coche') "$r3"
# "el fin de semana" lleva 'semana' dentro: si el orden fuera al reves, se lo comeria
$r4 = Invoke-RecordatorioVoz 'que tengo en la agenda este fin de semana'
Comp '"este fin de semana" no lo pisa "semana"' ($r4 -match 'fin de semana') "$r4"
# "EL VIERNES" DICHO UN VIERNES ES EL QUE VIENE, igual que al crear un recordatorio. Se
# pregunta por el dia de HOY a proposito: es el unico caso que se porta igual los siete dias
# de la semana, asi que el banco no depende de cuando se ejecute. Hay DOS citas, una hoy y
# otra dentro de siete dias, y solo puede salir la de dentro de siete.
$nomDia = @('domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado')[[int]$hoy.DayOfWeek]
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddHours(19).ToString('s'); texto = 'la de hoy' },
                   @{ cuando = $hoy.AddDays(7).AddHours(19).ToString('s'); texto = 'partida con los amigos' })
$r5 = Invoke-RecordatorioVoz "que tengo el $nomDia en la agenda"
Comp "'el $nomDia' dicho hoy es el de la semana que viene" ($r5 -match 'partida con los amigos') "$r5"
Comp 'y NO la de hoy' ($r5 -notmatch 'la de hoy') "$r5"
# EL FIN DE 'LA' SEMANA: esta SI lleva 'la semana' dentro, asi que si la rama de la semana
# fuera primero se la comeria y contestaria por siete dias en vez de por el sabado.
Vacia
$aSabB = (6 - [int]$hoy.DayOfWeek + 7) % 7
PonRecordatorios @(@{ cuando = $hoy.AddDays($aSabB).AddHours(12).ToString('s'); texto = 'comida del sabado' })
$r5b = Invoke-RecordatorioVoz 'que tengo el fin de la semana en la agenda'
Comp '"el fin de la semana" es el finde, no siete dias' ($r5b -match 'para el fin de semana') "$r5b"

Write-Host ''
Write-Host '-- 5. BORRAR UNA CITA: con dos candidatas no se borra NINGUNA --'
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(1).AddHours(10).ToString('s'); texto = 'cita con el medico' },
                   @{ cuando = $hoy.AddDays(2).AddHours(10).ToString('s'); texto = 'llamar al medico de cabecera' },
                   @{ cuando = $hoy.AddDays(3).AddHours(10).ToString('s'); texto = 'sacar la basura' })
$r6 = Invoke-RecordatorioVoz 'borra el recordatorio del medico'
Comp 'con dos que encajan, no borra nada' (@(Get-Recordatorios).Count -eq 3) "$r6"
Comp 'y las lee numeradas para elegir' ($r6 -match '1, cita con el medico' -and $r6 -match '2, llamar al medico') "$r6"
$r7 = Invoke-RecordatorioVoz 'borra el recordatorio uno'
Comp 'y por numero si borra, el que toca' (@(Get-Recordatorios).Count -eq 2 -and @(@(Get-Recordatorios) | Where-Object { $_.texto -match 'cita con el medico' }).Count -eq 0) "$r7"

Write-Host ''
Write-Host '-- 6. con una sola, borra; con ninguna, lo dice --'
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(1).AddHours(10).ToString('s'); texto = 'cita con el dentista' },
                   @{ cuando = $hoy.AddDays(2).AddHours(10).ToString('s'); texto = 'sacar la basura' })
$r8 = Invoke-RecordatorioVoz 'borra el recordatorio del dentista'
Comp 'con una sola, la quita' (@(Get-Recordatorios).Count -eq 1) "$r8"
Comp 'y deja la otra con su texto intacto' (@(Get-Recordatorios)[0].texto -eq 'sacar la basura') "$(@(Get-Recordatorios)[0].texto)"
$r9 = Invoke-RecordatorioVoz 'borra el recordatorio del veterinario'
Comp 'con ninguna, no toca el fichero' (@(Get-Recordatorios).Count -eq 1) "$r9"
Comp 'y lo dice' ($r9 -match 'No tengo nada apuntado de eso') "$r9"
# UN TROZO MAL OIDO NO BORRA NADA (regla 7): 'la' esta dentro de "sacar LA basura", y con el
# oido al 70,4 % eso es justo lo que llega cuando se pierde media frase.
$r9b = Invoke-RecordatorioVoz 'borra el recordatorio de la'
Comp 'un trozo de dos letras no borra nada' (@(Get-Recordatorios).Count -eq 1) "$r9b"

Write-Host ''
Write-Host '-- 7. y lo que NO puede tragarse --'
$reBorra = [regex]::Match($fuente, "(?m)^\s*if \(\`$p -match '(\^\(\?!.+?\)\(\?:borra\|elimina\|quita\|olvida\|cancela\).+?)'\) \{").Groups[1].Value
if (-not $reBorra) { Write-Host '  MAL  no encuentro el patron de borrar una cita'; exit 1 }
Comp '"borra la carpeta descargas" no entra' ('borra la carpeta descargas' -notmatch $reBorra) 'eso si es destructivo de verdad'
Comp '"borra todos los recordatorios" tampoco' ('borra todos los recordatorios' -notmatch $reBorra) 'ese va delante y es mas especifico'
Comp '"borra todo" tampoco' ('borra todo' -notmatch $reBorra)
Comp 'pero "borra la cita del martes" si' ('borra la cita del martes' -match $reBorra)
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(1).AddHours(10).ToString('s'); texto = 'cita con el dentista' })
$r10 = Invoke-RecordatorioVoz 'borra todos los recordatorios'
Comp 'y "borra todos" sigue vaciandolo entero' (@(Get-Recordatorios).Count -eq 0) "$r10"

Write-Host ''
Write-Host '-- 8. el fichero sigue teniendo dos campos, y ni un fantasma --'
# El fantasma de {"value":[],"Count":0} que ya esta documentado en Get-Recordatorios.
Vacia
PonRecordatorios @(@{ cuando = $hoy.AddDays(1).AddHours(10).ToString('s'); texto = 'cita con el dentista' })
$crudo = Get-Content -LiteralPath $RecordatoriosPath -Raw -Encoding UTF8 | ConvertFrom-Json
$campos = @(($crudo | Select-Object -First 1).PSObject.Properties.Name | Sort-Object)
Comp 'dos campos: cuando y texto' (($campos -join ',') -eq 'cuando,texto') "$($campos -join ',')"
Save-Recordatorios @()
$crudo2 = Get-Content -LiteralPath $RecordatoriosPath -Raw -Encoding UTF8
Comp 'y vacio se escribe como [] pelado' ($crudo2.Trim() -eq '[]') "$($crudo2.Trim())"
Comp 'sin ningun fantasma dentro' (@(Get-Recordatorios).Count -eq 0)

Write-Host ''
Write-Host '-- 9. no se ha creado ningun fichero nuevo --'
$ga = SinComentarios (Traer 'Get-AgendaDe')
Comp 'la agenda sale de las tres que ya habia' (($ga -match 'Get-Recordatorios') -and ($ga -match 'Get-Fechas') -and ($ga -match 'Get-Reglas'))
Comp 'y no abre ningun fichero por su cuenta' ($ga -notmatch 'Get-Content|Write-Atomico|Test-Path') 'cero formato nuevo, cero migracion'
Comp 'ni sale a la red' ($ga -notmatch 'Invoke-WebRequest|Invoke-RestMethod') 'un calendario sin nube era la idea'

try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  la agenda mira ya los tres sitios'
exit 0
