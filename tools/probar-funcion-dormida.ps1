# LO QUE NOVA SABE HACER Y BRAYA NO USA (2/10/2026, ideas 14 y 15)
#
# EL DATO: 'memoria\recordatorios.json' esta VACIO -es '[]'- y lleva 20,2 dias sin tocarse, mientras
# 'recordatorio' sale 67 veces en assistant.ps1 y tiene DOS bancos propios. La funcion esta escrita,
# probada y sin usar. Lo mismo 'fechas.json' (104 bytes, 20,8 dias) y 'recetas.json' (5 KB, 7,1 dias,
# con once recetas aprendidas en total).
#
# Y SE MIDIO EL POR QUE, que es lo que decidio el arreglo: en las 609 ordenes del corpus de uso hay
# CERO que suenen a recordatorio -ni 'recuerdame', ni 'avisame', ni 'dentro de N minutos'-. No es que
# Nova no lo entienda: es que braya no sabe que existe. Sin esa medicion, lo normal habria sido
# ponerse a tocar el oido para nada.
#
# LO QUE SE DEFIENDE:
#  1. que se calle si braya NO esta usando a Nova (para eso ya esta Get-AvisoSinUso, y reganar por las
#     dos cosas a la vez es reganar dos veces por lo mismo);
#  2. que hable de UNA sola funcion, la mas dormida, y no de una lista;
#  3. que un fichero que NO EXISTE cuente como "nunca", que es el caso mas claro;
#  4. que la frase lleve el COMO -la orden literal que braya puede repetir- y no solo el que;
#  5. y que nada de esto toque el disco de braya cuando corre el banco.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
        -ForegroundColor $(if ($ok) { 'Gray' } else { 'Red' })
    if (-not $ok) { $script:mal++ }
}
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)
function Traer([string]$n) {
    $d = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true) |
        Select-Object -First 1
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`r?`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# --- el mundo de mentira: carpeta propia, nada del disco de braya ---
$tmp = Join-Path $env:TEMP ("dormida-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$MemoriaDir = $tmp
$FuncionDormidaDias = 14
# LA LISTA SE SACA DEL FICHERO DE VERDAD, no se reescribe aqui: si manana se le anade una cuarta
# funcion, este banco la prueba sola en vez de quedarse mirando una copia vieja (manera 3).
$iL = $txt.IndexOf('$FUNCIONES_DORMIDAS = @(')
$fin = $txt.IndexOf("`n)", $iL)
Invoke-Expression $txt.Substring($iL, $fin - $iL + 2)
$script:sinUsoDice = ''
function Get-AvisoSinUso([string]$r = '', [datetime]$a = (Get-Date), [int]$d = 0) { return $script:sinUsoDice }
Invoke-Expression (Traer 'Get-FuncionDormida')

try {
    Write-Host ''
    Write-Host '-- 0. la lista del fichero de verdad --'
    Comp 'tiene al menos tres funciones' (@($FUNCIONES_DORMIDAS).Count -ge 3) "$(@($FUNCIONES_DORMIDAS).Count)"
    foreach ($fd in $FUNCIONES_DORMIDAS) {
        Comp ("  '" + $fd.f + "' trae el que y el COMO") ([bool]$fd.que -and [bool]$fd.como -and ([string]$fd.como).Length -gt 20) "$($fd.como)"
    }

    Write-Host ''
    Write-Host '-- 1. si braya NO usa a Nova, aqui no se dice nada --'
    $script:sinUsoDice = 'Llevo 20 dias sin apuntar ni una orden tuya...'
    Comp 'se calla del todo' ($null -eq (Get-FuncionDormida)) 'de eso ya habla Get-AvisoSinUso'
    $script:sinUsoDice = ''

    Write-Host ''
    Write-Host '-- 2. un fichero que no existe es "nunca" --'
    $r = Get-FuncionDormida
    Comp 'con la carpeta vacia, habla' ($null -ne $r) ''
    Comp '  y dice "nunca"' ($r -and $r.texto -match 'no me lo pides nunca') "$(if($r){$r.texto})"
    Comp '  con el COMO dentro' ($r -and $r.texto -match 'dime "') ''
    Comp '  y la clave lleva el nombre del fichero' ($r -and $r.clave -match '^dormida-') "$(if($r){$r.clave})"

    Write-Host ''
    Write-Host '-- 3. recien usada, no se menciona --'
    foreach ($fd in $FUNCIONES_DORMIDAS) {
        $p = Join-Path $tmp ([string]$fd.f)
        [IO.File]::WriteAllText($p, '[]', (New-Object System.Text.UTF8Encoding($false)))
    }
    Comp 'con todo tocado hoy, se calla' ($null -eq (Get-FuncionDormida)) ''

    Write-Host ''
    Write-Host '-- 4. habla de UNA, la mas dormida --'
    $p1 = Join-Path $tmp ([string]$FUNCIONES_DORMIDAS[0].f)
    $p2 = Join-Path $tmp ([string]$FUNCIONES_DORMIDAS[1].f)
    (Get-Item -LiteralPath $p1).LastWriteTime = (Get-Date).AddDays(-20)
    (Get-Item -LiteralPath $p2).LastWriteTime = (Get-Date).AddDays(-40)
    $r4 = Get-FuncionDormida
    Comp 'gana la que lleva mas tiempo' ($r4 -and $r4.texto -match ([regex]::Escape([string]$FUNCIONES_DORMIDAS[1].que))) "$(if($r4){$r4.texto.Substring(0,[Math]::Min(60,$r4.texto.Length))})"
    Comp '  y dice cuantos dias' ($r4 -and $r4.texto -match 'desde hace 40 dias') ''
    Comp '  y SOLO una (no es una lista)' ($r4 -and @(($r4.texto -split 'Se hacer')).Count -eq 2) 'una conferencia no es un aviso'

    Write-Host ''
    Write-Host '-- 5. justo en el borde del plazo --'
    foreach ($fd in $FUNCIONES_DORMIDAS) {
        $p = Join-Path $tmp ([string]$fd.f)
        (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-13)
    }
    Comp 'a los 13 dias todavia no' ($null -eq (Get-FuncionDormida)) "el plazo son $FuncionDormidaDias"
    foreach ($fd in $FUNCIONES_DORMIDAS) {
        $p = Join-Path $tmp ([string]$fd.f)
        (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-14)
    }
    Comp '  y a los 14 si' ($null -ne (Get-FuncionDormida)) ''
    # Y CON EL PLAZO A CERO SE APAGA, que es lo que hace a esto desactivable sin tocar codigo
# EL APAGADO VA POR config.json (funcionDormidaDias = 0), no por el parametro: pasar 0 ahi
# significa "usa el valor por defecto", que es lo contrario. Se prueba la puerta de verdad.
$guardado = $FuncionDormidaDias
$FuncionDormidaDias = 0
Comp 'con el plazo a 0 en config, se apaga' ($null -eq (Get-FuncionDormida)) 'desactivable sin tocar codigo'
$FuncionDormidaDias = $guardado
Comp '  y al devolverlo, vuelve a hablar' ($null -ne (Get-FuncionDormida)) ''

    Write-Host ''
    Write-Host '-- 6. el cableado --'
    Comp 'el plazo sale de config.json' ($sinCom -match "Get-Cfg 'entorno' 'funcionDormidaDias'") ''
    Comp 'se llama desde el bloque de media hora' ($sinCom -match 'Get-FuncionDormida') ''
    # EXCLUYENTE CON EL OTRO AVISO: tiene que estar DENTRO del 'if (-not $txtU)'
    $iU = $sinCom.IndexOf('if (-not $txtU) {')
    $iD = $sinCom.IndexOf('Get-FuncionDormida', [Math]::Max(0, $iU))
    Comp '  y solo si el otro aviso no tiene nada que decir' ($iU -ge 0 -and $iD -gt $iU) ''
    Comp "  con nivel 'bajo'" ($sinCom -match "Send-AvisoEntorno \(\[string\]\`$fd2\.clave\) \(\[string\]\`$fd2\.texto\) 'bajo'") 'no es una averia'
    Comp '  y un plazo largo' ($sinCom -match "\`$fd2\.texto\) 'bajo' 64800") '45 dias: una vez y no se insiste'

    Write-Host ''
    if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
    Write-Host 'Nova ofrece lo que sabe hacer y no le piden, una vez y sin insistir' -ForegroundColor Green
    exit 0
}
finally {
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
