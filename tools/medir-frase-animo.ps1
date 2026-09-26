# CUANTAS VECES HABLARIA EL ANIMO DE FONDO, con los dias de verdad (25/09, idea 38).
#
# Get-FraseAnimo dice "te estoy entendiendo mejor" o "llevo unos dias entendiendote peor"
# comparando la tendencia de hoy con la de hace tres dias. La pregunta que decide si eso es
# una buena idea o una pesada no se contesta leyendo el codigo: se contesta corriendolo sobre
# memoria\estadisticas.json y contando en cuantos dias habria abierto la boca.
#
# NO TOCA NADA: lee las estadisticas, saca las funciones del assistant.ps1 con el arbol y las
# ejecuta dia a dia. No escribe, no avisa, no guarda.
#
# Lo que dio el 25/09 con 14 dias (11 al 25 de septiembre): habla 5, calla 9. Y de esos cinco,
# el 17 repite la frase del 16 y el 24 la del 23, que es lo que justifica la guarda de
# $AnimoFraseCadaDias con una clave por frase. Con ella quedan tres: 16, 23 y 25.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  la medicion se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$txt = [IO.File]::ReadAllText($PS1)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$null)

# las del animo, sacadas del archivo (y no una lista a mano, que caduca)
foreach ($f in @($ast.FindAll({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -match 'Animo' }, $true))) {
    if ($f.Name -eq 'Test-AnimoQueSeCuenta') { continue }   # esa habla; aqui solo se mide
    Invoke-Expression $f.Extent.Text
}
foreach ($cte in @('AnimoLargoDias', 'AnimoLargoMinSucesos', 'AnimoLargoMinDias', 'AnimoSaltoMin',
                   'AnimoFraseMejor', 'AnimoFrasePeor', 'AnimoFraseCadaDias')) {
    $m = [regex]::Match($txt, ('(?m)^\$' + $cte + '\s*=\s*(.+)$'))
    if (-not $m.Success) { Write-Host "  MAL  no encuentro la constante $cte"; exit 1 }
    Invoke-Expression ('$' + $cte + ' = ' + $m.Groups[1].Value.Trim())
}
function Log([string]$m) { Write-Host ("  (queja: " + $m + ")") }

$ruta = Join-Path $Raiz 'memoria\estadisticas.json'
if (-not (Test-Path -LiteralPath $ruta)) { Write-Host "no hay $ruta"; exit 1 }
$j = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8 | ConvertFrom-Json
$dias = @{}
foreach ($p in $j.dias.PSObject.Properties) {
    $h = @{}
    foreach ($q in $p.Value.PSObject.Properties) { try { $h[$q.Name] = [int]$q.Value } catch {} }
    $dias[$p.Name] = $h
}
$claves = @($dias.Keys | Sort-Object)
if ($claves.Count -eq 0) { Write-Host 'estadisticas.json no tiene ni un dia'; exit 1 }
Write-Host ("dias con datos: " + $claves.Count + "  (" + $claves[0] + " .. " + $claves[-1] + ")")
Write-Host ''
Write-Host 'dia          sucesos  animoDia   fondo(base)  hace3d(base)   salto  que diria'
$hablo = 0; $trasGuarda = 0
$ultima = @{}   # clave de frase -> dia en que se dijo, que es justo lo que hace la guarda
foreach ($k in $claves) {
    $hoy = [datetime]::ParseExact($k, 'yyyy-MM-dd', $null)
    $dd = Get-AnimoDia $dias $k
    $a = Get-AnimoLargo $dias $hoy
    $b = Get-AnimoLargo $dias $hoy.AddDays(-3)
    $f = Get-FraseAnimo $dias $hoy
    $marca = '-'
    if ($f) {
        $hablo++
        $clave = if ($f -eq $AnimoFraseMejor) { 'animo-mejor' } else { 'animo-peor' }
        $sale = $true
        if ($ultima.ContainsKey($clave)) {
            if (($hoy - $ultima[$clave]).TotalDays -lt $AnimoFraseCadaDias) { $sale = $false }
        }
        if ($sale) { $ultima[$clave] = $hoy; $trasGuarda++; $marca = $f }
        else { $marca = '(se calla: repetiria lo del ' + $ultima[$clave].ToString('dd/MM') + ')' }
    }
    Write-Host ("{0}   {1,6}  {2,8:N2}   {3,6:N2}({4})     {5,6:N2}({6})   {7,6:N2}  {8}" -f `
        $k, $dd.sucesos, $dd.animo, $a.animo, $a.dias, $b.animo, $b.dias, ($a.animo - $b.animo), $marca)
}
Write-Host ''
Write-Host ("la frase sale en " + $hablo + " de " + $claves.Count + " dias")
Write-Host ("y con la guarda de " + $AnimoFraseCadaDias + " dias por frase, se dice en " + $trasGuarda)
exit 0
