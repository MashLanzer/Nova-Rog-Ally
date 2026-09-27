# LA MEMORIA QUE NO SE BORRA (25/09)
#
# LO QUE PIDIO BRAYA, con sus palabras: "haz una memoria permanente que guarde todo y no se
# mande al cerebro, y esta de 60 que siga asi, o sea temporal".
#
# POR QUE TIENE RAZON, medido: el perfil de 60 es lo que VIAJA. Su propio comentario lo dice,
# "va con CADA peticion al cerebro": 60 lineas son 2.603 caracteres, unos 723 tokens, y en
# quince dias hubo 186 peticiones a Claude. Por eso tiene tope y por eso la poda tira cosas.
# Se han aprendido 91 datos y quedan 60; entre los caidos estan los DOS UNICOS que braya
# enseno a mano ("mi juego favorito es Hollow Knight", "mi color favorito es el verde").
#
# LA SEPARACION QUE ESTE BANCO PROTEGE, y es la razon de ser de todo esto:
#   - perfil.md      -> 60 plazas, VIAJA en cada peticion. Sigue igual.
#   - perfil-todo.md -> sin tope, NO VIAJA NUNCA. Solo se abre cuando braya pregunta.
# La seccion 3 es la que de verdad importa: comprueba que el fichero permanente NO aparece en
# ninguno de los caminos por los que algo puede acabar en el modelo. Si un dia alguien lo mete
# "para que Nova sepa mas", el coste por consulta se multiplica y nadie se entera.
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

Write-Host '-- 1. las dos memorias existen y son distintas --'
Comp 'el perfil que viaja sigue con su tope' ($sinCom -match '\$PerfilMax\s*=\s*60') 'no se toca: es lo que se manda'
Comp 'y existe la memoria permanente' ($sinCom -match '\$PerfilTodoPath\s*=') ''
Comp 'con su propio fichero' ($sinCom -match 'perfil-todo\.md') ''
Comp 'se puede anadir' ($sinCom -match 'function Add-PerfilTodo') ''
Comp 'se puede leer entera' ($sinCom -match 'function Get-PerfilTodo') ''
Comp 'y se puede buscar dentro' ($sinCom -match 'function Find-PerfilTodo') 'para "que sabes de mi sobre X"'

Write-Host ''
# UN BLOQUE VACIO NO PRUEBA NADA (25/09). Estas comprobaciones son en negativo -"que NO
# aparezca X"- y con la funcion todavia sin escribir el trozo sale vacio y pasan solas.
# Por eso cada una exige primero que el bloque exista. Lo cazo correr el banco antes de
# implementar nada, que es justo para lo que se corre antes.
Write-Host '-- 2. y la permanente NO tiene tope --'
$iA = $sinCom.IndexOf('function Add-PerfilTodo')
$blA = if ($iA -gt 0) { $sinCom.Substring($iA, [Math]::Min(1400, $sinCom.Length - $iA)) } else { '' }
Comp 'Add-PerfilTodo no recorta por PerfilMax' ($blA -and -not ($blA -match 'PerfilMax')) 'si recortara, volveria a perder cosas'
Comp 'ni por ningun otro numero' ($blA -and -not ($blA -match '\$l\[\(\$l\.Count')) 'ese es el patron de recorte del perfil'
$iC = $sinCom.IndexOf('function Add-PerfilCaido')
$blC = if ($iC -gt 0) { $sinCom.Substring($iC, [Math]::Min(1100, $sinCom.Length - $iC)) } else { '' }
Comp 'la lapida tambien pierde su tope' ($blC -and -not ($blC -match 'PerfilMax')) 'lo ya olvidado no debe volver a olvidarse'

