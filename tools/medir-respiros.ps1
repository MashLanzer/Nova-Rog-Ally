# ¿Cuanto se ahorra con la mejora 2? Se saca del archivo real la lista RESPIRO y
# se cuentan los respiros antes y despues para ordenes tipicas.
$ruta = 'C:\Users\braya\Documents\voice-ctrl\assistant.ps1'
$lineas = Get-Content -LiteralPath $ruta

# la lista tal como quedo escrita en el codigo
$texto = ($lineas | Select-String -Pattern '\$RESPIRO = @\(' -Context 0, 2).ToString()
$inicio = [array]::IndexOf($lineas, ($lineas | Where-Object { $_ -match '\$RESPIRO = @\(' } | Select-Object -First 1))
$bloque = ($lineas[$inicio..($inicio + 2)] -join ' ')
Invoke-Expression ($bloque -replace '^\s*', '')
"acciones que piden respiro: $($RESPIRO.Count)"

# kinds de cada orden tipica (sacados a mano de lo que hace cada una)
$casos = @(
    @{ orden = 'modo juego';                     kinds = @('decir', 'brillo', 'volumenPct', 'app') },
    @{ orden = 'modo noche';                     kinds = @('decir', 'brillo', 'volumenPct') },
    @{ orden = 'abre steam, discord y spotify';  kinds = @('app', 'app', 'app') },
    @{ orden = 'abre steam y sube el volumen';   kinds = @('app', 'volumen') },
    @{ orden = 'que hora es';                    kinds = @('decir') },
    @{ orden = 'apunta que el codigo es 328';    kinds = @('memoria') },
    @{ orden = 'a que estoy jugando';            kinds = @('queJuego') }
)

$totalAntes = 0; $totalDespues = 0
foreach ($c in $casos) {
    $n = $c.kinds.Count
    $antes = $n * 250
    $despues = 0
    for ($i = 0; $i -lt $n; $i++) {
        if ($i -lt ($n - 1) -and $RESPIRO -contains $c.kinds[$i]) { $despues += 250 }
    }
    $totalAntes += $antes; $totalDespues += $despues
    "  {0,-34} {1,5} ms -> {2,5} ms   (ahorra {3} ms)" -f $c.orden, $antes, $despues, ($antes - $despues)
}
""
"  en estas siete ordenes: {0} ms -> {1} ms, o sea {2} ms menos de espera regalada" -f $totalAntes, $totalDespues, ($totalAntes - $totalDespues)
