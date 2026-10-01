# MOVER UN JUEGO A OTRO DISCO, HABLANDO (30/09, la 3 de las 20 funciones nuevas)
#
# LO QUE ESTA SECCION DEFIENDE es que Nova NO mueva los ficheros ella: mover un juego de Steam a
# mano es mover la carpeta de 'common', mover su appmanifest y que Steam se entere, y si sale a
# medias hay que volver a bajar el juego -139,57 GB en el caso mas gordo de braya-. Lo que si hace
# es comprobar que cabe, que el disco esta puesto, y abrir Steam donde esta el boton.
#
# TODO CON DISCOS Y JUEGOS DE PEGA: depender de que braya tenga la tarjeta puesta hoy seria un rojo
# que no significa nada (la manera 5 de salir verde mintiendo).
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
# LA RAIZ SALE DE $PSScriptRoot, NO A FUEGO (1/10, lo cazo el banco 2n78). Aqui estaba escrita la
# ruta de la consola de braya: en otra maquina -o si mueve la carpeta- este banco mediria un repo que
# no es este. Es la misma regla que siguen los demas bancos de la casa.
$LogDir = $Raiz
foreach ($n in @('ConvertTo-Plain', 'Get-EspacioPorJuego', 'Get-FraseMoverJuego')) { Invoke-Expression (Traer $n) }
function Log([string]$m) { }
function Get-JuegosMem { return ([pscustomobject]@{}) }

# un juego gordo y otro pequeno
$script:Juegos = @(
    @{ appid = '111'; nombre = 'Juegazo Gordo'; bytes = 140GB },
    @{ appid = '222'; nombre = 'Juego Chico';   bytes = 2GB }
)
# los discos de pega: C fija casi llena, D extraible con sitio, y una E que NO esta puesta
function Get-Unidades {
    return @(
        [pscustomobject]@{ letra = 'C'; tipo = 'fija';      etiqueta = 'Windows'; bytesLibres = 27GB;  bytesTotal = 476GB },
        [pscustomobject]@{ letra = 'D'; tipo = 'extraible'; etiqueta = 'Tarjeta'; bytesLibres = 400GB; bytesTotal = 512GB }
    )
}

Write-Host ''
Write-Host '-- 1. cabe: lo dice y abre Steam donde esta el boton --'
$r = Get-FraseMoverJuego 'Juegazo Gordo' 'la tarjeta'
Comp 'dice los gigas del juego' ($r.texto -match '140 gigas') "$($r.texto)"
Comp '  y los que quedan en el destino' ($r.texto -match '400') ''
Comp '  y dice que cabe' ($r.texto -match 'cabe') ''
Comp '  y avisa de que el boton lo pulsas tu' ($r.texto -match 'Archivos locales') 'si cree que ya esta movido, pierde el juego'
Comp '  y abre las propiedades de ESE juego' ($r.abrir -eq 'steam://gameproperties/111') "$($r.abrir)"

Write-Host ''
Write-Host '-- 2. lo que NO cabe no se empieza --'
# C tiene 27 GB libres y el juego ocupa 140: ni con margen ni sin el.
$r2 = Get-FraseMoverJuego 'Juegazo Gordo' 'C'
Comp 'dice que no cabe' ($r2.texto -match 'No cabe') "$($r2.texto)"
Comp '  y NO abre nada' (-not $r2.abrir) 'abrir Steam para nada es peor que no abrirlo'
# EL MARGEN IMPORTA: 2 GB caben en 27, pero un destino a cero es un destino inservible. Se prueba
# con un juego que cabria justo sin margen y no con margen.
$script:Juegos += @{ appid = '333'; nombre = 'Juego Al Limite'; bytes = 25GB }
$r3 = Get-FraseMoverJuego 'Juego Al Limite' 'C'
Comp 'y deja margen libre en el destino' ($r3.texto -match 'No cabe') '25 GB en 27 libres: no, hay que dejar hueco'
Comp '  y lo dice nombrando el margen' ($r3.texto -match 'margen') ''

Write-Host ''
Write-Host '-- 3. un disco que no esta puesto --'
$r4 = Get-FraseMoverJuego 'Juego Chico' 'E'
Comp 'dice que ese disco no esta' ($r4.texto -match 'no esta puesto') "$($r4.texto)"
Comp '  y NO abre nada' (-not $r4.abrir) ''

Write-Host ''
Write-Host '-- 4. sin tarjeta puesta, no la inventa --'
function Get-Unidades { return @([pscustomobject]@{ letra = 'C'; tipo = 'fija'; etiqueta = 'W'; bytesLibres = 27GB; bytesTotal = 476GB }) }
$r5 = Get-FraseMoverJuego 'Juego Chico' 'la tarjeta'
Comp 'dice que no ve ninguna tarjeta' ($r5.texto -match 'No veo ninguna tarjeta') "$($r5.texto)"
$r6 = Get-FraseMoverJuego 'Juego Chico' ''
Comp 'y con un solo disco dice que no hay donde' ($r6.texto -match 'Solo tienes un disco') "$($r6.texto)"

Write-Host ''
Write-Host '-- 5. lo que no existe y lo que es demasiado corto --'
Comp 'un juego que no esta no se inventa' ((Get-FraseMoverJuego 'Juego Que No Existe 99' 'la tarjeta').texto -match 'No encuentro') ''
Comp 'un nombre de dos letras se rechaza' ((Get-FraseMoverJuego 'ab' 'la tarjeta').texto -match 'un poco mas largo') 'casaria con cualquier juego'

Write-Host ''
Write-Host '-- 6. el cableado --'
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp 'hay un patron que saca moverJuego' ($sinCom -match "kind = 'moverJuego'") ''
Comp '  y el ejecutor lo atiende' ($sinCom -match "'moverJuego' \{") ''
# EL DESTINO TIENE QUE SONAR A DISCO (1/10, lo cazo el banco de colisiones 2n). El patron aceptaba
# cualquier destino y "mueve spotify a la otra pantalla" se iba a mover un juego de disco en vez de
# mandar la ventana al otro monitor. Se comprueba sobre el patron, que es donde estaba el fallo.
# Se busca LA LINEA del patron, no un trozo de 400 caracteres a su alrededor: ahi caian los regex
# de los patrones vecinos y la comprobacion decia cualquier cosa. Primer intento de escribirla.
$lineaPat = @(($sinCom -split "`n") | Where-Object { $_ -match 'mueve\|muever\|pasa\|cambia' }) | Select-Object -First 1
Comp '  se encuentra la linea del patron' ([bool]$lineaPat) ''
Comp '  y el destino se limita a discos' ($lineaPat -match 'tarjeta' -and $lineaPat -match 'unidad') 'si no, se come "a la otra pantalla"'
Comp '  y no acaba en un comodin que se lo coma todo' ($lineaPat -notmatch '\(\.\+\)\$') 'un (.+) final acepta "a la otra pantalla"'
# Y NO MUEVE FICHEROS: ni Move-Item ni robocopy en este camino. Es la guarda de la seccion.
$cuerpo = Traer 'Get-FraseMoverJuego'
Comp 'la funcion NO mueve ni un fichero' (($cuerpo -notmatch 'Move-Item') -and ($cuerpo -notmatch 'robocopy') -and ($cuerpo -notmatch 'Copy-Item')) 'un movido a medias son 139 GB de redescarga'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'Nova comprueba si el juego cabe en el otro disco, y no lo mueve ella' -ForegroundColor Green
exit 0
