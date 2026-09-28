# LO QUE NOVA SABE DE BRAYA NO PUEDE ACABAR EN UN REPOSITORIO PUBLICO (26/09, idea 1 de 121).
#
# El .gitignore de esta casa lista los ficheros de memoria\ UNO A UNO, a mano. Eso funciona
# mientras alguien se acuerde, y la prueba de que no se acuerda esta escrita en el propio
# fichero: tres veces dice "se me escapo" -perfil-todo.md y perfil-caidos.md el 25/09,
# uso-ally.json el 25/09-. Treinta y seis commits han tocado ese fichero.
#
# MEDIDO EL 26/09: el codigo puede crear 37 ficheros distintos en memoria\ y TRES no estaban
# cubiertos: logros-stamp.json (cuando juega y que logros saca), montajes.json (sus montajes de
# ventanas, con las URL que visita) y palabras-no.json (las palabras que no aguanta que le
# digan). Ninguno existia aun en disco, o sea que no se habia colado todavia: el proximo
# "git add -A" despues de usar esas funciones los habria metido.
#
# Y DE LOS 189 BANCOS DE tools\, NINGUNO MIRABA ESTO. Por eso existe este.
#
# QUE COMPRUEBA, y son dos redes distintas a proposito:
#   1. LO QUE EL CODIGO PUEDE ESCRIBIR: las 37 rutas Join-Path $MemoriaDir '...' de assistant.ps1.
#      Coge los ficheros que todavia no existen, que son los peligrosos -nadie los ve venir-.
#   2. LO QUE YA HAY EN DISCO bajo memoria\. Coge lo que escriben los workers de Python, que
#      construyen sus rutas con variables y no con literales, asi que la red 1 no los ve.
# Lo rastreado a proposito (hoy solo memoria\README.md) no cuenta: si git ya lo sigue, es
# porque alguien decidio que fuera asi.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PowerShell 5.1 con -File sale con codigo 0 aunque el
# script muera a mitad, asi que morir en silencio se daba por bueno.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}

# SIN GIT NO HAY NADA QUE COMPROBAR, y eso NO es un fallo del codigo: Nova se puede copiar a
# otro PC sin repositorio (ver NOVA-EN-OTRO-PC.md) y alli esta comprobacion no significa nada.
Push-Location $raiz
$hayGit = $false
try {
    $null = & git rev-parse --is-inside-work-tree 2>$null
    $hayGit = ($LASTEXITCODE -eq 0)
} catch { $hayGit = $false }
if (-not $hayGit) {
    Pop-Location
    Write-Host '  (no hay repositorio git aqui: no hay nada que se pueda escapar)'
    Write-Host '  lo que Nova sabe de braya se queda fuera del repositorio'
    exit 0
}

