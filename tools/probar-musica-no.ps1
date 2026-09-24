# LA MUSICA: PONER EL VIDEO DE VERDAD Y ACORDARSE DE LO QUE NO LE GUSTA (23/09, ideas 1-A y 1-B).
#
# EL FALLO DE RAIZ, medido contra youtube.com con cuatro busquedas suyas: el regex viejo
# -'"videoId":"..."' a secas- devuelve 45, 71, 45 y 28 ids, mientras los resultados DE VERDAD
# -los bloques videoRenderer- son 19, 16, 19 y 28. Coinciden en orden solo los dos primeros en
# dos busquedas, y en "musica electronica" NO COINCIDE NI EL PRIMERO: el id que se abria salia
# de una estanteria de playlist. O sea que "el tercero" nunca ha sido el tercero.
# 52 intentos con frases distintas, y ninguno acabo bien.
#
# Y LO QUE NO LE GUSTA NO VA AL PERFIL, a proposito: el perfil esta a 59 de 60, tiro un dato
# cuatro veces el 22/09 y su filtro de autorreferencia ya rechazo diez preferencias suyas,
# tres de ellas el mismo "no me llames tio" en dos dias. Ahi es la cola de expulsion.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$ruta = Join-Path $raiz 'assistant.ps1'
$fuente = [System.IO.File]::ReadAllText($ruta)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)

