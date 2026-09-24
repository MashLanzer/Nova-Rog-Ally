# Pruebas del autoaprendizaje: recetas, otras formas de decirlas, la coletilla
# tras la coma, el perfil en el prompt del cerebro, el balance ("cuanto has
# aprendido") y la celebracion de la capsula. Antes eran pruebas sueltas del
# 13/09; ahora pasan con probar-todo.
#
# Trabaja en una carpeta temporal propia (nunca en memoria\) y la borra al acabar.
#
#   powershell -NoProfile -File tools\probar-recetas.ps1
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$ErrorActionPreference = 'Continue'
$ruta = Join-Path (Split-Path -Parent $PSScriptRoot) 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$null)
function TraerFn($n) {
    $f = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $f) { throw "falta la funcion $n en assistant.ps1" }
    return $f.Extent.Text
}
$top = $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] }
# RE_DATO_SENSIBLE ENTRA AQUI DESDE EL 21/09. No estaba, y Add-DatoPerfil lo usa: sin
# el, la comparacion era '$d -match $null', o sea -match con patron VACIO, que en
# PowerShell casa con CUALQUIER texto. Resultado: 'lo sensible no se guarda' salia en
# verde porque se rechazaba TODO, incluido lo que si hay que guardar. Una prueba que
# aprueba pase lo que pase es peor que no tenerla: dice que algo esta cubierto y no lo
# esta. Es la misma regla de siempre: lo que se llama, se trae.
foreach ($a in $top) { if (@('RE_RECETA_PROHIBIDO', 'RecetasMax', 'NIVELES_NOVA', 'RE_DATO_SENSIBLE', 'PerfilMax') -contains $a.Left.VariablePath.UserPath) { Invoke-Expression $a.Extent.Text } }
foreach ($n in 'ConvertTo-Plain', 'ConvertTo-CmdArg', 'ConvertTo-Suave', 'Get-PatronReceta', 'Find-Receta', 'Find-RecetaIncompleta','Test-ScriptProhibido', 'Get-TextoReceta',
    'Add-Receta', 'Invoke-Receta', 'Get-Recetas', 'Save-Recetas', 'Get-VarianteReceta', 'Add-VarianteReceta', 'Build-PromptTraduccion',
    # Test-DatoTrato la trajo la idea 7 el 23/09 y Add-DatoPerfil la llama: sin ella este
    # banco moria a mitad, y hasta que se le puso el trap salia con codigo 0 y daba verde.
    'Get-DatosPerfil', 'Save-DatosPerfil', 'Test-DatoTrato', 'ConvertTo-Suave', 'Test-DatoPasajero', 'Add-DatoPerfil', 'Get-SistemaCerebro', 'Get-BalanceAprendizaje', 'Get-Estadisticas',
    'Send-UIEvento', 'Set-AcabaDeAprender', 'Get-CuentaAprendida', 'Get-Madurez', 'Get-FraseNivel', 'Write-Atomico',
    'Start-PasoScript', 'Complete-PasoScript', 'Start-Receta', 'Step-Receta', 'Watch-Receta', 'Close-Receta', 'Complete-RecetaResultado',
    'Test-ScriptSoloLectura', 'Format-VozInfo') { Invoke-Expression (TraerFn $n) }
# la lista blanca de la lectura, sacada del archivo real
$topCL = $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $_.Left.VariablePath.UserPath -eq 'CMDLETS_LECTURA' }
foreach ($a in $topCL) { Invoke-Expression $a.Extent.Text }