Write-Host ''
Write-Host '-- 3. LO QUE IMPORTA: la permanente NO VIAJA al modelo --'
$iS = $sinCom.IndexOf('function Get-SistemaCerebro')
$blS = if ($iS -gt 0) { $sinCom.Substring($iS, [Math]::Min(2500, $sinCom.Length - $iS)) } else { '' }
Comp 'no entra en el prompt del cerebro' ($blS -and -not ($blS -match 'PerfilTodo')) 'Get-SistemaCerebro'
Comp 'y ese prompt sigue llevando el perfil normal' ($blS -match 'Get-DatosPerfil') 'lo de siempre no se rompe'
$iW = $sinCom.IndexOf('$CharlaWorker')
$blW = if ($iW -gt 0) { $sinCom.Substring($iW, [Math]::Min(2500, $sinCom.Length - $iW)) } else { '' }
Comp 'no se le pasa al worker de la charla' ($blW -and -not ($blW -match 'PerfilTodoPath')) 'ahi solo va perfil.md'
$py = Join-Path $Raiz 'charla_worker.py'
if (Test-Path -LiteralPath $py) {
    $t = [IO.File]::ReadAllText($py)
    Comp 'el worker de la charla no lo nombra' (-not ($t -match 'perfil-todo')) ''
}

Write-Host ''
Write-Host '-- 4. se guarda lo que se aprende, y con las guardas de siempre --'
$iD = $sinCom.IndexOf('function Add-DatoPerfil')
$blD = if ($iD -gt 0) { $sinCom.Substring($iD, [Math]::Min(9000, $sinCom.Length - $iD)) } else { '' }
Comp 'cada dato aprendido va tambien a la permanente' ($blD -match 'Add-PerfilTodo') ''
Comp 'Add-PerfilTodo lleva la guarda de invitado' ($blA -match '\$script:invitado') 'con otro delante no se aprende nada'
Comp 'y no guarda vacios' ($blA -match 'if \(-not \$dato\)') ''
Comp 'y no repite lo mismo dos veces' ($blA -match 'ConvertTo-Plain') 'el mismo dato se reaprende cada vez que lo repites'
Comp 'se siembra al arrancar' ($sinCom -match 'Initialize-PerfilTodo') 'para no nacer vacia con 60 datos ya dentro'
$iI = $sinCom.IndexOf('function Initialize-PerfilTodo')
$blI = if ($iI -gt 0) { $sinCom.Substring($iI, [Math]::Min(700, $sinCom.Length - $iI)) } else { '' }
Comp 'y la siembra solo actua si no existe' ($blI -match 'Test-Path -LiteralPath \$PerfilTodoPath') 'no pisa lo que ya haya'

Write-Host ''
Write-Host '-- 5. LAS FUNCIONES, SACADAS DEL ARCHIVO Y EJECUTADAS --'
$faltan = 0
foreach ($f in @('ConvertTo-Plain', 'Write-Atomico', 'Get-DatoSinCola', 'Add-PerfilTodo', 'Get-PerfilTodo', 'Find-PerfilTodo')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    if (-not $d) { Comp ("se encuentra " + $f) $false ''; $faltan++; continue }
    Invoke-Expression $d.Extent.Text
}
if ($faltan -gt 0) {
    Write-Host ''
    Write-Host "  $mal MAL"
    exit 1
}
# LOS DOBLES, DESPUES DE CARGAR (manera 9): definirlos antes los pisa el archivo al cargarse.
function Log([string]$m) { }
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-perm-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $script:invitado = $false
    $PerfilTodoPath = Join-Path $tmp 'perfil-todo.md'

    Add-PerfilTodo 'braya juega a Hollow Knight' 'a mano'
    Add-PerfilTodo 'braya tiene un gato' 'charla'
    Comp 'guarda lo que se le da' ((@(Get-PerfilTodo)).Count -eq 2) "$((@(Get-PerfilTodo)).Count)"

    Add-PerfilTodo 'braya juega a Hollow Knight' 'charla'
    Comp 'y no lo repite' ((@(Get-PerfilTodo)).Count -eq 2) "$((@(Get-PerfilTodo)).Count) tras reaprender el mismo"
    Add-PerfilTodo 'BRAYA JUEGA A HOLLOW KNIGHT' 'charla'
    Comp 'ni con otras mayusculas' ((@(Get-PerfilTodo)).Count -eq 2) "$((@(Get-PerfilTodo)).Count)"

    # EL TOPE: se meten muchos mas de 60 y tienen que estar TODOS
    for ($i = 1; $i -le 80; $i++) { Add-PerfilTodo ("dato numero " + $i + " de prueba") 'banco' }
    $n = (@(Get-PerfilTodo)).Count
    Comp 'pasa de 60 sin perder nada' ($n -eq 82) "$n (2 + 80)"
    Comp 'y el primero sigue estando' (@(Get-PerfilTodo)[0] -match 'Hollow Knight') 'es lo que se perdia antes'

    Comp 'y se puede buscar dentro' ((@(Find-PerfilTodo 'hollow')).Count -eq 1) ''
    Comp 'buscando en mayusculas tambien' ((@(Find-PerfilTodo 'GATO')).Count -eq 1) ''
    Comp 'y una busqueda corta no devuelve media memoria' ((@(Find-PerfilTodo 'a')).Count -eq 0) 'menos de 3 letras, nada'

    # LA GUARDA DEL INVITADO, de verdad
    $antes = (@(Get-PerfilTodo)).Count
    $script:invitado = $true
    Add-PerfilTodo 'esto lo dijo otra persona' 'charla'
    $script:invitado = $false
    Comp 'con un invitado delante no guarda nada' ((@(Get-PerfilTodo)).Count -eq $antes) "$antes -> $((@(Get-PerfilTodo)).Count)"
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}


