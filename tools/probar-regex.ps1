# Comprueba que TODOS los patrones del asistente compilan como expresion regular.
#
# Por que existe: el 11/09 se colo '(?i)steamapps\common\([^\]+)' con barras
# simples. .NET ni siquiera podia compilarlo ("conjunto [] sin terminar"), pero
# la llamada estaba dentro de un try/catch por proceso, asi que la deteccion de
# juegos colgados devolvia lista vacia SIEMPRE y en silencio. Un regex roto no
# da la cara: se limita a no encontrar nunca nada.
#
#   powershell -File tools\probar-regex.ps1
param([string[]]$Archivos = @('assistant.ps1'))
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

$operadores = @('-match', '-notmatch', '-imatch', '-cmatch', '-split', '-replace', '-ireplace', '-creplace')
$fallos = 0
$vistos = 0
$vistosPorArchivo = @{}
$vistosSwitchPorArchivo = @{}

# EL LISTON MINIMO. Una prueba que no ve nada no puede suspender: el 18/09
# (REVISION-2026-09-18.md:207) se comprobo que este script sale VERDE con
# $vistos = 0, que es justo el accidente que el comentario de
# probar-todo.ps1:18-20 dice haber sufrido ya en otra prueba ("midio 0 casos y
# dijo OK igual"). Se habia escrito la leccion pero no se habia puesto el liston.
#
# DE DONDE SALEN LOS NUMEROS (contados el 19/09/2026 ejecutando este mismo
# script sobre assistant.ps1): 400 patrones = 341 de operadores (-match,
# -replace, -split...) + 59 casos literales de "switch -regex". En los commits
# de estos dias el contador SOLO HA SUBIDO -185 (12/09), 245 (13/09),
# 373 (17/09), 385 (18/09), 400 (19/09); los casos de switch,
# 45 / 46 / 55 / 59 / 59-, nunca ha bajado. Por eso el liston se pone por
# debajo (360 y 45) para que editar no de rojos falsos, pero muy por encima de
# cero: perder 40 patrones de golpe, o que el bloque del switch baje de 45, no
# es que se hayan borrado ordenes, es que esta prueba ha dejado de mirar.
# Si algun dia baja de verdad y a proposito, se vuelve a contar y se sube aqui.
$MINIMOS = @{ 'assistant.ps1' = 360 }
$MINIMOS_SWITCH = @{ 'assistant.ps1' = 45 }

function Apunta($tabla, $clave) {
    if ($tabla.ContainsKey($clave)) { $tabla[$clave]++ } else { $tabla[$clave] = 1 }
}

foreach ($archivo in $Archivos) {
    if (-not (Test-Path -LiteralPath $archivo)) {
        # NO es un aviso: si el fichero no se lee, esta prueba deja de mirarlo y
        # antes salia verde igual. Comprobado el 19/09: pasandole la lista con
        # comas desde 'powershell -File' llega como UNA ruta inventada, no
        # existe, y el resumen decia "0 patrones comprobados, todos compilan".
        $fallos++
        Write-Host ("  NO EXISTE  {0}  (de este fichero no se ha comprobado nada)" -f $archivo) -ForegroundColor Red
        continue
    }
    $err = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath $archivo), [ref]$err)
    for ($i = 0; $i -lt $tokens.Count - 1; $i++) {
        $t = $tokens[$i]
        if ($t.Type -ne 'Operator' -and $t.Type -ne 'CommandArgument') { continue }
        if ($operadores -notcontains $t.Content.ToLowerInvariant()) { continue }
        $sig = $tokens[$i + 1]
        if ($sig.Type -ne 'String') { continue }
        # solo literales COMPLETOS: si el patron sigue con '+', es un trozo de
        # una concatenacion ('^cuando...' + $VERBOS + '...') y por si solo no
        # tiene por que compilar.
        $patron = $sig.Content
        if ($patron -match '\$') { continue }
        if ($i + 2 -lt $tokens.Count) {
            $post = $tokens[$i + 2]
            if ($post.Type -eq 'Operator' -and $post.Content -eq '+') { continue }
        }
        $vistos++
        Apunta $vistosPorArchivo (Split-Path -Leaf $archivo)
        # CARACTERES DE CONTROL. Un patron puede compilar perfectamente y aun
        # asi estar roto: si un '\b' escrito en otro lenguaje se colo como
        # BACKSPACE (0x08), el regex busca un backspace literal y no coincide
        # nunca. Paso el 11/09 en siete lineas a la vez -entre ellas el filtro
        # que se comia "dale a enter" y el limite de palabra de los titulos de
        # juego- y ninguna comprobacion lo veia, porque todas compilaban.
        # tabulador, CR y LF son legitimos: hay patrones que parten por lineas
        $control = ($patron.ToCharArray() | Where-Object { [int]$_ -lt 32 -and [int]$_ -notin @(9, 10, 13) })
        if ($control) {
            $fallos++
            $codigos = ($control | ForEach-Object { '0x{0:X2}' -f [int]$_ }) -join ' '
            Write-Host ("  CONTROL {0}:{1}  caracteres invisibles ({2}) en el patron" -f $archivo, $sig.StartLine, $codigos) -ForegroundColor Red
            Write-Host ("          probablemente un escape mal traducido; suele ser un \b")
            continue
        }
        try {
            [void][regex]::new($patron)
        } catch {
            $fallos++
            Write-Host ("  ROTO  {0}:{1}  {2}" -f $archivo, $sig.StartLine, $patron) -ForegroundColor Red
            Write-Host ("        {0}" -f $_.Exception.Message.Trim())
        }
    }
}