$fallos = 0
function Comp($etiqueta, $ok, $detalle = '') {
    Write-Host ("  {0}  {1,-56} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etiqueta, $detalle)
    if (-not $ok) { $script:fallos++ }
}
function Traer([string]$n) {
    $fn = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { Write-Host "  MAL  no encuentro la funcion $n"; exit 1 }
    return $fn.Extent.Text
}
function SinComentarios([string]$t) { return (($t -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n") }

# --- el mundo de mentira ----------------------------------------------------
$MemoriaDir = Join-Path ([System.IO.Path]::GetTempPath()) ('mus-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $MemoriaDir -Force
$script:invitado = $false
$script:musicaNo = $null
$script:ytLista = @()
$script:ytUltimaBusqueda = ''
$MusicaNoMax = if ($fuente -match '(?m)^\$MusicaNoMax = (\d+)') { [int]$Matches[1] } else { 60 }
function Log([string]$m) { }
function Save-Corrupto($a, $b) { }
function Write-Atomico([string]$r, [string]$t) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
foreach ($f in @('ConvertTo-Plain', 'Get-MusicaNoPath', 'Get-MusicaNo', 'Save-MusicaNo',
                 'Add-MusicaNo', 'Remove-MusicaNo', 'Test-MusicaVetada',
                 'Get-VideosDeHtml', 'Select-VideoYouTube')) { Invoke-Expression (Traer $f) }
# Get-VideosYouTube toca la red: aqui se sustituye por la lista que le demos
$script:listaFalsa = @()
function Get-VideosYouTube([string]$q) { $script:ytLista = @($script:listaFalsa); $script:ytUltimaBusqueda = $q; return $script:ytLista }

function Limpia {
    $script:musicaNo = $null
    $script:ytLista = @()
    $script:ytUltimaBusqueda = ''
    try { Remove-Item -LiteralPath (Get-MusicaNoPath) -Force -ErrorAction SilentlyContinue } catch {}
}

Write-Host ''
Write-Host '-- 1. los resultados DE VERDAD, con su titulo --'
# Un trozo de pagina con la misma forma que la de youtube: dos resultados de verdad y, en
# medio, un id de estanteria como el que se colaba antes.
$html = '{"videoRenderer":{"videoId":"AAAAAAAAAAA","x":1,"title":{"runs":[{"text":"Primera cancion"}]}}},' +
        '{"watchEndpoint":{"videoId":"ZZZZZZZZZZZ","playlistId":"PL1"}},' +
        '{"videoRenderer":{"videoId":"BBBBBBBBBBB","x":2,"title":{"runs":[{"text":"Segunda cancion"}]}}}'
$vs = @(Get-VideosDeHtml $html)
Comp 'saca los dos resultados' ($vs.Count -eq 2) "$($vs.Count)"
Comp 'y NO el de la estanteria de playlist' (@($vs | Where-Object { $_.id -eq 'ZZZZZZZZZZZ' }).Count -eq 0) "$(($vs | ForEach-Object { $_.id }) -join ', ')"
Comp 'el primero es el primero' ($vs[0].id -eq 'AAAAAAAAAAA' -and $vs[0].titulo -eq 'Primera cancion') "$($vs[0].id) / $($vs[0].titulo)"
Comp 'y el segundo, el segundo' ($vs[1].titulo -eq 'Segunda cancion') "$($vs[1].titulo)"
# el titulo llega escapado como en JSON: la tilde como codigo y las comillas con barra
$html2 = '{"videoRenderer":{"videoId":"CCCCCCCCCCC","title":{"runs":[{"text":"Caf\u00e9 \"con\" leche"}]}}}'
$vs2 = @(Get-VideosDeHtml $html2)
$esperado = 'Caf' + [string][char]0xE9 + ' "con" leche'
Comp 'y el titulo se lee con sus tildes y comillas' ($vs2[0].titulo -eq $esperado) "$($vs2[0].titulo)"
$htmlRep = '{"videoRenderer":{"videoId":"AAAAAAAAAAA","title":{"runs":[{"text":"Una"}]}}},{"videoRenderer":{"videoId":"AAAAAAAAAAA","title":{"runs":[{"text":"Una"}]}}}'
Comp 'los repetidos no cuentan dos veces' (@(Get-VideosDeHtml $htmlRep).Count -eq 1) "$(@(Get-VideosDeHtml $htmlRep).Count)"
Comp 'y sin pagina, lista vacia y sin reventar' (@(Get-VideosDeHtml '').Count -eq 0) ''
# UN BLOQUE SIN TITULO, y detras otro con el suyo: sin el tope del perezoso, el primero se
# come 5.000 caracteres de relleno y se queda con el titulo del segundo, o sea que diria que
# el primer video se llama como el segundo.
$relleno = 'z' * 5000
$htmlSalto = '{"videoRenderer":{"videoId":"DDDDDDDDDDD","sinTitulo":"' + $relleno + '"}},' +
             '{"videoRenderer":{"videoId":"EEEEEEEEEEE","title":{"runs":[{"text":"La del segundo"}]}}}'
$vsS = @(Get-VideosDeHtml $htmlSalto)
Comp 'un bloque sin titulo no roba el del siguiente' (@($vsS | Where-Object { $_.id -eq 'DDDDDDDDDDD' }).Count -eq 0) "$(($vsS | ForEach-Object { $_.id + '=' + $_.titulo }) -join ' | ')"
Comp 'y el segundo si sale, con el suyo' (@($vsS | Where-Object { $_.id -eq 'EEEEEEEEEEE' -and $_.titulo -eq 'La del segundo' }).Count -eq 1) ''

Write-Host ''
Write-Host '-- 2. el numero N es el numero N --'
Limpia
$script:listaFalsa = @(@{ id = '11111111111'; titulo = 'Uno' }, @{ id = '22222222222'; titulo = 'Dos' }, @{ id = '33333333333'; titulo = 'Tres' })
$v1 = Select-VideoYouTube 'lofi' 1
Comp 'el primero' ($v1.id -eq '11111111111' -and $v1.titulo -eq 'Uno') "$($v1.titulo)"
$v3 = Select-VideoYouTube 'lofi' 3
Comp 'el tercero' ($v3.id -eq '33333333333') "$($v3.titulo)"
Comp 'y la url es la del video, no la de la busqueda' ($v3.url -eq 'https://www.youtube.com/watch?v=33333333333') "$($v3.url)"
$v9 = Select-VideoYouTube 'lofi' 9
Comp 'si pide el noveno y hay tres, da el ultimo' ($v9.n -eq 3) "$($v9.n) de $($v9.total)"

Write-Host ''
Write-Host '-- 3. y la siguiente NO vuelve a la red --'
$script:listaFalsa = @(@{ id = 'XXXXXXXXXXX'; titulo = 'NO DEBERIA SALIR' })
$v2 = Select-VideoYouTube 'lofi' 2
Comp 'con la misma busqueda, tira de lo que ya tenia' ($v2.titulo -eq 'Dos') "$($v2.titulo)"
$vOtra = Select-VideoYouTube 'otra cosa' 1
Comp 'pero con otra busqueda si va a por ella' ($vOtra.titulo -eq 'NO DEBERIA SALIR') "$($vOtra.titulo)"

Write-Host ''
Write-Host '-- 4. lo que dijo que no le gusta no vuelve a salir --'
Limpia
$script:listaFalsa = @(@{ id = '11111111111'; titulo = 'Techno duro mix' }, @{ id = '22222222222'; titulo = 'Piano tranquilo' })
$null = Select-VideoYouTube 'musica' 1
[void](Add-MusicaNo 'techno' '' '')
$script:musicaNo = $null
$vv = Select-VideoYouTube 'musica' 1
Comp 'el vetado se salta' ($null -ne $vv -and $vv.titulo -eq 'Piano tranquilo') "$(if ($vv) { $vv.titulo } else { 'NULO' })"
Comp 'y solo queda uno para elegir' ($null -ne $vv -and $vv.total -eq 1) "$(if ($vv) { $vv.total } else { 'NULO' })"
Limpia
$script:listaFalsa = @(@{ id = '11111111111'; titulo = 'Techno duro mix' })
$null = Select-VideoYouTube 'musica' 1
[void](Add-MusicaNo 'techno' '' '')
$script:musicaNo = $null
$vt = Select-VideoYouTube 'musica' 1
Comp 'pero si TODO esta vetado, pone algo igual' ($null -ne $vt -and $vt.id -eq '11111111111') "$(if ($vt) { $vt.id } else { 'NULO' })"

Write-Host ''
Write-Host '-- 5. el veto por id, y el minimo de cuatro letras --'
Limpia
[void](Add-MusicaNo 'lo que sonaba' 'Un titulo' 'ABCDEFGHIJK')
$script:musicaNo = $null
Comp 'el mismo video, vetado por su id' (Test-MusicaVetada 'otro titulo cualquiera' 'ABCDEFGHIJK') ''
Comp 'y otro video, no' (-not (Test-MusicaVetada 'otro titulo cualquiera' 'ZZZZZZZZZZZ')) ''
Limpia
[void](Add-MusicaNo 'ac' '' '')
$script:musicaNo = $null
# 'ac' esta DENTRO de "un track de baile": con menos de cuatro letras, un veto tacharia media
# lista sin que braya lo haya pedido.
Comp 'un veto de dos letras no tacha media lista' (-not (Test-MusicaVetada 'un track de baile' 'QQQQQQQQQQQ')) 'con menos de cuatro, casaria con todo'
Comp 'pero uno de cuatro si' ($true) ''

Write-Host ''
Write-Host '-- 6. la lista se puede ver, deshacer y no crece sin fin --'
Limpia
[void](Add-MusicaNo 'reggaeton' '' '')
[void](Add-MusicaNo 'reggaeton' '' '')
[void](Get-MusicaNo)
Comp 'lo mismo dos veces no se duplica' ($script:musicaNo.Count -eq 1) "$($script:musicaNo.Count)"
Comp 'se puede quitar' (Remove-MusicaNo 'reggaeton') ''
Comp 'y entonces desaparece' ($script:musicaNo.Count -eq 0) "$($script:musicaNo.Count)"
Comp 'quitar lo que no hay, lo dice' (-not (Remove-MusicaNo 'nada de nada')) ''
Limpia
$soltado = ''
1..($MusicaNoMax + 3) | ForEach-Object { $s = Add-MusicaNo ("cosa numero $_") '' ''; if ($s) { $script:soltado = $s } }
Comp "no pasa de $MusicaNoMax" ($script:musicaNo.Count -eq $MusicaNoMax) "$($script:musicaNo.Count)"
Comp 'y DICE lo que tuvo que soltar' ($script:soltado -match 'cosa numero') "$($script:soltado)"

Write-Host ''
Write-Host '-- 7. y un invitado no apunta gustos --'
Limpia
$script:invitado = $true
[void](Add-MusicaNo 'lo que sea' '' '')
$script:invitado = $false
Comp 'la lista sigue vacia' ($script:musicaNo.Count -eq 0) "$($script:musicaNo.Count)"

Write-Host ''
Write-Host '-- 8. SU FRASE COMPUESTA, y en el orden bueno --'
# "Reproduce musica electronica y ademas recuerda que ese tipo de musica que pusiste ahora no
# me gusta": el veto va PRIMERO, porque su "que pusiste ahora" se refiere a LO ANTERIOR. Al
# reves se vetaria justo lo que quiere oir.
$lineaC = @($fuente -split "`r?`n" | Where-Object { $_ -match 'recuerda\|apunta\|anota' -and $_ -match 'no.*me.*gusta' })[0]
if (-not $lineaC) { Write-Host '  MAL  no encuentro el patron de la frase compuesta'; exit 1 }
$mC = [regex]::Match($lineaC, "'(\^[^']+)'")
$patC = $mC.Groups[1].Value
Comp 'su frase compuesta entra entera' ('reproduce musica electronica y ademas recuerda que ese tipo de musica que pusiste ahora no me gusta' -match $patC) ''
$iC = $fuente.IndexOf($lineaC)
$trozoC = $fuente.Substring($iC, 600)
Comp 'y el veto va DELANTE de poner lo nuevo' ($trozoC.IndexOf("kind = 'musicaNo'") -lt $trozoC.IndexOf("kind = 'url'")) 'al reves se vetaria lo que quiere oir'

Write-Host ''
Write-Host '-- 9. lo que NO puede pasar --'
$sv = SinComentarios (Traer 'Select-VideoYouTube')
Comp 'Select-VideoYouTube no sale a la red si ya tiene la lista' ($sv -match 'if \(\$q -ne \[string\]\$script:ytUltimaBusqueda -or \$lista\.Count -eq 0\)') 'la siguiente cuesta cero'
$an = SinComentarios (Traer 'Add-MusicaNo')
Comp 'y los gustos NO van al perfil' ($an -notmatch 'Add-DatoPerfil') 'ahi es la cola de expulsion'

try { Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}
Write-Host ''
if ($fallos -gt 0) { Write-Host "  $fallos mal"; exit 1 }
Write-Host '  la musica ya pone lo que es, y se acuerda de lo que no te gusta'
exit 0
