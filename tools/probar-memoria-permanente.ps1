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
foreach ($f in @('ConvertTo-Plain', 'Write-Atomico', 'Add-PerfilTodo', 'Get-PerfilTodo', 'Find-PerfilTodo')) {
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
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que aprende ya no se pierde, y sigue sin viajar'
exit 0
