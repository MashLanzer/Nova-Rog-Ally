# QUE EL MODO INVITADO NO APRENDA NADA DE QUIEN NO ERES TU (17/09).
#
# "Modo invitado. No aprendo nada ni miro tus cosas", dice Nova al ponerlo. No era verdad
# del todo: la guarda estaba en 6 funciones (estadisticas, habitos, perfil, musica, charla,
# ritmo) y faltaba en las que aprenden de lo que se DICE. Dentro de Invoke-FastCommand
# -1.600 lineas- la unica comprobacion cubria "leer los mensajes", asi que un invitado podia
# dejar notas en el diario, contactos, fechas, alias, recetas y traducciones.
#
# Esta prueba tiene dos mitades, y la segunda es la que importa a largo plazo:
#   1) que las 11 de hoy tengan la guarda;
#   2) que NINGUNA funcion de guardado nueva se quede sin ella sin darse cuenta. Si alguien
#      anade una, esta prueba falla hasta que decida: o la protege, o la declara exenta con
#      su motivo aqui abajo.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO (24/09). PowerShell 5.1 con -File sale con codigo 0
# aunque el script muera a mitad, asi que un banco que llama a una funcion que ya no existe
# se daba por bueno. Paso dos veces el 23/09. Con esto, morir es un fallo.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$rutaA = Join-Path $raiz 'assistant.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($rutaA, [ref]$null, [ref]$null)

$mal = 0
function Comp([string]$etq, [bool]$ok, [string]$det) {
    Write-Host ("  {0}  {1,-50} {2}" -f $(if ($ok) { 'OK ' } else { 'MAL' }), $etq, $det)
    if (-not $ok) { $script:mal++ }
}

