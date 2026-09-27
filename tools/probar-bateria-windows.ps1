# LO QUE WINDOWS APUNTO DE LOS DIAS QUE NOVA NO ESTABA (27/09, idea 70 de las 121)
#
# EL DATO: Nova arranco 259 veces en 17 dias (13 + 246 lineas "VoiceAssistant iniciado") y su serie
# de bateria entera son 18 lineas de assistant-pulso.log. Windows guarda por su cuenta, dia a dia,
# cuanto estuvo la consola despierta con cargador y sin el, aunque Nova no estuviera viva.
#
# MEDIDO HOY en esta Ally: powercfg /batteryreport /xml tarda 248 ms y trae 13 entradas de historial
# y 18 de uso reciente. Del 15 al 26/09 la consola estuvo activa Y ENCHUFADA entre 23 h 13 m y
# 23 h 59 m CADA dia, y sin cargador 2 h 43 m en TOTAL en once dias (media 14,8 min/dia), con CUATRO
# dias a cero. Eso explica dos cosas que parecian fallos de Nova: el ritmo de bateria por juego no
# se aprende nunca (Update-BateriaJuego pide tramos de 10 min sin cargador) y el minimo de bateria
# que ha visto en 17 dias es el 90 %.
#
# LO QUE ESTE BANCO PROTEGE:
#   1. que la entrada IMPOSIBLE del informe (P24695DT4H10M53S, 24.695 dias) se TIRE y no se promedie
#   2. que una duracion ilegible no cuente como cero, que seria inventarse un dato
#   3. que si powercfg falla o no hay bateria, todo se quede como estaba
#   4. que el informe se pida UNA vez al dia y nunca desde el bucle
#   5. que Nova DIGA lo que el dato significa, en vez de esperar en silencio una serie que no llega
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
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
foreach ($f in @('ConvertTo-Segundos', 'Read-InformeBateria', 'Get-MinutosSinCargador', 'Update-BateriaWindows')) {
    Invoke-Expression (Traer $f)
}
$txt = [IO.File]::ReadAllText($PS1)
$script:logs = @()
function Log([string]$m) { $script:logs += @($m) }
$script:avisos = @()
function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60) {
    $script:avisos += @(@{ clave = $clave; texto = $texto; nivel = $nivel; cada = $cadaMin }); return $true
}
function Write-Atomico([string]$ruta, [string]$contenido) {
    [IO.File]::WriteAllText($ruta, $contenido, (New-Object Text.UTF8Encoding($false)))
}
$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-bat-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$MemoriaDir = $TmpDir
$BateriaWindowsJson = Join-Path $MemoriaDir 'bateria-windows.json'
$BateriaInformeTopeMs = 5000
$script:bateriaInformeDia = ''
Comp 'el tope del informe son 5000 ms' ($txt -match '\$BateriaInformeTopeMs = 5000') 'medido 248 ms'

