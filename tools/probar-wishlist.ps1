# LA LISTA DE DESEOS, Y CUANDO BAJA DE PRECIO (1/10, la 12 de las 20 funciones nuevas)
#
# MEDIDO al escribirla: la lista de braya tiene 33 juegos. Y una trampa que costo un 400:
# 'appdetails' solo acepta VARIOS juegos de golpe si se le pone 'filters=price_overview', y con ese
# filtro NO devuelve el nombre; sin filtro acepta UNO solo. Asi que no se pueden tener los doce
# nombres sin hacer doce llamadas, y el canal de Steam es uno.
#
# LO QUE ESTA SECCION DEFIENDE:
#  1. que la NOTICIA sea la bajada respecto a la ultima vez, no la lista -eso ya lo ve en Steam-;
#  2. que la foto de precios se guarde SIEMPRE que haya algo, tambien la primera vez: sin ella no
#     hay con que comparar manana y la funcion no sirve de nada;
#  3. que NO recite appids en voz alta, porque no sirven a nadie;
#  4. y que un juego gratis o sin precio en la region no cuente como "ha bajado".
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle = '') {
    Write-Host ("  {0}  {1,-54} {2}" -f $(if ($ok) { 'ok ' } else { 'MAL' }), $que, $detalle) `
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
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-wish-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $MemoriaDir = $tmp
    $WishlistPath = Join-Path $tmp 'wishlist-precios.json'
    $WishlistMiraMax = 12
    $WishlistBajaMin = 10
    foreach ($n in @('Write-Atomico', 'Get-WishlistPrecios', 'Format-WishlistPrecios')) { Invoke-Expression (Traer $n) }
    # NO SE ABRE STEAM DE VERDAD: la funcion abre la lista cuando hay bajadas, y un banco no puede
    # abrirle ventanas a braya cada vez que corre la bateria.
    $script:abiertas = @()
    function Start-Process { param([string]$FilePath, $ArgumentList, $WindowStyle, [switch]$Wait) $script:abiertas += $FilePath }

    function Respuesta($pares) {
        # el JSON que devuelve appdetails: { "<appid>": { success, data: { price_overview } } }
        $sb = @()
        foreach ($p in $pares) {
            $sb += ('"' + $p.id + '": {"success": true, "data": {"price_overview": {"final": ' + $p.cent +
                    ', "discount_percent": ' + $p.desc + ', "final_formatted": "$' + ([Math]::Round($p.cent / 100.0, 2)) + '"}}}')
        }
        return ('{' + ($sb -join ',') + '}') | ConvertFrom-Json
    }

    Write-Host ''
    Write-Host '-- 1. la primera vez guarda la foto y no inventa bajadas --'
    $o1 = Respuesta @(@{ id = '111'; cent = 1999; desc = 0 }, @{ id = '222'; cent = 4999; desc = 0 })
    $f1 = Format-WishlistPrecios $o1 @('111', '222') 33
    Comp 'la primera vez no dice que haya bajado nada' ($f1 -match 'Nada de tu lista ha bajado') "$f1"
    Comp '  y dice cuantos ha mirado de cuantos' ($f1 -match 'He mirado 2 de los 33') ''
    Comp '  y GUARDA la foto' (Test-Path -LiteralPath $WishlistPath) 'sin ella, manana no hay con que comparar'
    $g = Get-WishlistPrecios
    Comp '  con los dos precios' ($g['111'] -eq 19.99 -and $g['222'] -eq 49.99) "$($g.Count) guardados"

    Write-Host ''
    Write-Host '-- 2. y la segunda, la bajada ES la noticia --'
    $script:abiertas = @()
    $o2 = Respuesta @(@{ id = '111'; cent = 999; desc = 50 }, @{ id = '222'; cent = 4999; desc = 0 })
    $f2 = Format-WishlistPrecios $o2 @('111', '222') 33
    Comp 'dice que ha bajado uno' ($f2 -match 'Ha bajado uno') "$f2"
    Comp '  y cuanto ha bajado' ($f2 -match 'un 50 por ciento') ''
    Comp '  y a cuanto se queda' ($f2 -match '9\.99') ''
    # NO RECITA APPIDS: no sirven a nadie en voz alta.
    Comp '  y NO recita el appid' ($f2 -notmatch '111') 'appdetails no da nombres con varios ids'
    Comp '  y abre la lista, que es donde estan los nombres' ($script:abiertas -contains 'steam://url/WishlistPage') ''
    # Y LA FOTO SE ACTUALIZA, o maniana diria que bajo otra vez lo mismo
    Comp '  y actualiza la foto' ((Get-WishlistPrecios)['111'] -eq 9.99) "$((Get-WishlistPrecios)['111'])"
    $script:abiertas = @()
    $f2b = Format-WishlistPrecios $o2 @('111', '222') 33
    # OJO AL ESCRIBIR ESTO: '-notmatch "Ha bajado"' tambien casa con "NO ha bajado", porque
    # PowerShell no distingue mayusculas. Se comprueba la frase entera del caso que toca.
    Comp '  asi que no repite la misma bajada' ($f2b -match 'No ha bajado nada desde la ultima vez') "$f2b"
    Comp '  y no abre la lista otra vez' ($script:abiertas.Count -eq 0) 'abrir Steam sin noticia es molestar'

    Write-Host ''
    Write-Host '-- 3. una bajada pequena no es noticia --'
    # Un 3 % no merece una frase: el liston son 10.
    [IO.File]::WriteAllText($WishlistPath, '{"333": 20.0}')
    $o3 = Respuesta @(@{ id = '333'; cent = 1950; desc = 0 })
    Comp 'un 3 por ciento no se dice' ((Format-WishlistPrecios $o3 @('333') 1) -notmatch 'bajado uno') "$(Format-WishlistPrecios $o3 @('333') 1)"
    [IO.File]::WriteAllText($WishlistPath, '{"333": 20.0}')
    $o3b = Respuesta @(@{ id = '333'; cent = 1700; desc = 0 })
    Comp 'y un 15 por ciento si' ((Format-WishlistPrecios $o3b @('333') 1) -match 'Ha bajado uno') ''

    Write-Host ''
    Write-Host '-- 4. si no ha bajado nada pero hay ofertas, lo dice --'
    [IO.File]::WriteAllText($WishlistPath, '{"444": 10.0}')
    $o4 = Respuesta @(@{ id = '444'; cent = 1000; desc = 40 })
    $f4 = Format-WishlistPrecios $o4 @('444') 1
    Comp 'dice que hay una en oferta' ($f4 -match 'en oferta' -and $f4 -match '40 por ciento') "$f4"
    Comp '  y aclara que no ha bajado desde la ultima vez' ($f4 -match 'No ha bajado nada desde la ultima vez') ''

    Write-Host ''
    Write-Host '-- 5. lo que NO cuenta --'
    # Un juego gratis o sin precio en la region no tiene price_overview: no puede contar como bajada.
    $oSin = '{"555": {"success": true, "data": {}}}' | ConvertFrom-Json
    Comp 'un juego sin precio no cuenta' ((Format-WishlistPrecios $oSin @('555') 1) -match 'no me ha dado los precios') "$(Format-WishlistPrecios $oSin @('555') 1)"
    $oFalla = '{"666": {"success": false}}' | ConvertFrom-Json
    Comp 'y uno que Steam no resuelve, tampoco' ((Format-WishlistPrecios $oFalla @('666') 1) -match 'no me ha dado los precios') ''
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca la wishlist' ($sinCom -match "que = 'wishlist'") ''
Comp '  y el ejecutor no le pide un juego' ($sinCom -match "if \(\[string\]\`$a\.que -eq 'wishlist'\)") 'no va de un juego concreto'
Comp '  y la maquina tiene sus dos pasos' (($sinCom -match "paso = 'uno'") -and ($sinCom -match "paso = 'dos'")) ''
# EL FILTRO VA SOLO, sin cc ni l: con ellos appdetails devuelve 400 (medido).
$cuerpo = Traer 'Receive-SteamPregunta'
Comp '  y pide los precios con el filtro solo' (($cuerpo -match 'filters=price_overview') -and ($cuerpo -notmatch 'filters=price_overview&cc')) 'con cc o l da 400'
# Y LOS PRECIOS NO SE ESCAPAN AL REPOSITORIO, que es publico
$gi = [IO.File]::ReadAllText((Join-Path $Raiz '.gitignore'))
Comp 'la foto de precios esta ignorada en git' ($gi -match 'wishlist-precios\.json') 'son sus gustos de compra'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova avisa cuando algo de tu lista de deseos baja de precio' -ForegroundColor Green
exit 0