# --- las que guardan algo TUYO: tienen que mirar el modo invitado ---
$DEBEN = @(
    'Add-Memoria', 'Add-DiarioResumen', 'Add-Alias-Comando', 'Add-Traduccion', 'Add-Rechazo',
    'Add-VarianteReceta', 'Add-Receta', 'Set-NotaJuego', 'Save-Contactos', 'Add-TiempoJuego',
    'Add-Fecha', 'Add-Estadistica', 'Add-Habito', 'Add-HistorialMusica', 'Add-DatoPerfil',
    'Add-CharlaHora', 'Add-RitmoSeguimiento'
)
# --- y las que NO guardan nada personal: exentas, con el motivo ---
$EXENTAS = @{
    'Set-UI'                  = 'dibuja la capsula, no guarda nada'
    'Set-Cfg'                 = 'ajustes de Nova, no datos de nadie'
    'Set-VozVelocidad'        = 'un ajuste de la voz'
    'Save-Corrupto'           = 'aparta un archivo roto: hay que hacerlo siempre'
    'Save-EstadoParaDeshacer' = 'brillo y volumen para poder deshacer, se borra solo'
    'Save-DecisionPropia'     = 'lo que decidio Nova de si misma, no del invitado'
    'Add-RecetasInfoBase'     = 'recetas de fabrica, se cargan al arrancar'
    'Save-EntornoVistos'      = 'dispositivos vistos, del equipo y no de una persona'
    'Save-Captura'            = 'guarda la imagen que se acaba de pedir a proposito'
    'Save-Habitos'            = 'lo llama Add-Habito, que ya mira el modo'
    'Save-JuegosMem'          = 'lo llaman Set-NotaJuego y Add-TiempoJuego, ya protegidos'
    'Save-Listas'             = 'la lista de la compra se pide en voz alta, no se aprende sola'
    'Save-Recetas'            = 'lo llaman Add-Receta y Add-VarianteReceta, ya protegidos'
    'Save-Rechazos'           = 'lo llama Add-Rechazo, ya protegido'
    'Save-Recordatorios'      = 'un recordatorio se pide a proposito'
    'Save-Reglas'             = 'una regla se pide a proposito'
    'Save-TiempoJuego'        = 'lo llama Add-TiempoJuego, ya protegido'
    'Save-DatosPerfil'        = 'lo llama Add-DatoPerfil, que ya mira el modo'
    # 23/09: dejo de estar exenta por el motivo viejo -"se pide a proposito"- y lleva la guarda
    # dentro. El modo invitado se propone justo cuando Nova no reconoce la voz, o sea cuando
    # hay otra persona delante, y commands.json es el fichero de ordenes de braya.
    'Add-Perfil'              = 'lleva la guarda dentro desde el 23/09; se queda aqui por si alguien la quita sin querer'
    'Set-UsoAhora'            = 'marca de uso del propio Nova'
    # LAS SIETE DE LA TANDA DE VEINTE IDEAS (24/09), decididas una a una. La regla que las
    # separa es la de siempre: el modo invitado esta para que Nova no APRENDA de quien no
    # eres tu, no para que deje de funcionar la consola mientras hay alguien delante.
    'Add-DescargaHecha'       = 'que Steam acabara de bajar un juego es del equipo: pasa igual hable quien hable, y nadie lo dice'
    'Save-DescargasEstado'    = 'el estado de las descargas de Steam, leido del disco; no sale de nadie'
    'Save-AvisoEspera'        = 'avisos que Nova genero ella sola y no pudo dar; no hay nada de quien hablo'
    'Add-ArranqueOidoMs'      = 'milisegundos de lo que tarda el oido en arrancar: mide la maquina, igual que Add-NubeTiempo'
    'Add-GuiaTiempo'          = 'milisegundos de lo que tarda la Wikipedia en contestar; lo mismo'
    'Save-BancoTrivia'        = 'preguntas de cultura general de la consola, y cuales se han hecho ya; el marcador no se guarda'
    'Save-MusicaNo'           = 'lo llaman Add-MusicaNo y Remove-MusicaNo, las dos ya protegidas (24/09: a Remove le faltaba)'
    'Add-NubeTiempo'          = 'solo son milisegundos, y con invitado la nube ni se lanza (Start-NubeOir sale en su primera linea)'
    # LA QUE APARECIO AL AMPLIAR EL DETECTOR (24/09). Guarda en memoria\juegos-dos.json si cada
    # juego instalado es de uno o de dos, y eso lo dice la TIENDA de Steam, no quien hable: la
    # ficha de A Way Out pone "cooperativo" tenga braya un invitado delante o no. Es el mismo
    # motivo por el que ya estaban exentas Add-DescargaHecha y Save-DescargasEstado.
    'Save-JuegosDos'          = 'las categorias de la tienda de los juegos instalados: salen de Steam, no de quien hable'
    # LA LAPIDA DEL PERFIL (24/09, idea 12). Comprobado con grep: el UNICO sitio que la llama
    # es la poda de Add-DatoPerfil (linea 8119), y Add-DatoPerfil se va en su primera linea
    # con el modo invitado puesto. O sea que con alguien delante no se llega ni a la poda.
    "Add-PerfilCaido"          = 'solo la llama la poda de Add-DatoPerfil, que sale en su primera linea si hay invitado'
    # 22/09: la hermana de la de arriba, pero SOLO por el primer motivo. Comprobado que el
    # segundo NO vale aqui: Start-OpencodeJob no mira el modo invitado, asi que con un
    # invitado delante SI se lanzan trabajos y SI se apuntan sus tiempos. Y aun asi no
    # lleva guarda, porque lo que se guarda son milisegundos de la maquina y de la red, no
    # nada de quien hablo: una pregunta tarda lo mismo la pida braya o la pida otro. El
    # modo invitado esta para que Nova no APRENDA de quien no eres tu, y un tiempo de
    # respuesta no dice nada de nadie. Ponerle la guarda solo dejaria huecos en la medicion
    # de la barra sin tapar ni un dato personal.
    'Add-TrabajoTiempo'       = 'milisegundos de la maquina y la red, no de quien habla (ver la nota de arriba)'
    # 21/09 (C6): la guarda la ponen los DOS que la llaman, y ahi es donde toca.
    # Add-Traduccion sale en su primera linea si hay invitado -o sea que un invitado no
    # ensena nada-, y Remove-Traduccion a proposito NO la tiene: olvidar algo tuyo se
    # puede pedir siempre, tambien mientras le dejas la consola a alguien. Si la guarda
    # se pusiera aqui dentro, ese olvido se quedaria a medias: borrado de la memoria y
    # no del fichero, o sea que volveria al reiniciar.
    'Save-Traducciones'       = 'la decide quien la llama: Add-Traduccion tiene la guarda y Remove-Traduccion no la quiere'
}