# Y LOS CASOS DE UN "switch -regex". Aqui vive buena parte del vocabulario
# (deshaz, repite, colocar ventanas...) y NO pasan por ningun -match, asi que
# el recorrido de arriba no los veia. Se colo un "\l" invalido y no rompio un
# patron: rompio el switch ENTERO, con lo que dejaron de reconocerse 100
# ordenes de golpe. Un error que revienta en tiempo de ejecucion, ademas,
# porque el archivo compila igual.
foreach ($archivo in $Archivos) {
    if (-not (Test-Path -LiteralPath $archivo)) { continue }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $archivo), [ref]$null, [ref]$null)
    $switches = $ast.FindAll({ param($x)
        $x -is [System.Management.Automation.Language.SwitchStatementAst] -and
        ($x.Flags -band [System.Management.Automation.Language.SwitchFlags]::Regex) }, $true)
    foreach ($sw in $switches) {
        foreach ($caso in $sw.Clauses) {
            # Clauses da tuplas (condicion, cuerpo): .Item a secas es el indizador
            # de la tupla, no la condicion
            $lit = $caso.Item1 -as [System.Management.Automation.Language.StringConstantExpressionAst]
            if (-not $lit) { continue }    # los compuestos con $VERBOS se comprueban al usarse
            $patron = $lit.Value
            $vistos++
            Apunta $vistosPorArchivo (Split-Path -Leaf $archivo)
            Apunta $vistosSwitchPorArchivo (Split-Path -Leaf $archivo)
            $control = ($patron.ToCharArray() | Where-Object { [int]$_ -lt 32 -and [int]$_ -notin @(9, 10, 13) })
            if ($control) {
                $fallos++
                $codigos = ($control | ForEach-Object { '0x{0:X2}' -f [int]$_ }) -join ' '
                Write-Host ("  CONTROL {0}:{1}  caracteres invisibles ({2}) en un caso de switch" -f $archivo, $lit.Extent.StartLineNumber, $codigos) -ForegroundColor Red
                continue
            }
            try { [void][regex]::new($patron) } catch {
                $fallos++
                Write-Host ("  ROTO  {0}:{1}  {2}" -f $archivo, $lit.Extent.StartLineNumber, $patron) -ForegroundColor Red
                Write-Host ("        {0}" -f $_.Exception.Message.Trim())
            }
        }
    }
}

Write-Host ""

# EL LISTON: solo se le exige a los ficheros de $MINIMOS que vengan en esta
# pasada (asi se puede seguir apuntando el script a una herramienta suelta, que
# puede no tener ni un patron literal, sin inventar rojos).
$nombres = @($Archivos | ForEach-Object { Split-Path -Leaf $_ })
foreach ($clave in $MINIMOS.Keys) {
    if ($nombres -notcontains $clave) { continue }
    $n = 0
    if ($vistosPorArchivo.ContainsKey($clave)) { $n = $vistosPorArchivo[$clave] }
    if ($n -lt $MINIMOS[$clave]) {
        $fallos++
        Write-Host ("  POCOS  {0}: {1} patrones vistos, minimo {2}" -f $clave, $n, $MINIMOS[$clave]) -ForegroundColor Red
        Write-Host ("         no es que esten rotos: es que esta prueba ha dejado de verlos.")
        Write-Host ("         mira si el fichero se lee entero y si la extraccion sigue valiendo.")
    } else {
        Write-Host ("  liston {0}: {1} patrones (minimo {2})" -f $clave, $n, $MINIMOS[$clave])
    }
}
foreach ($clave in $MINIMOS_SWITCH.Keys) {
    if ($nombres -notcontains $clave) { continue }
    $n = 0
    if ($vistosSwitchPorArchivo.ContainsKey($clave)) { $n = $vistosSwitchPorArchivo[$clave] }
    if ($n -lt $MINIMOS_SWITCH[$clave]) {
        $fallos++
        Write-Host ("  POCOS  {0}: {1} casos de 'switch -regex' vistos, minimo {2}" -f $clave, $n, $MINIMOS_SWITCH[$clave]) -ForegroundColor Red
        Write-Host ("         ahi vive medio vocabulario (deshaz, repite, colocar ventanas...); si baja de golpe,")
        Write-Host ("         lo que ha dejado de funcionar es el recorrido del AST, no las ordenes.")
    } else {
        Write-Host ("  liston {0}: {1} casos de switch (minimo {2})" -f $clave, $n, $MINIMOS_SWITCH[$clave])
    }
}

Write-Host ""
if ($fallos -eq 0) {
    Write-Host "$vistos patrones comprobados, todos compilan."
    exit 0
}
Write-Host "$vistos patrones comprobados, $fallos problemas (rotos, invisibles, ficheros sin leer o por debajo del liston)."
exit 1
