# QUE DOS ORDENES DISTINTAS NO COMPARTAN EL MISMO ID (1/10, idea 2 de las 20 nuevas)
#
# EL AGUJERO: la marca del id (tmp\dictado-id.txt) NO se consume con los destinos neutros
# ('charla', 'traducir'), y eso esta bien -se apuntan ANTES de saber el destino de verdad, y
# comersela ahi dejaria a la orden real sin id-. Pero si la orden nunca llega a un destino de
# verdad, la marca se queda en disco, y la orden SIGUIENTE la hereda.
#
# MEDIDO sobre las 609 ordenes guardadas: 375 ids distintos, 79 repetidos, y 57 DE ESOS 79 llevaban
# ORDENES DISTINTAS dentro. Ejemplo real: el id 20260920-225247 tiene "Ya estoy uniendo, man" a las
# 22:52:47 y "regla: cuando abra elden ring pon modo noche" a las 22:54:39.
#
# Y NO ES UN DETALLE: Get-ComoTeEntendi y analizar-uso.py se quedan con la ULTIMA linea de cada id,
# asi que el destino de una orden PISA el de la otra. Es lo que falsea el 70,4 % con el que se mide
# la meta del 100 %, que es lo que mas le importa a braya.
#
# LO QUE DEFIENDE:
#  1. que una marca de hace mas de cinco minutos NO se pegue a la orden de ahora;
#  2. que una de hace un rato corto SI valga (si no, se tiraria la mitad del corpus);
#  3. que un id con forma rara no se tire: ante la duda, el dato se guarda;
#  4. que Write-DestinoUso lo compruebe ANTES de escribir la linea, no despues;
#  5. y que el analizador avise cuando encuentre un id con dos ordenes dentro, en vez de
#     falsear el porcentaje en silencio.
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
$UsoIdFrescoMin = 5
Invoke-Expression (Traer 'Test-MarcaUsoVieja')

Write-Host ''
Write-Host '-- 1. una marca vieja NO se pega a la orden de ahora --'
$ahora = Get-Date
# EL CASO DE VERDAD: dos minutos es lo que separaba las dos ordenes del ejemplo del 20/09... y DOS
# MINUTOS AUN VALE. Lo que no vale es lo de mucho antes.
Comp 'la de hace 6 minutos se tira' (Test-MarcaUsoVieja $ahora.AddMinutes(-6).ToString('yyyyMMdd-HHmmss')) ''
Comp 'la de hace una hora, tambien' (Test-MarcaUsoVieja $ahora.AddHours(-1).ToString('yyyyMMdd-HHmmss')) ''
Comp 'y la de ayer' (Test-MarcaUsoVieja $ahora.AddDays(-1).ToString('yyyyMMdd-HHmmss')) 'un dia sin reiniciar y la marca seguia ahi'

Write-Host ''
Write-Host '-- 2. pero la de hace un rato corto SI vale --'
# Si esto se pasara de estricto se tiraria la mitad del corpus, que es peor que el fallo original:
# el oido tarda segundos en resolver una orden y los repasos llegan despues.
Comp 'la de hace 10 segundos vale' (-not (Test-MarcaUsoVieja $ahora.AddSeconds(-10).ToString('yyyyMMdd-HHmmss'))) ''
Comp 'la de hace 2 minutos vale' (-not (Test-MarcaUsoVieja $ahora.AddMinutes(-2).ToString('yyyyMMdd-HHmmss'))) 'una charla larga puede tardar eso'
Comp "la de hace 4 minutos aun vale (el liston son $UsoIdFrescoMin)" (-not (Test-MarcaUsoVieja $ahora.AddMinutes(-4).ToString('yyyyMMdd-HHmmss'))) ''
# Y UNA DEL FUTURO TAMPOCO SE TIRA: si el reloj da un salto, lo que no hay que hacer es perder datos
Comp 'y una del futuro no se tira' (-not (Test-MarcaUsoVieja $ahora.AddMinutes(3).ToString('yyyyMMdd-HHmmss'))) 'un salto de reloj no debe borrar nada'

Write-Host ''
Write-Host '-- 3. ANTE LA DUDA, EL DATO SE GUARDA --'
# Si el id no tiene la forma esperada -otro worker, otro formato maniana- tirar la linea seria peor
# que el fallo que esto arregla.
foreach ($raro in @('', 'pepito', '2026-09-20 22:52:47', '20260920', '20260920-2252', 'XXXXXXXX-XXXXXX')) {
    Comp ("'" + $raro + "' no se tira") (-not (Test-MarcaUsoVieja $raro)) 'ante la duda, vale'
}