$fns = $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

Write-Host '  -- las que aprenden de lo que se dice: con guarda --'
foreach ($n in $DEBEN) {
    $f = @($fns | Where-Object { $_.Name -eq $n })
    if ($f.Count -eq 0) { Comp "$n existe" $false 'no la encuentro'; continue }
    Comp $n ($f[0].Extent.Text -match 'script:invitado') ''
}

Write-Host ''
Write-Host '  -- el detector conoce TODAS las formas de escribir del archivo --'
# EL DETECTOR ES EL BANCO, y un detector estrecho deja pasar funciones enteras sin que nadie se
# entere: hasta el 24/09 solo miraba WriteAllText, AppendAllText y Write-Atomico, y Save-JuegosDos
# -que guarda con Set-Content- llevaba desde el 11/09 sin estar ni exenta ni con guarda, con el
# banco diciendo "ninguna sin decidir".
#
# Por eso aqui no se comprueba el resultado, se comprueba el DETECTOR: que las formas de
# escribir que de verdad aparecen en assistant.ps1 esten todas en su lista. Si manana alguien
# guarda con Out-File o con Export-Clixml, esto se pone rojo antes de que la funcion exista.
# Este banco no lee el fichero como texto -trabaja con el arbol-, asi que aqui se lee una vez.
$txtA = [System.IO.File]::ReadAllText($rutaA)
$detector = 'WriteAllText|AppendAllText|Write-Atomico|Set-Content|Out-File|Export-Clixml|Add-Content'
$formasQueUsa = @()
# Add-Content entro el 24/09, y lo caza esta misma comprobacion: el archivo lo usa, aunque hoy
# ninguna funcion Add/Save/Set escriba SOLO con el. Que no haya victimas hoy no es motivo para
# dejar el agujero: Save-JuegosDos llevaba trece dias colada por el mismo tipo de hueco.
foreach ($forma in @('WriteAllText', 'AppendAllText', 'Write-Atomico', 'Set-Content', 'Out-File',
                     'Export-Clixml', 'Add-Content', 'Export-Csv', 'Save-Text')) {
    if ($txtA -match [regex]::Escape($forma)) { $formasQueUsa += $forma }
}
$fuera = @($formasQueUsa | Where-Object { $detector -notmatch [regex]::Escape($_) })
Comp 'el detector cubre todo lo que el archivo usa para escribir' ($fuera.Count -eq 0) $(if ($fuera) { "NO mira: $($fuera -join ', ')" } else { "cubre las $($formasQueUsa.Count) formas que usa" })
# y que sea LITERALMENTE el mismo que usa el bucle de abajo, no una copia que se quede vieja
$yo = [System.IO.File]::ReadAllText($PSCommandPath)
Comp 'y es el mismo que usa el bucle de abajo' ($yo -match [regex]::Escape("-notmatch '" + $detector + "'")) 'si se separan, esto deja de proteger nada'

Write-Host ''
Write-Host '  -- y ninguna nueva se cuela sin decidirlo --'
$sinDecidir = @()
foreach ($f in $fns) {
    if ($f.Name -notmatch '^(Add|Save|Set)-') { continue }
    $t = $f.Extent.Text
    # TRES FORMAS DE ESCRIBIR NO SON TODAS (24/09). El detector solo miraba WriteAllText,
    # AppendAllText y Write-Atomico, asi que una funcion que guardara con Set-Content se
    # colaba entera. Barriendo las 533 del archivo aparecieron DOS: Save-DatosPerfil, que ya
    # estaba exenta -asi que daba igual-, y Save-JuegosDos, que no estaba ni exenta ni en la
    # lista de las que deben llevar guarda. O sea que el banco decia "ninguna sin decidir" y
    # habia una.
    if ($t -notmatch 'WriteAllText|AppendAllText|Write-Atomico|Set-Content|Out-File|Export-Clixml|Add-Content') { continue }
    if ($DEBEN -contains $f.Name) { continue }
    if ($EXENTAS.ContainsKey($f.Name)) { continue }
    if ($t -match 'script:invitado') { continue }                              # protegida por su cuenta
    $sinDecidir += $f.Name
}
Comp 'ninguna funcion de guardado sin decidir' ($sinDecidir.Count -eq 0) $(if ($sinDecidir.Count) { "sin decidir: " + ($sinDecidir -join ', ') } else { '' })
if ($sinDecidir.Count) {
    Write-Host '     (protegela con la guarda, o anadela a $EXENTAS aqui arriba con su motivo)' -ForegroundColor Yellow
}