# --- RECETAS DE INFORMACION (16/09): solo lectura de verdad, y de los datos a la frase ---
# El 15/09, "que tengo en mi escritorio" costo 44 s de agente por no poder aprenderse.
$falloInfo = 0
function CompInfo($etq, $ok, $det) {
    Write-Host ("  {0}  {1,-52} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:falloInfo++ }
}
Write-Host "`n== Recetas de informacion: el script SOLO puede leer"
CompInfo 'listar el escritorio vale' (Test-ScriptSoloLectura 'Get-ChildItem (Join-Path $env:USERPROFILE "Desktop") | Measure-Object | ConvertTo-Json -Compress') ''
CompInfo 'leer el disco vale' (Test-ScriptSoloLectura 'Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, FreeSpace | ConvertTo-Json -Compress') ''
CompInfo 'crear un archivo NO' (-not (Test-ScriptSoloLectura 'New-Item -ItemType File x.txt')) ''
CompInfo 'borrar NO' (-not (Test-ScriptSoloLectura 'Remove-Item $env:USERPROFILE\Desktop\x.txt')) ''
CompInfo 'escribir con > NO' (-not (Test-ScriptSoloLectura 'Get-ChildItem > salida.txt')) ''
CompInfo 'llamar a un exe NO' (-not (Test-ScriptSoloLectura 'winget list')) ''
CompInfo 'arrancar un proceso NO' (-not (Test-ScriptSoloLectura 'Start-Process notepad')) ''
CompInfo 'bajar algo de internet NO' (-not (Test-ScriptSoloLectura 'Invoke-WebRequest http://x')) ''
CompInfo 'vacio NO' (-not (Test-ScriptSoloLectura '')) ''

Write-Host "`n== Recetas de informacion: de los datos a la frase"
$vozEsc = @{ modo = 'plantilla'; plantilla = 'En el escritorio tienes {cuantos|cosa|cosas}: {nombres}.'; vacio = 'No tienes nada en el escritorio.' }
$f1 = Format-VozInfo $vozEsc '{"cuantos":3,"nombres":["Games","Hola.txt","It Takes Two"]}'
CompInfo 'cuenta y enumera' ($f1 -eq 'En el escritorio tienes 3 cosas: Games, Hola.txt, It Takes Two.') "'$f1'"
$f2 = Format-VozInfo $vozEsc '{"cuantos":1,"nombres":["Games"]}'
CompInfo 'singular' ($f2 -eq 'En el escritorio tienes 1 cosa: Games.') "'$f2'"
$f3 = Format-VozInfo $vozEsc '{"cuantos":0,"nombres":[]}'
CompInfo 'si no hay nada, lo dice con su frase' ($f3 -eq 'No tienes nada en el escritorio.') "'$f3'"
$f4 = Format-VozInfo $vozEsc 'esto no es json'
CompInfo 'si el script devuelve basura, la frase de vacio' ($f4 -eq 'No tienes nada en el escritorio.') "'$f4'"
CompInfo 'sin plantilla, no dice nada' ((Format-VozInfo @{ modo = 'plantilla' } '{"a":1}') -eq '') ''
if ($falloInfo -gt 0) { Write-Host "  $falloInfo MAL en recetas de informacion" -ForegroundColor Red }

Write-Host "`n== Una receta de informacion, de punta a punta"
$dirI = Join-Path $env:TEMP ('nova-info-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dirI | Out-Null
# Start-PasoScript escribe su script en $TmpDir: TIENE que ser otra carpeta, o la
# receta se cuenta a si misma (la primera version listaba receta-xxx.ps1 y sus .txt)
$TmpDir = Join-Path $env:TEMP ('nova-info-tmp-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TmpDir | Out-Null
$WORKDIR = $TmpDir
New-Item -ItemType File -Path (Join-Path $dirI 'uno.txt') | Out-Null
New-Item -ItemType File -Path (Join-Path $dirI 'dos.txt') | Out-Null
$rInfo = @{
    id = 99; frase = 'que hay en la carpeta de prueba'; resumen = 'mirar la carpeta'; respuesta = ''
    pasos = @(@{ tipo = 'lectura'; texto = ('$i = @(Get-ChildItem -LiteralPath ''' + $dirI + ''' -File | Sort-Object Name); [pscustomobject]@{ cuantos = $i.Count; nombres = @($i | ForEach-Object { $_.Name }) } | ConvertTo-Json -Compress') })
    variantes = @(); tipo = 'info'
    voz = @{ modo = 'plantilla'; plantilla = 'Ahi tienes {cuantos|archivo|archivos}: {nombres}.'; vacio = 'Esa carpeta esta vacia.' }
}
$resI = Invoke-Receta $rInfo @{}
CompInfo 'se ejecuta y dice los datos' ($resI.ok -and $resI.texto -eq 'Ahi tienes 2 archivos: dos.txt, uno.txt.') "'$($resI.texto)'"
# y una que intenta tocar algo NO se ejecuta, aunque este escrita en el archivo
$rMala = @{ id = 98; frase = 'borra la carpeta de prueba'; resumen = 'x'; respuesta = ''
    pasos = @(@{ tipo = 'lectura'; texto = ('Remove-Item -Recurse -Force ''' + $dirI + '''') })
    variantes = @(); tipo = 'info'; voz = @{ modo = 'plantilla'; plantilla = 'ya'; vacio = 'nada' }
}
$resM = Invoke-Receta $rMala @{}
CompInfo 'un paso de lectura que toca algo NO se ejecuta' ((-not $resM.ok) -and (Test-Path $dirI)) "$($resM.error)"
Remove-Item -LiteralPath $dirI -Recurse -Force -ErrorAction SilentlyContinue
if ($falloInfo -gt 0) { Write-Host "  $falloInfo MAL en recetas de informacion" -ForegroundColor Red }

$dir = Join-Path $env:TEMP ('nova-recetas-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$RecetasOn = $true
$RecetasPath = Join-Path $dir 'recetas.json'
$PerfilPath = Join-Path $dir 'perfil.md'
$EstadisticasJson = Join-Path $dir 'estadisticas.json'
$TmpDir = $dir; $WORKDIR = $dir
$CcSistema = Join-Path (Split-Path -Parent $PSScriptRoot) 'cerebro-sistema.md'
# AQUI HABIA UNA COPIA DEL PATRON, INVENTADA (21/09): '(?i)contrasen|password|clave del
# banco'. O sea que este banco NO probaba el filtro de verdad, probaba tres palabras
# escritas a mano aqui mismo: el de assistant.ps1 podia cambiar, romperse o quedarse
# vacio y esta prueba seguia en verde. Comprobado quitandole 'contrase' al de verdad:
# el banco no se enteraba. Es el mismo accidente que probar-juegos.ps1 con el umbral de
# los 3 minutos. Ahora se trae del archivo, arriba, con las otras variables.
$PerfilMax = 60
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$UiNuevaOn = $true
$script:recetas = $null; $script:stats = $null
$script:logs = @()
function Log($m) { $script:logs += $m }
function Add-Estadistica($a, $b) {}
function Start-Vibracion {}
function Refresh-UI {}
function UltimoLog { if ($script:logs.Count) { $script:logs[-1] } else { '' } }
$mal = 0
function Comp($etq, $ok, $det = '') {
    if (-not $ok) { $script:mal++ }
    "  {0}  {1}{2}" -f $(if ($ok) { 'OK  ' } else { 'MAL ' }), $etq, $(if ("$det" -ne '') { "  -> $det" } else { '' })
}

Write-Host "--- recetas: aprender, encajar, ejecutar, seguridad ---"
function Test-FastCommand($t) { return ($t -match '^abre (spotify|discord)$') }
function Invoke-FastCommand($t) { if ($t -match '^abre') { return "abriendo" } return $null }
$receta = '{"frase": "crea una carpeta llamada {nombre} en {sitio}", "resumen": "crear la carpeta {nombre} en {sitio}", "pasos": [{"tipo": "powershell", "script": "New-Item -ItemType Directory -Path (Join-Path $sitio $nombre) -Force | Out-Null"}], "respuesta": "Listo, cree la carpeta {nombre}."}'
$r = Add-Receta "crea una carpeta llamada Fotos Viaje en $dir" ("Hecho. " + $receta)
Comp 'receta valida se aprende' ($null -ne $r) (UltimoLog)
$e = Find-Receta "Oye, crea una carpeta llamada Juegos Viejos en $dir."
Comp 'encaja con otra frase, con cortesia y punto final' ($null -ne $e)
Comp 'valor recortado del ORIGINAL (mayusculas intactas)' ($e.valores.nombre -ceq 'Juegos Viejos') $e.valores.nombre
Comp 'ruta intacta' ($e.valores.sitio -eq $dir) $e.valores.sitio
Comp 'resumen con los valores' ((Get-TextoReceta $e.receta 'resumen' $e.valores) -eq "crear la carpeta Juegos Viejos en $dir")
$res = Invoke-Receta $e.receta $e.valores
Comp 'la receta se ejecuta' ($res.ok) ("$($res.error)$($res.texto)")
Comp 'y la carpeta existe de verdad' (Test-Path (Join-Path $dir 'Juegos Viejos'))
$malo = "x'; New-Item -Path '" + (Join-Path $dir 'INYECTADO.txt') + "' -ItemType File; '"
$res2 = Invoke-Receta $e.receta @{ nombre = $malo; sitio = $dir }
Comp 'un valor con comillas no se ejecuta como codigo' (-not (Test-Path (Join-Path $dir 'INYECTADO.txt'))) ("ok=" + $res2.ok)
Comp 'prohibido: Remove-Item' (Test-ScriptProhibido 'Remove-Item $ruta -Recurse')
Comp 'prohibido: alias del en posicion de comando' (Test-ScriptProhibido "del C:\cosa.txt")
Comp 'prohibido: descarga' (Test-ScriptProhibido 'Invoke-WebRequest https://x -OutFile y')
Comp 'permitido: "carpeta del juego" en un texto' (-not (Test-ScriptProhibido 'New-Item -ItemType Directory -Path "C:\carpeta del juego"'))
$n0 = (Get-Recetas).Count
Comp 'rechaza script con Remove-Item' ($null -eq (Add-Receta 'borra la carpeta fotos' '{"frase":"borra la carpeta {nombre}","pasos":[{"tipo":"powershell","script":"Remove-Item $nombre -Recurse"}]}')) (UltimoLog)
Comp 'rechaza frase demasiado general' ($null -eq (Add-Receta 'hazlo' '{"frase":"{algo}","pasos":[{"tipo":"orden","texto":"abre spotify"}]}')) (UltimoLog)
Comp 'rechaza si la frase no encaja con su plantilla' ($null -eq (Add-Receta 'abre la musica ya' '{"frase":"pon musica en {app} ahora","pasos":[{"tipo":"orden","texto":"abre {app}"}]}')) (UltimoLog)
Comp 'rechaza un hueco con nombre reservado' ($null -eq (Add-Receta 'guarda la nota hola' '{"frase":"guarda la nota {input}","pasos":[{"tipo":"powershell","script":"Set-Content x.txt $input"}]}')) (UltimoLog)
Comp 'rechaza una orden que Nova no entiende' ($null -eq (Add-Receta 'pon la radio alta' '{"frase":"pon la radio alta","pasos":[{"tipo":"orden","texto":"sube la radio"}]}')) (UltimoLog)
Comp 'acepta una orden que Nova si entiende' ($null -ne (Add-Receta 'pon musica en spotify ahora' '{"frase":"pon musica en {app} ahora","pasos":[{"tipo":"orden","texto":"abre {app}"}],"respuesta":"Abriendo {app}"}')) (UltimoLog)
Comp 'ninguna rechazada se guardo' ((Get-Recetas).Count -eq $n0 + 1) ("recetas=" + (Get-Recetas).Count)
$script:recetas = $null
$e3 = Find-Receta "crea una carpeta llamada Otra en $dir"
Comp 'se relee del archivo y sigue encajando' ($null -ne $e3 -and $e3.valores.nombre -eq 'Otra')
$e4 = Find-Receta 'pon musica en discord ahora'
Comp 'la receta de orden encaja y se ejecuta' ($null -ne $e4 -and (Invoke-Receta $e4.receta $e4.valores).ok)
Comp 'una frase cualquiera no encaja' ($null -eq (Find-Receta 'que hora es'))

Write-Host "--- coletilla tras la coma ---"
function Test-FastCommand($t) { $true }
$script:recetas = $null; Remove-Item $RecetasPath -Force -ErrorAction SilentlyContinue
$json = '{"frase":"crea una carpeta llamada {nombre} en el escritorio","pasos":[{"tipo":"powershell","script":"New-Item -ItemType Directory -Force -Path $nombre"}]}'
Comp 'con coletilla tras la coma, se aprende' ($null -ne (Add-Receta 'crea una carpeta llamada Fotos en el escritorio, ahi guardo las fotos del viaje' $json)) (UltimoLog)
Comp 'si ni la primera parte encaja, se sigue rechazando' ($null -eq (Add-Receta 'abre la carpeta de musica, que hoy toca' '{"frase":"crea una carpeta llamada {nombre} en el escritorio","pasos":[{"tipo":"powershell","script":"New-Item x"}]}')) (UltimoLog)

Write-Host "--- otras formas de decirlo (variantes) ---"
$script:recetas = $null; Remove-Item $RecetasPath -Force -ErrorAction SilentlyContinue
$v = Get-VarianteReceta 'hazme una carpeta Fotos en el escritorio' @{ nombre = 'Fotos' }
Comp 'plantilla de otra forma de decirlo' ($v -eq 'hazme una carpeta {nombre} en el escritorio') $v
$v = Get-VarianteReceta 'Oye nova, puedes hacerme una carpeta Fotos Viejas en el escritorio.' @{ nombre = 'Fotos Viejas' }
Comp 'con cortesia delante y punto final' ($v -eq 'hacerme una carpeta {nombre} en el escritorio') $v
$v = Get-VarianteReceta 'hazme una carpeta fotos en el escritorio' @{ nombre = 'Imagenes' }
Comp 'si Haiku cambio el valor, no se inventa plantilla' ($null -eq $v) $v
$v = Get-VarianteReceta 'fotos' @{ nombre = 'fotos' }
Comp 'demasiado general, no' ($null -eq $v) $v
$v = Get-VarianteReceta 'copia foto a fotos viejas ya' @{ a = 'foto'; b = 'fotos viejas' }
Comp 'dos huecos, el mas largo primero' ($v -eq 'copia {a} a {b} ya') $v
$vars = New-Object System.Collections.ArrayList
[void]$vars.Add('hazme una carpeta {nombre} en el escritorio')
$pasos = New-Object System.Collections.ArrayList
[void]$pasos.Add(@{ tipo = 'powershell'; texto = 'New-Item x' })
$g = Get-Recetas
[void]$g.Add(@{ id = 1; frase = 'crea una carpeta llamada {nombre} en el escritorio'; resumen = 'crear la carpeta {nombre} en el escritorio'; respuesta = 'ok'; pasos = $pasos; variantes = $vars; ejemplo = 'x'; creada = 'x'; usos = 3; confirmadas = 2; fallos = 0; rechazos = 0 })
$e = Find-Receta 'hazme una carpeta Juegos Viejos en el escritorio'
Comp 'encaja por una variante' ($null -ne $e -and $e.valores.nombre -eq 'Juegos Viejos') $e.valores.nombre
Comp 'y dice que plantilla encajo' ($e.plantilla -eq 'hazme una carpeta {nombre} en el escritorio') $e.plantilla
$e2 = Find-Receta 'crea una carpeta llamada Otra en el escritorio'
Comp 'la frase original sigue encajando' ($null -ne $e2 -and $e2.valores.nombre -eq 'Otra')
Add-VarianteReceta $g[0] 'hazme una carpeta {nombre} en el escritorio'
Add-VarianteReceta $g[0] 'crea una carpeta llamada {nombre} en el escritorio'
Comp 'no repite variantes ni copia la frase' ($g[0].variantes.Count -eq 1) $g[0].variantes.Count
Add-VarianteReceta $g[0] 'monta una carpeta {nombre} en el escritorio'
Comp 'una nueva si se guarda' ($g[0].variantes.Count -eq 2)
$script:recetas = $null
$g2 = Get-Recetas
Comp 'las variantes sobreviven al guardado' ($g2.Count -eq 1 -and $g2[0].variantes.Count -eq 2) ("variantes=" + $g2[0].variantes.Count)
Comp 'y siguen encajando tras releer' ($null -ne (Find-Receta 'monta una carpeta X en el escritorio'))
[IO.File]::WriteAllText($RecetasPath, '[{"id":7,"frase":"abre la carpeta {nombre}","resumen":"","respuesta":"","pasos":[{"tipo":"powershell","texto":"x"}],"ejemplo":"","creada":"","usos":0,"confirmadas":0,"fallos":0,"rechazos":0}]')
$script:recetas = $null
$g3 = Get-Recetas
Comp 'receta antigua sin variantes se carga' ($g3.Count -eq 1 -and $g3[0].variantes.Count -eq 0)
Comp 'y encaja' ($null -ne (Find-Receta 'abre la carpeta Fotos'))
$cmds = Get-Content (Join-Path (Split-Path -Parent $PSScriptRoot) 'commands.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:Juegos = @(@{ nombre = 'ELDEN RING' })
$prompt = Build-PromptTraduccion 'hazme una carpetita'
Comp 'el prompt de Haiku incluye las tareas aprendidas' ($prompt -match 'Tareas que Nova ya sabe hacer' -and $prompt -match '- abre la carpeta \{nombre\}')
$script:recetas = New-Object System.Collections.ArrayList
Comp 'sin recetas no se anade nada' ((Build-PromptTraduccion 'hola') -notmatch 'Tareas que Nova')

Write-Host "--- perfil: lo que Nova sabe de ti ---"
$barra = [char]92
$rutaCapturas = 'D:' + $barra + 'Capturas'
Comp 'un dato se guarda' ($null -ne (Add-DatoPerfil ('Su carpeta de capturas es ' + $rutaCapturas) 'prueba'))
Comp 'repetido no se guarda dos veces' ($null -eq (Add-DatoPerfil ('Su carpeta de capturas es ' + $rutaCapturas) 'prueba'))
Comp 'lo sensible no se guarda' ($null -eq (Add-DatoPerfil 'Su contrasena del correo es hola1234' 'prueba'))
# EL OTRO LADO DEL FILTRO (21/09): con el patron sin traer, aqui se rechazaba TODO y la
# linea de arriba salia verde igual. Un dato normal tiene que PASAR.
Comp 'y un dato normal si se guarda' ($null -ne (Add-DatoPerfil 'Braya juega a Elden Ring por las noches' 'prueba'))
$txt = Get-Content (Get-SistemaCerebro) -Raw -Encoding UTF8
Comp 'el prompt del cerebro lleva a Nova Y el perfil' ($txt.Contains('Lo que sabes de braya') -and $txt.Contains('Su carpeta de capturas es ' + $rutaCapturas) -and $txt.Contains('Eres Nova'))

Write-Host "--- cuanto has aprendido, y la celebracion ---"
Remove-Item $PerfilPath, $RecetasPath -Force -ErrorAction SilentlyContinue
$script:recetas = $null; $script:stats = $null
Comp 'sin nada aprendido lo dice' ((Get-BalanceAprendizaje) -match '^todavia no he aprendido')
[IO.File]::WriteAllText($RecetasPath, '[{"id":1,"frase":"crea la carpeta {nombre}","pasos":[],"variantes":["hazme una carpeta {nombre}"]},{"id":2,"frase":"abre capturas","pasos":[],"variantes":[]}]')
[IO.File]::WriteAllText($PerfilPath, "# x`n`n- dato uno largo`n- dato dos largo`n- dato tres largo")
$hoy = (Get-Date).ToString('yyyy-MM-dd'); $ayer = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd'); $viejo = (Get-Date).AddDays(-10).ToString('yyyy-MM-dd')
[IO.File]::WriteAllText($EstadisticasJson, "{`"dias`":{`"$hoy`":{`"receta`":4,`"perfil`":1},`"$ayer`":{`"receta`":2},`"$viejo`":{`"receta`":50}}}")
$script:recetas = $null; $script:stats = $null
$t = Get-BalanceAprendizaje
Comp 'balance: tareas, formas, datos, usos de la semana y minutos' ($t -match 'se hacer 2 tareas y entiendo 3 formas' -and $t -match 'se 3 cosas de ti' -and $t -match 'hice sola 6 cosas' -and $t -match 'unos 2 minutos') $t
$script:uiEvento = ''; $script:uiEventoN = 0; $script:acabaDeAprender = $false
Send-UIEvento 'hecho'; Comp 'hecho normal' ($script:uiEvento -eq 'hecho')
Set-AcabaDeAprender; Send-UIEvento 'hecho'; Comp 'hecho tras aprender se celebra' ($script:uiEvento -eq 'gesto:aprendido')
Send-UIEvento 'hecho'; Comp 'y solo una vez' ($script:uiEvento -eq 'hecho')
Set-AcabaDeAprender; $script:acabaDeAprenderEn = -20000; Send-UIEvento 'hecho'
Comp 'la marca caduca a los 10 s' ($script:uiEvento -eq 'hecho' -and -not $script:acabaDeAprender)

Write-Host "--- receta con script sin bloquear a Nova (M11) ---"
$script:dichos = @(); $script:enviados = @()
function Say($t, $e = '') { $script:dichos += $t }
function Show-Popup {}
function Set-UI {}
function Submit-Command($t, $m) { $script:enviados += "$m|$t" }
$script:recetaEnCurso = $null; $script:reparandoReceta = $null
$marcaR = Join-Path $dir 'receta-async.txt'
$rAsync = @{ id = 71; frase = 'marca async {nombre}'; resumen = 'x'; respuesta = 'Hecho con {nombre}.'; usos = 0; confirmadas = 5; fallos = 0
    variantes = (New-Object System.Collections.ArrayList)
    pasos = @(@{ tipo = 'powershell'; texto = "Start-Sleep -Milliseconds 900; Set-Content -LiteralPath '$marcaR' -Value `$nombre" }) }
$t0 = [System.Diagnostics.Stopwatch]::StartNew()
$vuelta = Start-Receta @{ receta = $rAsync; valores = @{ nombre = 'Ana' } } 'marca async Ana' 'otra forma de decirlo'
Comp 'con un script, no espera: vuelve al momento' ($vuelta -eq 'enCurso' -and $t0.ElapsedMilliseconds -lt 800 -and $null -ne $script:recetaEnCurso) "$($t0.ElapsedMilliseconds) ms"
$otra = Start-Receta @{ receta = $rAsync; valores = @{ nombre = 'Leo' } } 'marca async Leo'
Comp 'mientras corre, otra receta no se empieza' ($otra -eq $false -and $script:dichos[-1] -match 'todavia') ($script:dichos -join ' | ')
while ($script:recetaEnCurso -and $t0.ElapsedMilliseconds -lt 15000) { Watch-Receta; Start-Sleep -Milliseconds 100 }
$escrito = if (Test-Path $marcaR) { (Get-Content $marcaR -Raw).Trim() } else { '' }
Comp 'al acabar el script: contesta y aprende la otra forma de decirlo' ($escrito -eq 'Ana' -and $script:dichos[-1] -eq 'Hecho con Ana.' -and @($rAsync.variantes) -contains 'otra forma de decirlo') ("$escrito | " + ($script:dichos -join ' | '))
$rFallo = @{ id = 72; frase = 'falla async'; resumen = 'x'; respuesta = ''; usos = 0; confirmadas = 5; fallos = 0
    variantes = (New-Object System.Collections.ArrayList); pasos = @(@{ tipo = 'powershell'; texto = 'exit 3' }) }
$script:enviados = @()
[void](Start-Receta @{ receta = $rFallo; valores = @{} } 'falla async')
$t1 = [System.Diagnostics.Stopwatch]::StartNew()
while ($script:recetaEnCurso -and $t1.ElapsedMilliseconds -lt 15000) { Watch-Receta; Start-Sleep -Milliseconds 100 }
Comp 'si el script falla: se apunta y va al cerebro a repararla' ($rFallo.fallos -eq 1 -and $script:enviados -contains 'accion|falla async' -and $script:reparandoReceta.error -match 'codigo 3') ($script:enviados -join ',')
$script:reparandoReceta = $null

Write-Host "--- recetas que preguntan lo que falta ---"
$script:invitado = $false
$falsas = @(
    @{ id = 91; frase = 'crea una carpeta llamada {nombre}'; variantes = @('haz una carpeta que se llame {nombre}') },
    @{ id = 92; frase = 'busca el tiempo en {ciudad}'; variantes = @() },
    @{ id = 93; frase = 'copia {origen} a {destino}'; variantes = @() },
    @{ id = 94; frase = 'descarga {cosa}'; variantes = @() }
)
$inc = Find-RecetaIncompleta 'Oye, crea una carpeta' $falsas
Comp 'sin el valor del final: la encuentra y dice que hueco falta' ($inc -and $inc.receta.id -eq 91 -and $inc.hueco -eq 'nombre') "$($inc.receta.id) $($inc.hueco)"
$inc = Find-RecetaIncompleta 'haz una carpeta' $falsas
Comp 'tambien por otra forma de decirla (quita "que se llame")' ($inc -and $inc.receta.id -eq 91)
$inc = Find-RecetaIncompleta 'busca el tiempo' $falsas
Comp 'quita el enlace "en"' ($inc -and $inc.hueco -eq 'ciudad')
Comp 'con dos huecos no pregunta' ($null -eq (Find-RecetaIncompleta 'copia' $falsas))
Comp 'con una sola palabra fija no pregunta (demasiado poco)' ($null -eq (Find-RecetaIncompleta 'descarga' $falsas))
Comp 'lo que no se parece, nada' ($null -eq (Find-RecetaIncompleta 'crea una lista' $falsas))
$script:invitado = $true
Comp 'en modo invitado no hay recetas' ($null -eq (Find-RecetaIncompleta 'crea una carpeta' $falsas) -and $null -eq (Find-Receta 'crea una carpeta llamada X' $falsas))
$script:invitado = $false

Write-Host "--- el nivel de Nova ---"
# aqui hay 2 recetas con 1 variante (3) y 3 datos tuyos: 6 cosas
$script:recetas = $null
function Get-Reglas { return ,(New-Object System.Collections.ArrayList) }
Comp 'cuenta tareas, formas de pedirlas y datos' ((Get-CuentaAprendida) -eq 6) (Get-CuentaAprendida)
Comp 'nada aprendido: nivel 0' ((Get-Madurez 0) -eq 0)
Comp 'una cosa: nivel 1' ((Get-Madurez 1) -eq 1)
Comp 'seis cosas: nivel 2' ((Get-Madurez 6) -eq 2)
Comp 'cincuenta o mas: el maximo, 5' ((Get-Madurez 50) -eq 5 -and (Get-Madurez 300) -eq 5)
Comp 'la frase cuenta cuanto falta' ((Get-FraseNivel) -eq 'estoy en el nivel 2 y se 6 cosas; con 6 mas subo al 3') (Get-FraseNivel)

Write-Host "--- las 8 recetas de verdad de braya (memoria\recetas.json) ---"
# HASTA AHORA ESTE BANCO SOLO PROBABA RECETAS INVENTADAS AQUI MISMO. Estas son las que
# hay DE VERDAD en memoria\recetas.json el 24/09: 8 recetas, 1 sola con hueco ({texto}) y
# con una forma mas de decirla, y 7 literales sin ningun hueco. Copiadas del archivo tal
# cual (frase y ejemplo). Lo que se rompe si esto se cae: no un caso de laboratorio, sino
# todo lo que Nova ha aprendido a hacer sola; una receta que deja de encajar vuelve a
# costar los 44 s de agente que costaba antes de aprenderla.
# La 6 lleva una ene con tilde en el ejemplo real ("manana"), y aqui los ficheros son
# ASCII: se arma con su codigo para que sea la frase de braya y no una parecida.
$ejemplo6 = 'Revisa mi calendario y dime si tengo algo anotado para ma' + [char]0xF1 + 'ana'
$realesRec = @(
    @{ id = 1; frase = 'crea una nota en el escritorio que diga {texto}'; ejemplo = 'Crea una nota en el escritorio que diga Hola'
       variantes = @('crea una nota en el escritorio llamada {texto}') },
    @{ id = 2; frase = 'que hay en mis descargas'; ejemplo = 'que hay en mis descargas'; variantes = @() },
    @{ id = 3; frase = 'que hay en mis documentos'; ejemplo = 'que hay en mis documentos'; variantes = @() },
    @{ id = 4; frase = 'cuantos clips tengo'; ejemplo = 'cuantos clips tengo'; variantes = @() },
    @{ id = 5; frase = 'crear un archivo en el escritorio que se llame hola y dentro tenga hola mundo'
       ejemplo = 'Puedes crear un archivo en el escritorio que se llame Hola y dentro tenga Hola Mundo'; variantes = @() },
    @{ id = 6; frase = 'revisa mi calendario y dime si tengo algo anotado para manana'; ejemplo = $ejemplo6; variantes = @() },
    @{ id = 7; frase = 'pon el nombre prueba y la carpeta en el escritorio'; ejemplo = 'Pon el nombre prueba y la carpeta en el escritorio'; variantes = @() },
    @{ id = 8; frase = 'crea una carpeta llamada prueba dos en el escritorio'; ejemplo = 'Crea una carpeta llamada Prueba dos en el escritorio'; variantes = @() }
)
$script:invitado = $false
$erradas = 0
foreach ($rr in $realesRec) {
    $enc = Find-Receta $rr.ejemplo $realesRec
    if (-not $enc -or $enc.receta.id -ne $rr.id) { $erradas++; Write-Host ("       la $($rr.id) no encaja con su propio ejemplo") }
}
Comp 'las 8 encajan cada una con su propio ejemplo' ($erradas -eq 0) "erradas=$erradas"
# la unica con hueco: el valor se recorta del ORIGINAL, con sus mayusculas
$encN = Find-Receta 'Crea una nota en el escritorio que diga Hola' $realesRec
Comp 'la nota saca el texto tal como lo dijo' ($encN -and $encN.valores.texto -ceq 'Hola') "$($encN.valores.texto)"
# Y POR LA OTRA FORMA DE DECIRLA, que es la unica variante que hay guardada. La frase es
# la que dijo braya en el registro ("RECETA 1: 'Crea una nota en el escritorio llamada
# Hola Uno' -> la hago sin IA"), y sirve ademas para lo que el ejemplo guardado no
# prueba: que el hueco admita DOS palabras. Con un hueco que solo coja una, 'Hola Uno'
# deja de encajar y esa orden vuelve a costar una vuelta entera al agente.
$encV = Find-Receta 'Crea una nota en el escritorio llamada Hola Uno' $realesRec
Comp 'y por su variante, con un valor de dos palabras' ($encV -and $encV.receta.id -eq 1 -and $encV.valores.texto -ceq 'Hola Uno') "$($encV.valores.texto)"
# LA NOTA Y LA CARPETA EMPIEZAN IGUAL ("crea una..."): la 8 no puede caer en la 1, que se
# comeria "carpeta llamada Prueba dos en el escritorio" entero como el texto de una nota.
$encC = Find-Receta 'Crea una carpeta llamada Prueba dos en el escritorio' $realesRec
Comp 'la carpeta no cae en la receta de la nota' ($encC -and $encC.receta.id -eq 8) "cayo en la $($encC.receta.id)"
$incN = Find-RecetaIncompleta 'crea una nota en el escritorio' $realesRec
Comp 'sin decir que poner, pregunta el texto' ($incN -and $incN.receta.id -eq 1 -and $incN.hueco -eq 'texto') "$($incN.hueco)"

Write-Host "--- la plantilla se ajusta a TU verbo (dos casos reales del registro) ---"
# LOS DOS QUE ESTABAN EN EL LOG Y NO ESTABAN AQUI. El cerebro escribe la frase con SU
# verbo ("cuenta...") y braya la dijo con otro ("puedes contar..."), asi que la plantilla
# no encajaba con lo dicho y la receta se perdia. Paso de verdad el 13/09 a las 16:34:51 y
# a las 16:35:24 (descargas y documentos: las dos "RECETA descartada ... no encaja en
# 'cuenta los archivos de mi carpeta de {carpeta}'"), y el arreglo se ve funcionando el
# 18/09 a las 18:50:50: "RECETA: plantilla ajustada a como lo dijiste". Si esta rama se
# cae, esas dos recetas vuelven a no aprenderse nunca, y la 5 de memoria\recetas.json
# -que se guardo por aqui- no existiria.
$script:recetas = $null
Remove-Item $RecetasPath -Force -ErrorAction SilentlyContinue
$script:logs = @()
$jsonCuenta = '{"frase":"cuenta los archivos de mi carpeta de {carpeta}","resumen":"contar los archivos de {carpeta}","pasos":[{"tipo":"orden","texto":"abre spotify"}],"respuesta":"listo"}'
$rCuenta = Add-Receta 'Puedes contar los archivos de mi carpeta de descargas' $jsonCuenta
Comp 'el "puedes contar" del 13/09 ya se aprende' ($null -ne $rCuenta) (UltimoLog)
Comp 'y se guarda con TU verbo, no con el del cerebro' ($rCuenta -and $rCuenta.frase -eq 'contar los archivos de mi carpeta de {carpeta}') "$($rCuenta.frase)"
Comp 'y lo deja dicho en el log' ((@($script:logs) -join ' | ') -match 'plantilla ajustada a como lo dijiste') ''
Comp 'la plantilla ajustada vuelve a encajar' ($null -ne (Find-Receta 'contar los archivos de mi carpeta de documentos')) ''
# EL SEGUNDO CASO REAL, el que dejo la receta 5 tal como esta hoy en el disco: braya dijo
# "Puedes crear..." y el cerebro escribio "crea...". La frase que quedo guardada empieza
# por "crear", y es exactamente la que hay en memoria\recetas.json.
$script:recetas = $null
Remove-Item $RecetasPath -Force -ErrorAction SilentlyContinue
$script:logs = @()
$jsonHola = '{"frase":"crea un archivo en el escritorio que se llame hola y dentro tenga hola mundo","resumen":"crear el archivo","pasos":[{"tipo":"orden","texto":"abre spotify"}],"respuesta":"listo"}'
$rHola = Add-Receta 'Puedes crear un archivo en el escritorio que se llame Hola y dentro tenga Hola Mundo' $jsonHola
Comp 'y el del 18/09 queda igual que en el disco' ($rHola -and $rHola.frase -eq 'crear un archivo en el escritorio que se llame hola y dentro tenga hola mundo') "$($rHola.frase)"

Write-Host "--- el MOTIVO cuando el cerebro dice que NO ---"
# EL REGEX QUE NADIE MIRABA. Cuando el cerebro contesta "RECETA: NO", detras tiene que
# venir UNO de los seis motivos que le pide $CcInstruccionReceta (pantalla, contenido,
# externo, destructivo, inseguro, charla). Ese motivo es lo unico que dice QUE se podria
# mejorar para que la proxima vez si se aprenda.
# LO MEDIDO EN EL REGISTRO: desde que existe el motivo (18/09) ha habido 6 "RECETA: NO"
# -2 el 18/09, 3 el 20/09 y 1 el 22/09, que son exactamente los 6 'receta-no' de
# estadisticas.json-. De esos 6, CINCO salieron "sin motivo" y el sexto (20/09 a las
# 18:57:36) saco "no", que no es ninguno de los seis. O sea: 0 motivos utiles de 6.
# Por eso esto se prueba: para que se vea lo que el regex se traga y lo que se le escapa.
# El regex y su condicion se sacan del archivo real por el arbol, no copiados: si alguien
# los cambia, aqui se ve. El cuerpo entero del if se ejecuta con Log y Add-Estadistica de
# mentira, asi que lo que se mide es lo que se apuntaria de verdad.
$ifNoRec = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.IfStatementAst] -and
    $x.Clauses[0].Item1.Extent.Text -match '^\$bloqueRec\s+-match' -and
    $x.Clauses[0].Item2.Extent.Text -match "Add-Estadistica 'receta-no'" }, $true)
if (-not $ifNoRec) { Write-Host '  MAL  no encuentro el bloque del NO de la receta'; $mal++ }
$condNoRec = $ifNoRec.Clauses[0].Item1.Extent.Text
$cuerpoNoRec = $ifNoRec.Clauses[0].Item2.Extent.Text
$script:statReceta = ''
function Add-Estadistica($a, $b) { $script:statReceta = "$a|$b" }
function MotivoDelNo([string]$bloqueRec) {
    $script:statReceta = ''
    if (-not (Invoke-Expression $condNoRec)) { return '(no es un NO)' }
    Invoke-Expression ('& ' + $cuerpoNoRec)
    return ($script:statReceta -replace '^receta-no\|', '')
}
# los seis motivos no se escriben aqui: se sacan de la instruccion que el cerebro recibe,
# para que anadir uno nuevo alli no deje este banco mirando una lista vieja
$txtInstr = ($ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $x.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
    $x.Left.VariablePath.UserPath -eq 'CcInstruccionReceta' }, $true)).Extent.Text
$seis = @([regex]::Matches($txtInstr, '(?m)^-\s*NO\s+([a-z]+)') | ForEach-Object { $_.Groups[1].Value })
Comp 'la instruccion del cerebro sigue ofreciendo sus motivos' ($seis.Count -ge 5) ("motivos=" + ($seis -join ','))
$sinLeer = @()
foreach ($m in $seis) { if ((MotivoDelNo ("NO $m")) -ne $m) { $sinLeer += $m } }
Comp 'y el regex los lee todos' ($sinLeer.Count -eq 0) ("no lee: " + ($sinLeer -join ','))
Comp 'con dos puntos delante tambien' ((MotivoDelNo 'NO: externo') -eq 'externo') ''
Comp 'y con el motivo explicado detras' ((MotivoDelNo 'NO pantalla: tuviste que MIRAR la pantalla') -eq 'pantalla') ''
Comp 'en minusculas tambien, que el cerebro no siempre grita' ((MotivoDelNo 'No contenido') -eq 'contenido') ''
# LO QUE NO ES UN NO NO PUEDE ENTRAR AQUI: detras de "RECETA:" suele venir el JSON de una
# receta buena, y si esto lo tomara por un NO se perderia la receta entera.
Comp 'el JSON de una receta buena no es un NO' ((MotivoDelNo '{"tipo": "accion", "frase": "abre steam"}') -eq '(no es un NO)') ''
Comp 'ni una palabra que solo empieza por no' ((MotivoDelNo 'NOPE, ni idea') -eq '(no es un NO)') ''
# LOS TRES QUE SE TRAGABA MAL, ARREGLADOS EL 24/09 (idea 13). Estas tres comprobaciones
# nacieron documentando el fallo, y hoy documentan el arreglo: la lista dejo de ser abierta.
#
# 1) "NO, no era una tarea" daba motivo "no", que es EXACTAMENTE lo que se apunto el 20/09 a
#    las 18:57:36 -el unico motivo que el regex viejo saco en toda su vida-. "no" no es
#    ninguno de los seis, asi que ahora no se apunta nada, que es la verdad.
Comp 'un "no" de relleno ya NO se cuela (20/09 18:57:36)' ((MotivoDelNo 'NO, no era una tarea') -eq 'sin motivo') 'antes daba "no"'
# 2) lo mismo con cualquier otra palabra de relleno: el regex viejo cogia la primera que
#    hubiera, fuera la que fuera.
Comp 'ni una palabra suelta cualquiera' ((MotivoDelNo 'no se puede repetir sin ti') -eq 'sin motivo') 'antes daba "se"'
# 3) y el motivo en la LINEA DE ABAJO ya se lee. La clase de caracteres vieja llevaba
#    espacio, tabulador, dos puntos, coma y guion, pero NO el salto de linea, y la
#    instruccion se los pide en lista, o sea en lineas aparte: es la explicacion mas
#    probable de los cinco "sin motivo" medidos. Probable, no segura: el texto crudo de esos
#    cinco no se guarda en ningun sitio, y eso no se puede saber a toro pasado.
Comp 'el motivo en la linea de abajo ya se lee' ((MotivoDelNo ("NO" + [char]10 + "inseguro")) -eq 'inseguro') 'antes se perdia'
Comp 'y con la explicacion debajo, tambien' ((MotivoDelNo ("NO" + [char]10 + "pantalla: tuviste que mirar")) -eq 'pantalla') ''
# PERO NO SE ADIVINA. Si el cerebro no escribio ninguno de los seis, 'sin motivo' es la
# respuesta correcta: inventarlo seria peor que no tenerlo, porque este contador es de los
# que se miran para decidir.
Comp 'y un NO a secas sigue sin motivo' ((MotivoDelNo 'NO') -eq 'sin motivo') 'no se inventa'
Comp 'ni un NO con una excusa larga y sin motivo' ((MotivoDelNo 'NO porque esto la verdad no lo tengo claro del todo') -eq 'sin motivo') ''
# Y NO SE CAZA UNA PALABRA PERDIDA EN MEDIO DE UN PARRAFO: solo cuentan las dos primeras
# lineas. Si valiera el bloque entero, una explicacion que mencionara "la pantalla" tres
# parrafos mas abajo se apuntaria como motivo.
$largo = "NO" + [char]10 + "no estoy seguro" + [char]10 + "ademas habria que mirar la pantalla"
Comp 'una palabra tres lineas mas abajo no cuenta' ((MotivoDelNo $largo) -eq 'sin motivo') 'solo las dos primeras lineas'


Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
# EL VERDE EN FALSO (18/09, revision del agente). $falloInfo contaba los fallos de las recetas
# de informacion -las que comprueban que un script SOLO PUEDA LEER, ni borrar ni lanzar
# procesos- pero se imprimia y nunca se sumaba a $mal, asi que el banco daba exito con esas
# guardas rotas. Son 16 comprobaciones que no podian suspender.
$mal += $falloInfo
if ($mal -gt 0) { Write-Host "$mal casos MAL"; exit 1 }
Write-Host "todo correcto"