Write-Host ''
Write-Host '-- 6. LA PUERTA QUE LE FALTABA (27/09, idea 63) --'
# Tenia 64 datos y CERO llamadores: Get-PerfilTodo y Find-PerfilTodo existian y no las usaba
# nadie en 31.000 lineas, asi que los 31 datos que ya no estan en el perfil no habia forma
# humana de sacarlos. Ahora hay dos puertas, las dos EN LOCAL para no romper la seccion 3:
# una frase que pregunta a proposito, y la busqueda en la memoria que ya contestaba sin modelo.
Comp 'hay una frase que la abre' ($sinCom -match 'perfilBusca') 'que sabes de mi sobre X'
$iFC = $sinCom.IndexOf("kind = 'perfilBusca'")
Comp 'con cola, para que no pise a "que sabes de mi" a secas' ($iFC -gt 0 -and $sinCom.Substring([Math]::Max(0,$iFC-320), 320) -match [regex]::Escape('(?:sobre|de|acerca de|respecto a|en cuanto a) (.+)$')) ''
$iAc = $sinCom.IndexOf("'perfilBusca' {")
$blAc = if ($iAc -gt 0) { $sinCom.Substring($iAc, [Math]::Min(1800, $sinCom.Length - $iAc)) } else { '' }
Comp 'y la accion lee de verdad la permanente' ($blAc -match 'Find-PerfilTodo') ''
Comp 'y no manda sus datos al registro' ($blAc -match 'respuestaPrivada') 'son cosas suyas'
$iFM = $sinCom.IndexOf('function Find-EnMemoria')
$blFM = if ($iFM -gt 0) { $sinCom.Substring($iFM, [Math]::Min(2600, $sinCom.Length - $iFM)) } else { '' }
Comp 'la busqueda en la memoria tambien la mira' ($blFM -and $blFM -match 'Get-PerfilTodo') 'antes de decir que no sabe'
Comp 'y sigue siendo en local, sin modelo' ($blFM -and -not ($blFM -match 'Send-Charla|Submit-Command')) 'lo que pidio braya'