# --- y una de verdad, ejecutada: que con un invitado delante no acumule nada ---
Write-Host ''
Write-Host '  -- y no es solo que lo diga: se ejecuta --'
function Traer([string]$n) {
    $fn = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $fn) { throw "no encuentro $n" }
    return $fn.Extent.Text
}
$script:tiempoJuegoPend = @{}
$script:invitado = $true
Invoke-Expression (Traer 'Add-TiempoJuego')
Add-TiempoJuego 'It Takes Two' 30
Comp 'con invitado, no apunta tiempo de juego' ($script:tiempoJuegoPend.Count -eq 0) ("entradas: " + $script:tiempoJuegoPend.Count)
$script:invitado = $false
Add-TiempoJuego 'It Takes Two' 30
Comp 'y sin invitado sigue apuntando como siempre' ($script:tiempoJuegoPend['It Takes Two'] -eq 30) ("-> " + $script:tiempoJuegoPend['It Takes Two'])

# Add-Rechazo devuelve $false, no $null: el llamador hace "$apuntada = Add-Rechazo ..."
$script:invitado = $true
function ConvertTo-Plain([string]$t) { return $t.ToLower() }
Invoke-Expression (Traer 'Add-Rechazo')
$r = Add-Rechazo 'abre steam'
Comp 'Add-Rechazo devuelve false, no se traga el resultado' ($r -eq $false) ("-> '" + $r + "'")
$script:invitado = $false

Write-Host ''
Write-Host '  -- y que sobreviva a un arranque (16,3 al dia) --'
# Sin esto, braya pone el modo invitado, le deja la consola a alguien, Nova se relanza y el
# modo se ha ido solo: a partir de ahi se guarda todo lo que diga esa persona, por muchas
# guardas que lleve cada funcion.
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('inv-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $TmpDir -Force
$sw = [System.Diagnostics.Stopwatch]::StartNew()
function Write-Atomico([string]$r, [string]$t, [bool]$b = $false) { [System.IO.File]::WriteAllText($r, $t, (New-Object System.Text.UTF8Encoding($false))) }
$InvitadoPath = Join-Path $TmpDir 'invitado.json'
Invoke-Expression (Traer 'Save-Invitado')
Invoke-Expression (Traer 'Restore-Invitado')
$script:invitado = $true
Save-Invitado
Comp 'el modo invitado queda apuntado' (Test-Path -LiteralPath $InvitadoPath) ''
$script:invitado = $false                      # esto es lo que pasa al reiniciar Nova
Restore-Invitado
Comp 'y tras reiniciar, sigue puesto' ($script:invitado) 'antes se iba solo 16 veces al dia'
# y caduca a los 30 minutos, como Test-FinInvitado
[System.IO.File]::WriteAllText($InvitadoPath, ('{ "desde": "' + (Get-Date).AddMinutes(-31).ToString('o') + '" }'), (New-Object System.Text.UTF8Encoding($false)))
$script:invitado = $false
Restore-Invitado
Comp 'pero uno de hace media hora ya no' (-not $script:invitado) 'los mismos 30 min de Test-FinInvitado'
Comp 'y se borra el rastro' (-not (Test-Path -LiteralPath $InvitadoPath)) ''
$script:invitado = $true; Save-Invitado
$script:invitado = $false; Save-Invitado
Comp 'al salir del modo, el fichero se va' (-not (Test-Path -LiteralPath $InvitadoPath)) ''
try { Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Host ''
if ($mal -gt 0) { Write-Host "$mal casos MAL" -ForegroundColor Red; exit 1 }
Write-Host 'todo correcto' -ForegroundColor Green