try {
    Write-Host ''
    Write-Host '-- 1. LAS DURACIONES DE WINDOWS, PARSEADAS --'
    Comp '1a. PT23H40M38S son 85.238 s' ((ConvertTo-Segundos 'PT23H40M38S') -eq 85238) ([string](ConvertTo-Segundos 'PT23H40M38S'))
    Comp '1b. PT0S son 0' ((ConvertTo-Segundos 'PT0S') -eq 0) ''
    Comp '1c. PT45M55S son 2.755 s' ((ConvertTo-Segundos 'PT45M55S') -eq 2755) ([string](ConvertTo-Segundos 'PT45M55S'))
    # LO QUE IMPORTA: una duracion ilegible devuelve -1, NO 0. Un 0 contaria como "ese dia no solto
    # el cargador" y ensuciaria la media con un dato que en realidad no se sabe.
    Comp '1d. una basura da -1, no 0' ((ConvertTo-Segundos 'no soy una duracion') -eq -1) 'un 0 seria inventarse el dato'
    Comp '1e. y vacio tambien' ((ConvertTo-Segundos '') -eq -1) ''
    Comp '1f. la entrada imposible se parsea pero sale gigante' ((ConvertTo-Segundos 'P24695DT4H10M53S') -gt 90000) ([string](ConvertTo-Segundos 'P24695DT4H10M53S') + ' s')

    Write-Host ''
    Write-Host '-- 2. EL INFORME DE VERDAD, LEIDO AQUI --'
    $inf = Read-InformeBateria
    if (-not $inf) {
        Write-Host '  --   esta maquina no da informe de bateria; el resto del banco no depende de el'
    } else {
        Comp '2a. trae dias' (@($inf.dias).Count -gt 0) ([string]@($inf.dias).Count + ' dias validos')
        Comp '2b. y tramos de uso reciente' (@($inf.tramos).Count -gt 0) ([string]@($inf.tramos).Count + ' tramos')
        Comp '2c. tarda menos que el tope' ($inf.ms -lt $BateriaInformeTopeMs) ([string]$inf.ms + ' ms')
        # LA ENTRADA IMPOSIBLE: ningun dia puede traer mas de 24 h entre con y sin cargador
        $imposibles = @($inf.dias | Where-Object { ([int]$_.acMin + [int]$_.dcMin) -gt 1500 })
        Comp '2d. la entrada de 24.695 dias esta fuera' ($imposibles.Count -eq 0) 'promediar una basura es inventarse un numero'
        Comp '2e. cada dia trae su fecha en formato corto' (@($inf.dias | Where-Object { $_.fecha -match '^\d{4}-\d{2}-\d{2}$' }).Count -eq @($inf.dias).Count) ([string]@($inf.dias)[0].fecha)
        Comp '2f. y el XML no se queda por el suelo' (-not (Test-Path -LiteralPath (Join-Path $TmpDir 'bateria-windows.xml'))) ''
        $dcT = 0; $cero = 0
        foreach ($d in @($inf.dias)) { $dcT += [int]$d.dcMin; if ([int]$d.dcMin -le 0) { $cero++ } }
        Write-Host ('       media real: ' + [int]($dcT / @($inf.dias).Count) + ' min/dia sin cargador, ' + $cero + ' dias a cero, de ' + @($inf.dias).Count + ' dias')
    }

    Write-Host ''
    Write-Host '-- 3. UNA VEZ AL DIA, Y LO QUE DICE --'
    $script:logs = @(); $script:avisos = @()
    $r1 = Update-BateriaWindows
    $r2 = Update-BateriaWindows
    Comp '3a. la segunda llamada del dia no hace nada' (-not $r2) 'el informe cuesta 248 ms: no se pide dos veces'
    if ($r1) {
        Comp '3b. deja el resumen en disco' (Test-Path -LiteralPath $BateriaWindowsJson) ''
        Comp '3c. y lo cuenta en el registro' (@($script:logs | Where-Object { $_ -match 'min/dia sin cargador' }).Count -ge 1) (@($script:logs) -join ' | ')
        $m = Get-MinutosSinCargador
        Comp '3d. y se puede volver a leer despues' ($m -ge 0) ([string]$m + ' min/dia')
        # LA REGLA 2 DE LA CASA: si no va a poder aprender el gasto por juego, que lo DIGA
        if ($m -lt 10) {
            Comp '3e. con menos de 10 min/dia, avisa de que no podra aprender el gasto por juego' (@($script:avisos | Where-Object { $_.clave -eq 'bateria-nunca-suelta' }).Count -eq 1) ([string]@($script:avisos).Count + ' aviso(s)')
            Comp '3f. y en nivel bajo (se ve, no se dice)' (@($script:avisos)[0].nivel -eq 'bajo') 'no es para interrumpir'
        } else {
            Write-Host ('  --   esta maquina si se usa sin cargador (' + $m + ' min/dia): el aviso no toca')
        }
    }
    Write-Host ''
    Write-Host '-- 4. SIN INFORME, TODO COMO ESTABA --'
    Remove-Item -LiteralPath $BateriaWindowsJson -Force -ErrorAction SilentlyContinue
    Comp '4a. sin fichero, Get-MinutosSinCargador dice -1 (no lo se)' ((Get-MinutosSinCargador) -eq -1) 'y nadie decide nada con eso'
    [IO.File]::WriteAllText($BateriaWindowsJson, 'esto no es json')
    Comp '4b. con el fichero roto, tambien -1' ((Get-MinutosSinCargador) -eq -1) ''
    [IO.File]::WriteAllText($BateriaWindowsJson, '{"dias":0,"dcMinTotal":0}')
    Comp '4c. y con cero dias, -1 (no se divide por cero)' ((Get-MinutosSinCargador) -eq -1) ''

    Write-Host ''
    Write-Host '-- 5. EL CABLEADO --'
    Comp '5a. se llama en el cambio de dia, no en el bucle' ($txt -match 'Update-BateriaWindows\) \} catch \{ Log \(.bateria de Windows') ''
    Comp '5b. y la funcion se frena con la marca del dia' ((Traer 'Update-BateriaWindows') -match '\$script:bateriaInformeDia -eq \$hoyB') ''
    Comp '5c. las entradas absurdas se tiran por tamano, no por posicion' ((Traer 'Read-InformeBateria') -match '-gt 90000') 'la fila resumen puede cambiar de sitio'
    Comp '5d. el informe se pide a un XML de tmp, no a la carpeta de memoria' ((Traer 'Read-InformeBateria') -match 'Join-Path \$TmpDir') ''

    Write-Host ''
    Write-Host '-- 6. LA RAMA DEL AVISO, CON DATOS INYECTADOS --'
    # En esta consola la media son 14 min/dia, asi que la rama que avisa no se ejercita sola y
    # quedaria sin probar (una prueba que no se ejecuta es una de las maneras de salir verde
    # mintiendo). El doble va DESPUES de cargar la funcion de verdad, para que no la pise el AST.
    function Read-InformeBateria {
        $d = New-Object System.Collections.ArrayList
        # ocho dias enchufado del todo y tres con un rato suelto: media por debajo de 10
        for ($i = 1; $i -le 8; $i++) { [void]$d.Add(@{ fecha = ('2026-09-0' + $i); acMin = 1430; dcMin = 0 }) }
        $k = 9
        foreach ($m in @(12, 20, 25)) { $k++; [void]$d.Add(@{ fecha = ('2026-09-' + $k); acMin = 1400; dcMin = $m }) }
        return @{ ms = 200; dias = @($d); tramos = @() }
    }
    $script:bateriaInformeDia = ''
    $script:logs = @(); $script:avisos = @()
    $r6 = Update-BateriaWindows
    $m6 = Get-MinutosSinCargador
    Comp '6a. con 11 dias y media por debajo de 10, avisa' (@($script:avisos | Where-Object { $_.clave -eq 'bateria-nunca-suelta' }).Count -eq 1) ([string]$m6 + ' min/dia de media')
    Comp '6b. en nivel bajo: se ve, no se dice' (@($script:avisos)[0].nivel -eq 'bajo') 'no es para interrumpir una partida'
    Comp '6c. con plazo de una semana' (@($script:avisos)[0].cada -eq 10080) 'el dato no cambia de un dia para otro'
    Comp '6d. y la frase lleva el numero medido' (@($script:avisos)[0].texto -match [string]$m6) (@($script:avisos)[0].texto)
    Comp '6e. y lo explica en el registro' (@($script:logs | Where-Object { $_ -match 'no puedo aprender lo que gasta cada juego' }).Count -eq 1) ''
    # y con POCOS dias no se afirma nada: el informe recien estrenado trae uno o dos
    function Read-InformeBateria { return @{ ms = 200; dias = @(@{ fecha = '2026-09-01'; acMin = 1430; dcMin = 0 }); tramos = @() } }
    $script:bateriaInformeDia = ''
    $script:logs = @(); $script:avisos = @()
    $null = Update-BateriaWindows
    Comp '6f. con un solo dia de datos, NO avisa' (@($script:avisos).Count -eq 0) 'hacen falta 7 dias para decir algo'
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova lee lo que Windows apunto de los dias que ella no estaba' -ForegroundColor Green
exit 0
