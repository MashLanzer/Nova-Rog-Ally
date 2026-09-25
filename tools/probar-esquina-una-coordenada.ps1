# "MUEVETE A LA DERECHA": UNA SOLA COORDENADA, Y LA COLETILLA (25/09)
#
# EL DATO. Los dos patrones de esquina exigen las DOS coordenadas juntas -(arriba|abajo) Y
# (izquierda|derecha)- y acaban anclados en $, asi que ni una sola ni "de la pantalla" detras.
# Contado sobre los 633 dictados distintos de assistant.log y su rotado, braya lo ha pedido
# CUATRO veces y las cuatro con una sola coordenada, y el patron cogia CERO:
#     "mueve a la derecha"
#     "exacto muevete a la derecha de la pantalla"
#     "no no tu muevete a la derecha"
#     "no no no muevete a la derecha de la pantalla"
# Tres de las cuatro llevan delante algo que $FILLER_INI no quita ("exacto", "no no", "tu"), y
# por eso el patron nuevo admite ese arranque. Se puede permitir precisamente aqui porque mover
# la capsula es la orden mas inofensiva que tiene Nova: no borra, no cierra y no gasta. Meter
# "no" en $FILLER_INI seria lo contrario -se llevaria la negacion de TODAS las ordenes-, y por
# eso el arranque se admite en ESTE patron y no en la lista general.
#
# LO QUE NO PUEDE ROBAR, y por eso la coordenada va al FINAL de la frase:
#   "mueve y take two a la cappeta games"   -> mover un fichero (asi lo oyo Nova)
#   "no abre youtube en la pantalla izquierda a media pantalla izquierda y painter a media..."
#   -> pantalla partida, que es otra cosa entera.
# Medido: 4 de 4 cogidas, 0 coladas de 633.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$fuente = [System.IO.File]::ReadAllText((Join-Path $raiz 'assistant.ps1'))

$fallos = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-58} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $que, $detalle)
    if (-not $ok) { $script:fallos++ }
}

# LAS DOS RAMAS DE VERDAD, sacadas del archivo entre dos marcas suyas: la de las dos
# coordenadas y la nueva de una sola. Van juntas a proposito, para que se vea que la nueva no
# le quita ninguna frase a la vieja.
$ini = $fuente.IndexOf('# --- a que esquina se va la capsula ---')
$fin = if ($ini -ge 0) { $fuente.IndexOf("if (`$f -match '^(?:donde estas", $ini) } else { -1 }
if ($ini -lt 0 -or $fin -lt 0) { Write-Host '  MAL  no encuentro la rama de una sola coordenada'; exit 1 }
$rama = $fuente.Substring($ini, $fin - $ini)
# LA ESQUINA DE AHORA. La rama la lee de $script:esquina, la misma variable que usa
# 'donde estas' (assistant.ps1:15094). Se le pone una conocida para poder comprobar que SOLO
# cambia la coordenada que se dijo.
$script:esquina = 'abajo-izquierda'
Invoke-Expression ("function Esquina([string]`$f) {`n" + $rama + "`n}")

Write-Host ''
Write-Host '-- 1. LAS CUATRO VECES QUE LO PIDIO, Y NINGUNA ENTRABA --'
$reales = @(
    'mueve a la derecha',
    'exacto muevete a la derecha de la pantalla',
    'no no tu muevete a la derecha',
    'no no no muevete a la derecha de la pantalla'
)
foreach ($r in $reales) {
    $a = @(Esquina $r)
    Comp ('"' + $r + '"') ($a.Count -eq 1 -and $a[0].kind -eq 'esquina' -and $a[0].valor -eq 'abajo-derecha') `
        $(if ($a.Count) { "valor=$($a[0].valor)" } else { 'no la coge' })
}

Write-Host ''
Write-Host '-- 2. SOLO CAMBIA LA COORDENADA QUE SE DIJO --'
# Si "muevete a la derecha" moviera tambien la vertical, se estaria inventando la mitad de la
# orden. Se prueba desde las dos verticales.
$script:esquina = 'arriba-izquierda'
$aV = @(Esquina 'muevete a la derecha')
Comp 'desde arriba-izquierda se queda arriba' ($aV.Count -eq 1 -and $aV[0].valor -eq 'arriba-derecha') $(if ($aV.Count) { $aV[0].valor })
$script:esquina = 'abajo-derecha'
$aH = @(Esquina 'ponte arriba')
Comp 'y "ponte arriba" no toca la horizontal' ($aH.Count -eq 1 -and $aH[0].valor -eq 'arriba-derecha') $(if ($aH.Count) { $aH[0].valor })

Write-Host ''
Write-Host '-- 3. LO QUE NO PUEDE ROBAR --'
$script:esquina = 'abajo-izquierda'
$noRoba = @(
    # ESTA ES LA QUE PROTEGE EL ANCLAJE FINAL, y las otras tres no. Sin el $ del final, esta
    # frase casaria y Nova se pondria en la esquina TIRANDO "y abre steam": media orden
    # perdida sin decir nada. Las otras tres se caen por el verbo o por no llevar coordenada,
    # asi que con ellas solas quitar el anclaje salia en VERDE. Lo destapo una rotura.
    'muevete a la derecha y abre steam',
    'ponte abajo y pon el modo juego',
    'mueve y take two a la cappeta games',
    'no abre youtube en la pantalla izquierda a media pantalla izquierda y painter a media pantalla derecha',
    'si pero abre youtube en la pantalla izquierda y pinterest en la pantalla derecha'
)
foreach ($n in $noRoba) {
    Comp ('no la coge: "' + $n.Substring(0, [Math]::Min(46, $n.Length)) + '..."') (@(Esquina $n).Count -eq 0)
}

Write-Host ''
Write-Host '-- 4. Y LAS DE DOS COORDENADAS SIGUEN COMO ESTABAN --'
foreach ($d in @(@('ponte abajo a la derecha', 'abajo-derecha'), @('vete a la esquina de arriba izquierda', 'arriba-izquierda'))) {
    $aD = @(Esquina $d[0])
    Comp ('"' + $d[0] + '"') ($aD.Count -eq 1 -and $aD[0].valor -eq $d[1]) $(if ($aD.Count) { "valor=$($aD[0].valor)" } else { 'no la coge' })
}

Write-Host ''
if ($fallos) { Write-Host "$fallos casos MAL"; exit 1 }
Write-Host 'una sola coordenada mueve solo esa coordenada'
exit 0