Write-Host ''
Write-Host '-- 7. Y FUNCIONANDO DE VERDAD, no solo escrito --'
$faltan2 = 0
foreach ($f in @('Get-Distancia', 'Get-PuntosClaves', 'Find-EnMemoria')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    if (-not $d) { Comp ('se encuentra ' + $f) $false ''; $faltan2++; continue }
    Invoke-Expression $d.Extent.Text
}
if ($faltan2 -gt 0) { Write-Host ''; Write-Host "  $mal MAL"; exit 1 }
$tmp2 = Join-Path ([IO.Path]::GetTempPath()) ('nova-perm2-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp2 -Force | Out-Null
try {
    $script:invitado = $false
    $PerfilTodoPath = Join-Path $tmp2 'perfil-todo.md'
    # LOS DOS PATRONES, SACADOS DEL ARCHIVO Y EJECUTADOS (no mirados: ejecutados). Si el de la
    # cola se escribiera mal, el de abajo -anclado ^...$- se lo comeria y la frase acabaria en el
    # modelo sin que nadie lo notase.
    $patBusca = ''; $patTodo = ''
    foreach ($linea in ($txt -split "`n")) {
        if (-not $patBusca -and $linea -match "if \(\`$f -match '(\^\(\?:que sabes\|que tienes anotado.+?)'\)") { $patBusca = $Matches[1] }
        if (-not $patTodo -and $linea -match "if \(\`$f -match '(\^\(\?:que sabes de mi\|.+?)'\)") { $patTodo = $Matches[1] }
    }
    Comp 'el patron de la cola se encuentra en el archivo' ([bool]$patBusca) $patBusca
    Comp 'y el de "que sabes de mi" a secas tambien' ([bool]$patTodo) ''
    if ($patBusca -and $patTodo) {
        Comp '"que sabes de mi sobre mi gato" entra por la puerta nueva' ('que sabes de mi sobre mi gato' -match $patBusca) ''
        $colaV = if ('que sabes de mi sobre mi gato' -match $patBusca) { $Matches[1] } else { '' }
        Comp 'y la cola que saca es lo que se busca' ($colaV -eq 'mi gato') "'$colaV'"
        Comp 'y esa frase NO la coge el de a secas' (-not ('que sabes de mi sobre mi gato' -match $patTodo)) 'si la cogiera, contestaria el perfil entero'
        Comp '"que sabes de mi" sigue yendo al de siempre' ('que sabes de mi' -match $patTodo) ''
        Comp 'y NO entra por la puerta nueva' (-not ('que sabes de mi' -match $patBusca)) 'sin cola no hay que buscar'
        Comp '"que tienes apuntado de mi sobre el verde" tambien entra' ('que tienes apuntado de mi sobre el verde' -match $patBusca) ''
    }
    # el dato de verdad que nadie podia sacar: la mascota
    Add-PerfilTodo 'tiene un gato o mascota llamada Meramiau' 'charla'
    Add-PerfilTodo 'su color favorito es el verde' 'a mano'
    # sin notas ninguna: lo que salga sale de la permanente y de ningun otro sitio
    $MemoriaDir = Join-Path $tmp2 'memoria-vacia'
    $DiarioDir = Join-Path $tmp2 'diario-vacio'
    $r1 = Find-EnMemoria 'que sabes de mi gato'
    Comp 'preguntando por el gato, lo encuentra' ($r1 -and $r1 -match 'Meramiau') "$r1"
    Comp 'y dice de donde sale' ($r1 -match 'De ti tengo apuntado') "$r1"
    # EL CASO NEGATIVO (manera 16): una pregunta de otra cosa no puede devolver su mascota
    $r2 = Find-EnMemoria 'que te dije del medico'
    Comp 'y a una pregunta de otra cosa no le saca nada' (-not $r2) "$r2"
    # Y SIN FICHERO, que es como esta el dia que se estrena en otro PC: ni se rompe ni inventa
    $PerfilTodoPath = Join-Path $tmp2 'no-existe.md'
    $r3 = Find-EnMemoria 'que sabes de mi gato'
    Comp 'sin fichero permanente no se rompe y no devuelve nada' (-not $r3) "$r3"
} finally {
    Remove-Item -LiteralPath $tmp2 -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que aprende ya no se pierde, y sigue sin viajar'
exit 0