Write-Host '-- 1. lo que el codigo PUEDE escribir en memoria\ --'
# LA VARIABLE TIENE QUE SER EXACTAMENTE $MemoriaDir: hay rutas de prueba en el archivo que usan
# otras carpetas ($pruebaDir), y contarlas seria un rojo falso.
$ps1 = Join-Path $raiz 'assistant.ps1'
$txt = [IO.File]::ReadAllText($ps1, [Text.Encoding]::UTF8)
$delCodigo = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($m in [regex]::Matches($txt, "Join-Path\s+\`$MemoriaDir\s+['`"]([A-Za-z0-9_.\\-]+)['`"]")) {
    [void]$delCodigo.Add($m.Groups[1].Value)
}
Comp 'se encuentran las rutas de memoria en el codigo' ($delCodigo.Count -ge 25) "$($delCodigo.Count) rutas distintas"

Write-Host ''
Write-Host '-- 2. lo que YA hay en disco --'
$memDir = Join-Path $raiz 'memoria'
$enDisco = @()
if (Test-Path -LiteralPath $memDir) {
    foreach ($f in @(Get-ChildItem -LiteralPath $memDir -Recurse -File -ErrorAction SilentlyContinue)) {
        $enDisco += $f.FullName.Substring($raiz.Length + 1).Replace('\', '/')
    }
}
Comp 'se ven los ficheros de memoria en disco' ($enDisco.Count -gt 0) "$($enDisco.Count) ficheros"

# LO QUE GIT YA SIGUE A PROPOSITO NO ES UN ESCAPE (hoy solo memoria\README.md)
$rastreados = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($l in @(& git ls-files memoria 2>$null)) { if ($l) { [void]$rastreados.Add($l.Trim()) } }

# LAS CARPETAS SE PRUEBAN CON UN FICHERO DENTRO, y esto costo un rojo falso (26/09). El
# .gitignore cubre las carpetas con barra final -"memoria/temas/", "memoria/notas-voz/"-, y un
# patron con barra SOLO casa si eso es un directorio DE VERDAD en disco. Como ninguna de las
# dos existe todavia, preguntar por "memoria/temas" a secas devolvia "no cubierta" y el banco
# cantaba dos escapes que no lo eran. Comprobado a mano: con la carpeta creada, "memoria/temas"
# casa con la linea 25; sin crearla no casa, pero "memoria/temas/prueba.md" SI casa igualmente.
# O sea que lo que de verdad importa -lo que Nova escribe DENTRO- esta cubierto siempre.
# Por eso una ruta sin extension se prueba como carpeta, que es lo que es.
$candidatas = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($r in $delCodigo) {
    $lim = 'memoria/' + $r.Replace('\', '/')
    if ($lim -notmatch '\.[A-Za-z0-9]{1,6}$') { $lim = $lim.TrimEnd('/') + '/lo-que-escriba-dentro' }
    [void]$candidatas.Add($lim)
}
foreach ($r in $enDisco) { [void]$candidatas.Add($r) }
$aMirar = @($candidatas | Where-Object { -not $rastreados.Contains($_) })

Write-Host ''
Write-Host '-- 3. y ninguna se escapa del .gitignore --'
# UNA SOLA LLAMADA A GIT, no una por fichero: resuelve las 40 de golpe en ~120 ms. Una llamada
# por ruta serian 40 procesos, y la regla 5 de la casa prohibe gastar lo que le hace falta al
# juego.
#
# Y POR ARGUMENTOS, NO POR --stdin, que fue lo primero que probe y salia MAL (26/09): al
# mandarle texto por la tuberia, PowerShell 5.1 le pega delante un BOM de UTF-8 y le cambia los
# finales de linea a CRLF, asi que git recibia "\357\273\277memoria/habitos.json\r" y no
# reconocia NINGUNA ruta: TODAS salian como no cubiertas. El banco habria cantado cuarenta
# escapes falsos, y a los dos dias nadie lo mira. Se ve en la salida de git, que entrecomilla
# los nombres con caracteres raros.
function SinCubrir([string[]]$rutas) {
    if (-not $rutas -or $rutas.Count -eq 0) { return @() }
    $salida = & git check-ignore --non-matching --verbose -- $rutas 2>$null
    $fuera = @()
    foreach ($l in @($salida)) {
        # las cubiertas salen como "fichero:linea:patron<TAB>ruta"; las NO cubiertas, como "::<TAB>ruta"
        if ($l -match '^::\s+(.+)$') { $fuera += $Matches[1].Trim() }
    }
    return $fuera
}
$sinCubrir = @(SinCubrir $aMirar)
Comp 'todo lo que Nova escribe en memoria esta ignorado' ($sinCubrir.Count -eq 0) $(
    if ($sinCubrir.Count) { "SE ESCAPAN: " + ($sinCubrir -join ', ') } else { "$($aMirar.Count) rutas comprobadas" })
if ($sinCubrir.Count -gt 0) {
    Write-Host ''
    Write-Host '       El repositorio es PUBLICO. Anade estas lineas al .gitignore:' -ForegroundColor Yellow
    foreach ($s in $sinCubrir) { Write-Host ("         " + $s) -ForegroundColor Yellow }
}

Write-Host ''
Write-Host '-- 4. y el detector detecta (si no, esto seria decoracion) --'
# LA UNICA FORMA DE SABER QUE ESTO FUNCIONA sin esperar a que se escape algo: se le pone
# delante una ruta que NO puede estar ignorada, y tiene que cazarla. Sin esta prueba, un
# check-ignore que devolviera siempre vacio dejaria el banco verde para siempre.
$inventada = 'memoria/no-existe-esto-jamas-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.secreto'
$pilla = @(SinCubrir @($inventada))
Comp 'una ruta sin cubrir se caza' ($pilla.Count -eq 1) "probando con $inventada"
# Y AL REVES: una que SI esta cubierta no puede salir como escape, o el banco daria rojos
# falsos por todo y nadie lo miraria a los tres dias.
$cubierta = @(SinCubrir @('memoria/habitos.json'))
Comp '  y una cubierta no da rojo falso' ($cubierta.Count -eq 0) 'memoria/habitos.json esta en el .gitignore'

Write-Host ''
Write-Host '-- 5. y Nova lo comprueba sola, no solo este banco --'
# ESTE BANCO SOLO PROTEGE SI ALGUIEN LO CORRE ANTES DE COMMITEAR, y braya commitea a mano. Por
# eso la misma comprobacion vive tambien en assistant.ps1. Aqui se comprueba que esta, que
# alguien la llama, y -lo que importa- que HACE lo que dice.
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ps1, [ref]$null, [ref]$null)
$defM = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Test-MemoriaIgnorada' }, $true)
Comp 'existe Test-MemoriaIgnorada' ($null -ne $defM) ''
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$llam = @([regex]::Matches($sinCom, '(?<!function )Test-MemoriaIgnorada')).Count
Comp '  y alguien la llama de verdad' ($llam -ge 1) "$llam llamada(s) fuera de su definicion"
Comp '  no toca git con un juego delante' ($defM -and $defM.Extent.Text -match 'juegoActivo') 'regla 5'
Comp '  una vez al dia como mucho' ($defM -and $defM.Extent.Text -match 'ignoradasMiradas') ''
# LO QUE NUNCA PUEDE HACER: quitar lineas del .gitignore ni commitear. Anadir, si.
# SIN LOS COMENTARIOS, que es la manera 1 de la casa (28/09). Esto miraba el texto ENTERO de la
# funcion, comentarios incluidos, asi que un comentario que explicase por que un commit de todo es
# peligroso ponia el caso en rojo con el codigo perfecto. Paso literalmente al documentar lo de
# memoria/juegos-fuera.json, que llevaba subido desde el 5cb104c.
$defMsc = (($defM.Extent.Text -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '  solo ANADE al .gitignore' ($defM -and $defMsc -match 'Add-Content' -and
                                   $defMsc -notmatch 'Set-Content' -and
                                   $defMsc -notmatch 'git\s+(commit|add)') 'nunca quita ni commitea'

# LA FUNCION, EJECUTADA DE VERDAD sobre un repositorio de mentira (manera 14: se doblan las
# dependencias -por donde sale la voz y de donde salen las rutas-, no la pieza que se prueba).
$tmpR = Join-Path ([IO.Path]::GetTempPath()) ('nova-gi-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path (Join-Path $tmpR 'memoria') | Out-Null
Push-Location $tmpR
try {
    & git init -q 2>$null
    Set-Content -LiteralPath (Join-Path $tmpR '.gitignore') -Value @('memoria/tapado.json') -Encoding UTF8
    # un "assistant.ps1" de mentira con dos rutas: una cubierta y otra no
    $falso = Join-Path $tmpR 'falso.ps1'
    Set-Content -LiteralPath $falso -Encoding UTF8 -Value @(
        '$a = Join-Path $MemoriaDir ''tapado.json''',
        '$b = Join-Path $MemoriaDir ''se-escapa.json''')
    $script:juegoActivo = $false
    $script:avisos = @()
    function Log([string]$m) { }
    function Send-AvisoEntorno([string]$clave, [string]$texto, [string]$nivel = 'medio', [int]$cadaMin = 60, [bool]$ya = $false) {
        $script:avisos += @{ clave = $clave; texto = $texto; nivel = $nivel }; return $true
    }
    Invoke-Expression $defM.Extent.Text
    # POR PARAMETRO, no por $PSCommandPath: esa variable es automatica y la funcion sacada del
    # arbol seguia viendo la de verdad, asi que la primera version de esta prueba media el
    # assistant.ps1 REAL contra un .gitignore de mentira. Por eso la funcion los admite.
    $r1 = Test-MemoriaIgnorada $falso $tmpR
    $gi = Get-Content -LiteralPath (Join-Path $tmpR '.gitignore') -Raw
    Comp 'con una ruta sin cubrir, la tapa' ($r1 -and $gi -match 'se-escapa\.json') 'la anadio al .gitignore'
    Comp '  y no toca la que ya estaba' (@([regex]::Matches($gi, 'tapado\.json')).Count -eq 1) 'nunca quita ni duplica'
    Comp '  y lo dice' ($script:avisos.Count -eq 1 -and $script:avisos[0].nivel -ne 'bajo') "nivel '$(if($script:avisos.Count){$script:avisos[0].nivel})'"
    # SEGUNDA PASADA EL MISMO DIA. Y AQUI HAY QUE TENER CUIDADO (26/09, lo cazo una rotura de
    # este mismo banco): llamarla otra vez a secas NO prueba el freno. Despues de la primera
    # pasada el .gitignore ya cubre todo, asi que la segunda devuelve false por no encontrar
    # nada, con freno o sin el. Borrando la linea del freno, el banco seguia verde: la prueba
    # pasaba por la razon equivocada, que es la manera 16 de salir verde mintiendo.
    # Lo que si lo prueba: meter una ruta NUEVA sin cubrir entre las dos llamadas. Con freno,
    # la segunda no la ve hasta manana; sin freno, la taparia ahora mismo.
    Add-Content -LiteralPath $falso -Encoding UTF8 -Value "`$c = Join-Path `$MemoriaDir 'aparece-luego.json'"
    $script:avisos = @()
    $r2 = Test-MemoriaIgnorada $falso $tmpR
    $gi2 = Get-Content -LiteralPath (Join-Path $tmpR '.gitignore') -Raw
    Comp '  y no lo repite el mismo dia' ((-not $r2) -and $script:avisos.Count -eq 0 -and
                                          $gi2 -notmatch 'aparece-luego') 'con una ruta nueva delante, espera a manana'
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmpR -Recurse -Force -ErrorAction SilentlyContinue
}

Pop-Location
Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que Nova sabe de braya se queda fuera del repositorio'
exit 0