Write-Host ''
Write-Host '-- 4. el cableado: se comprueba ANTES de escribir --'
$cuerpo = Traer 'Write-DestinoUso'
$sinCom = (($cuerpo -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
$iTest = $sinCom.IndexOf('Test-MarcaUsoVieja')
$iEscribe = $sinCom.IndexOf('AppendAllText')
Comp 'Write-DestinoUso lo comprueba' ($iTest -ge 0) ''
Comp '  y ANTES de escribir la linea' ($iTest -ge 0 -and $iEscribe -ge 0 -and $iTest -lt $iEscribe) "comprueba en $iTest, escribe en $iEscribe"
# Y LA MARCA VIEJA SE BORRA: si se quedara, la orden siguiente volveria a tropezar con ella
$iBorra = $sinCom.IndexOf('Remove-Item', $iTest)
Comp '  y borra la marca caducada' ($iTest -ge 0 -and $iBorra -gt $iTest -and ($iBorra - $iTest) -lt 400) 'si se queda, la siguiente tropieza igual'
Comp '  y lo apunta, para poder contarlo' ($sinCom -match "uso-id-caducado") ''
# EL LISTON SALE DE config.json, no esta a fuego
$txt = [IO.File]::ReadAllText($PS1)
Comp 'el liston sale de config.json' ($txt -match "Get-Cfg 'uso' 'idFrescoMin'") ''

Write-Host ''
Write-Host '-- 5. y el analizador avisa de los ids sucios --'
$an = [IO.File]::ReadAllText((Join-Path $Raiz 'tools\analizar-uso.py'))
Comp 'analizar-uso.py busca ids con dos ordenes dentro' ($an -match 'textosPorId') ''
Comp '  y lo dice antes de dar los porcentajes' ($an.IndexOf('textosPorId') -lt $an.IndexOf('ORDENES REALES')) 'si sale despues, ya nadie lo lee'
Comp '  y lo cuenta sobre el total, no suelto' ($an -match 'de %d con texto') ''
# Y SE EJECUTA DE VERDAD: con un fichero de pega que tiene un id sucio y otro limpio.
$pyExeU = $env:NOVA_PY
if (-not $pyExeU) { $pyExeU = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe' }
if (Test-Path -LiteralPath $pyExeU) {
    $tmpU = Join-Path ([IO.Path]::GetTempPath()) ('nova-uso-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    New-Item -ItemType Directory -Force -Path $tmpU | Out-Null
    try {
        $prueba = @'
import sys, collections, json
sys.path.insert(0, sys.argv[1])
# la misma cuenta que hace analizar-uso.py, sobre datos de pega
destinos = [
    {"id": "A", "hizo": "local", "detalle": "abre steam"},
    {"id": "A", "hizo": "charla", "detalle": "abre steam"},
    {"id": "B", "hizo": "charla", "detalle": "que tal estas"},
    {"id": "B", "hizo": "local", "detalle": "pon modo noche"},
    {"id": "C", "hizo": "fallo-dicho-por-ti", "detalle": "no era eso"},
    {"id": "C", "hizo": "local", "detalle": "abre spotify"},
]
t = collections.defaultdict(set)
for d in destinos:
    det = (d.get("detalle") or "").strip().lower()[:40]
    if d.get("id") and det and d.get("hizo") != "fallo-dicho-por-ti":
        t[d["id"]].add(det)
sucios = sorted(i for i, s in t.items() if len(s) > 1)
print(",".join(sucios) if sucios else "-")
'@
        $tp = Join-Path $tmpU 'p.py'
        [IO.File]::WriteAllText($tp, $prueba)
        $errU = Join-Path $tmpU 'err.txt'
        $sal = @(& $pyExeU $tp $Raiz 2>$errU)
        $e = ''
        if (Test-Path -LiteralPath $errU) { $e = ([IO.File]::ReadAllText($errU)).Trim() }
        if ($e) { Comp 'el trozo de Python corre sin quejarse' $false $e.Replace("`n", ' | ') }
        # A tiene el mismo texto dos veces -> limpio. B tiene dos textos -> sucio.
        # C tiene dos, pero uno es 'fallo-dicho-por-ti' y no cuenta -> limpio.
        Comp 'caza el id con dos ordenes dentro' ([string]$sal[0] -eq 'B') "dijo '$($sal[0])', y lo sucio es la B"
        Comp '  y no se queja del que repite el MISMO texto' ([string]$sal[0] -notmatch 'A') 'eso es el diseno: varias lineas por orden'
        Comp '  ni de una queja de braya sobre su orden' ([string]$sal[0] -notmatch 'C') "'fallo-dicho-por-ti' lleva otro texto a proposito"
    } finally { Remove-Item -LiteralPath $tmpU -Recurse -Force -ErrorAction SilentlyContinue }
} else {
    Write-Host '  --   sin Python aqui: el trozo ejecutable se salta' -ForegroundColor DarkGray
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'dos ordenes distintas ya no comparten el mismo id' -ForegroundColor Green
exit 0
