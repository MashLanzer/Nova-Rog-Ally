# CONTAR LO QUE HIZO MIENTRAS NO ESTABAS (25/09, idea 30 de las 50)
#
# LO MEDIDO: el resumen al volver solo cuenta MENSAJES. Todas sus lineas del registro son de
# la misma forma -"Mientras no estabas: 1 mensaje de Discord", "3 mensajes", "5 mensajes de
# Discord"- y ni una dice nada de lo que hizo NOVA. Cuenta lo que paso, no lo que ella hizo.
#
# Y SI QUE HACE COSAS: en la franja de 02 a 08, con braya durmiendo, el registro tiene 302
# avisos aparcados -118 del ruido, 118 del Gmail lleno, 66 del disco- y desde hoy tambien la
# copia de lo aprendido (ver TRABAJAR CUANDO NO MOLESTA, idea 27). Todo eso pasa y nadie se
# entera nunca.
#
# LO QUE PRUEBA ESTE BANCO, y la mitad es lo que NO hace:
#   - que lo diga cuando hay algo que decir, en una frase corta;
#   - que se calle cuando no hay nada;
#   - y que NO sea un motivo para hablar: si no hay mensajes que contar, Nova no saluda solo
#     para presumir de lo que hizo. Es un anadido al resumen, no un resumen propio.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}
$err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) "$($err.Count) error(es)"
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. existe y lo usa el resumen al volver --'
Comp 'existe Get-LoQueHice' ($sinCom -match 'function Get-LoQueHice') ''
$d = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-ResumenAlVolver' }, $true)
Comp 'se encuentra Test-ResumenAlVolver' ($null -ne $d) ''
if ($d) {
    $c = ($d.Extent.Text -split "`n" | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '  y lo llama' ($c -match 'Get-LoQueHice') ''
    # NO ES UN MOTIVO PARA HABLAR: el corte de "no hay nada que contar" tiene que ir ANTES.
    $iCorte = $c.IndexOf('if ($partes.Count -eq 0) { return }')
    $iHice = $c.IndexOf('Get-LoQueHice')
    Comp '  DESPUES del corte de "no hay nada que contar"' (($iCorte -ge 0) -and ($iHice -gt $iCorte)) 'si no, saludaria solo para presumir'
    Comp '  y cuenta los avisos que se guardo' ($c -match 'avisoEspera') ''
    Comp '  y si la copia la hizo durante la ausencia' ($c -match 'Get-CopiaHorasEsperando') 'no vale una copia de antes de irse'
}

Write-Host ''
Write-Host '-- 2. LA FRASE, SACADA DEL ARCHIVO Y EJECUTADA --'
$dF = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-LoQueHice' }, $true)
if (-not $dF) { Comp 'se saca del arbol' $false ''; Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
Invoke-Expression $dF.Extent.Text

# SIN NADA, NADA. Esto es la mitad del valor: la mayoria de las veces no hay que decir nada.
Comp 'sin nada que contar, se calla' ([string]::IsNullOrEmpty((Get-LoQueHice 0 $false))) 'lo normal es no decir nada'

# UN AVISO: en singular, que "me calle 1 cosas" suena a maquina
$f1 = Get-LoQueHice 1 $false
Comp 'con un aviso guardado, lo dice' (-not [string]::IsNullOrEmpty($f1)) "$f1"
Comp '  en singular' ($f1 -notmatch '1 cosa') "$f1"

# VARIOS
$f3 = Get-LoQueHice 3 $false
Comp 'con tres, dice cuantos' ($f3 -match '3') "$f3"

# SOLO LA COPIA
$fc = Get-LoQueHice 0 $true
Comp 'con solo la copia, tambien' (-not [string]::IsNullOrEmpty($fc)) "$fc"
Comp '  y no se inventa avisos' ($fc -notmatch 'calle') "$fc"

# LAS DOS COSAS, en una frase
$f2 = Get-LoQueHice 2 $true
Comp 'las dos cosas van juntas' (($f2 -match 'calle') -and ($f2 -match 'aprendido')) "$f2"
Comp '  en UNA sola frase' ((@($f2 -split '\.' | Where-Object { $_.Trim() }).Count) -eq 1) "$f2"

# NUMEROS RAROS
Comp 'con un negativo no dice nada' ([string]::IsNullOrEmpty((Get-LoQueHice -3 $false))) 'no deberia pasar, pero no revienta'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  ya cuenta lo que hizo mientras no estabas'
exit 0
