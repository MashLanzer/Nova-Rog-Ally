# EL LOGRO NO SE CONTABA A SI MISMO (25/09, idea 49 de las 50).
#
# En nova_ui.cs, el switch de Evento() repartia asi: casi todos los gestos entran por
# Gesto(arg) -que apunta en tmp\gestos.log, mueve el humor y pone la cara- y el logro entraba
# por Logro() a secas, que solo pinta el oro y suena. Resultado medido: 'logro' sale CERO
# veces en las 3.518 lineas del diario de gestos, mientras 'orgullo' sale 188 y 'aprendido'
# 16. Y no es que no pasara: en el registro de catorce dias hay 11 logros de Steam, 10
# medallas de hora de juego y 11 fechas especiales.
#
# Treinta y dos momentos buenos que Nova vivio, celebro en pantalla y no apunto en ningun
# sitio. Por eso no salen en el resumen de la semana -que cuenta los gestos del diario- ni le
# pusieron nunca el humor 'contenta' que Gesto() le da a 'logro' desde que existe.
#
# ESTE BANCO ES DE TEXTO, y no puede ser de otra cosa: la capsula es una ventana de WPF que no
# se puede instanciar desde aqui. O sea que comprueba que la llamada esta puesta y que sigue
# valiendo para lo que se puso; lo que se ve en pantalla lo dice la capsula al arrancar.
$ErrorActionPreference = 'Stop'
# UN BANCO QUE REVIENTA SE PONE ROJO: PowerShell 5.1 con -File sale con codigo 0 aunque el
# script muera a mitad, asi que morir en silencio se daba por bueno.
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$raiz = Split-Path -Parent $PSScriptRoot
$cs = Join-Path $raiz 'nova_ui.cs'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$det) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($det) { "  (" + $det + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($det) { "  (" + $det + ")" })); $script:mal++ }
}
if (-not (Test-Path -LiteralPath $cs)) { Comp 'existe nova_ui.cs' $false ''; exit 1 }
$txt = [IO.File]::ReadAllText($cs, [Text.Encoding]::UTF8)
# SIN COMENTARIOS: el de arriba explica el fallo citando "case \"logro\": Logro();", que es
# justo lo que este banco prohibe. Buscando sobre el texto crudo se encontraria a si mismo.
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^(//|\*|/\*)' }) -join "`n"

# EL CUERPO DE CADA UNA, POR SEPARADO, y no el fichero entero (25/09, lo cazo este banco a la
# primera). La prohibicion de "case \"logro\": Logro()" mirando todo nova_ui.cs se ponia roja
# con el codigo YA ARREGLADO, porque DENTRO de Gesto() esa misma linea existe y es la buena:
# es la que pinta el oro. Lo que se prohibe no es la linea, es la linea EN Evento().
function Cuerpo([string]$todo, [string]$firma) {
    $i = $todo.IndexOf($firma)
    if ($i -lt 0) { return '' }
    $j = $todo.IndexOf("`n    void ", $i + 10)
    if ($j -lt 0) { $j = $todo.Length }
    return $todo.Substring($i, $j - $i)
}
# LA FIRMA SIN EL PARENTESIS DE CIERRE (27/09). Este banco buscaba 'void Gesto(string nombre)'
# literal y desde entonces Gesto() gano un segundo parametro: hoy es
# 'void Gesto(string nombre, char quien = '?')' -el 'quien' que separa lo que dijo braya de lo
# que Nova se dice a si misma-. Con la firma cerrada, Cuerpo() no la encontraba, $cuerpoG salia
# vacio y las CUATRO comprobaciones de la seccion 2 salian rojas sin que nada estuviera mal.
# Antes: 'void Gesto(string nombre)'   Ahora: 'void Gesto(string nombre' (abierta, aguanta que
# manana le pongan un tercer parametro; lo que se vigila es el cuerpo, no la lista de argumentos).
$cuerpoE = Cuerpo $sinCom 'void Evento(string nombre'
$cuerpoG = Cuerpo $sinCom 'void Gesto(string nombre'

# LOS DOS PATRONES QUE IMPORTAN, ESCRITOS UNA SOLA VEZ, porque el detector de la seccion 3 tiene
# que probar EL MISMO patron que se usa de verdad arriba: dos copias que se separan hacen que el
# detector certifique un patron que ya no vigila nada (esa es la manera 15 de salir verde
# mintiendo, doblar la pieza que se prueba).
# LA LLAMADA BUENA, con los argumentos que traiga: el 26/09 la idea 101 le puso el segundo
# -case "logro": Gesto("logro", 't') , la 't' de "esto lo saco el jugando"- y este banco, que
# exigia Gesto("logro") a pelo, se puso rojo con el codigo YA arreglado.
# Antes: 'case\s+"logro":\s*Gesto\("logro"\)'   Ahora: admite ', <lo que sea>' detras.
$reBuena = 'case\s+"logro":\s*Gesto\("logro"\s*(,[^)]*)?\)'
# LA LLAMADA PROHIBIDA EN Evento(): la que pinta el oro y se salta el apunte.
$reMala = 'case\s+"logro":\s*Logro\(\)'

Write-Host '-- 1. el evento del logro entra por la puerta que apunta --'
Comp 'se encuentra Evento()' ($cuerpoE -ne '') ''
Comp 'el evento "logro" llama a Gesto' ($cuerpoE -match $reBuena) 'hoy con la "t" de la idea 101: lo saco el jugando'
# LO QUE SE PROHIBE, por su nombre: la llamada directa que se salta el apunte, EN Evento().
Comp '  y ya no llama a Logro() por la puerta de atras' ($cuerpoE -notmatch $reMala) 'esa era la linea que se saltaba el diario'

Write-Host ''
Write-Host '-- 2. y esa puerta sigue haciendo las tres cosas --'
# NO BASTA CON QUE LA LLAMADA EXISTA: si Gesto() dejara de apuntar, o dejara de llamar a
# Logro(), el cambio de arriba seria peor que el fallo -se perderia hasta el oro-.
Comp 'se encuentra Gesto()' ($cuerpoG -ne '') ''
# AnotarGesto TAMBIEN GANO EL 'quien' (27/09): hoy la linea es 'AnotarGesto(nombre, quien);'.
# Antes se exigia 'AnotarGesto(nombre)' exacto. Se sigue exigiendo que le pase el NOMBRE del
# gesto -si le pasara otra cosa, el diario apuntaria mal- y se admite lo que venga detras.
Comp '  Gesto apunta en el diario' ($cuerpoG -match 'AnotarGesto\(nombre\s*(,[^)]*)?\)') 'sin esto, el logro seguiria sin contarse'
Comp '  Gesto pinta el oro del logro' ($cuerpoG -match 'case\s+"logro":\s*[\r\n\s]*Logro\(\)') 'se ve y suena igual que antes'
Comp '  y le pone el humor contenta' ($cuerpoG -match '"logro"[^\r\n]*Humor\("contenta"' -or $cuerpoG -match 'Humor\("contenta"[^\r\n]*"logro"') 'lo que nunca llego a pasar'

Write-Host ''
Write-Host '-- 3. y el detector detecta (si no, esto seria decoracion) --'
# LA UNICA FORMA DE SABER QUE UN DETECTOR FUNCIONA sin esperar a que pase la desgracia: se le
# pone delante el codigo VIEJO, el que tenia el fallo, y tiene que cazarlo.
$viejo = '            case "destello": Destello(); break;' + "`n" + '            case "logro": Logro(); break;'
Comp 'con el codigo de ayer delante, lo caza' (($viejo -match $reMala) -and ($viejo -notmatch $reBuena)) 'el que dejaba el diario a cero'
# Y QUE LA TOLERANCIA A LOS ARGUMENTOS NO SE HAYA COMIDO LA COMPROBACION (27/09). Al admitir
# 'Gesto("logro", <lo que sea>)' hay que demostrar que el patron sigue diciendo NO a lo que no
# es: otro gesto en esa rama, u otra funcion con nombre parecido. Sin esto, relajar el patron
# seria bajar el liston a escondidas.
$falso1 = '            case "logro": Gesto("orgullo", ''t''); break;'
$falso2 = '            case "logro": GestoFalso("logro", ''t''); break;'
Comp '  y no se traga otro gesto en esa rama' ($falso1 -notmatch $reBuena) 'Gesto("orgullo") no es apuntar el logro'
Comp '  ni una funcion que solo se parece' ($falso2 -notmatch $reBuena) 'GestoFalso() no apunta en el diario'
# LO MISMO PARA EL APUNTE: 'AnotarGesto("logro")' -un literal en vez de la variable- dejaria de
# apuntar los otros veinte gestos, asi que el patron tiene que rechazarlo.
Comp '  y el apunte exige la variable nombre' ('AnotarGesto("logro", quien);' -notmatch 'AnotarGesto\(nombre\s*(,[^)]*)?\)') 'un literal ahi romperia los otros gestos'

Write-Host ''
Write-Host '-- 4. y el diario, como esta hoy (informativo, no es un rojo) --'
# ESTO NO PUEDE SER UN FALLO, y es importante: el diario solo empezara a traer 'logro' cuando
# alguien recompile la capsula con Nova parada y vuelva a pasar un logro. Un rojo que depende
# de lo que haya en disco hoy no dice nada del codigo -eso ya costo dos rojos falsos el 25/09-,
# asi que aqui solo se cuenta lo que hay.
$gl = Join-Path $raiz 'tmp\gestos.log'
if (Test-Path -LiteralPath $gl) {
    $lineas = @([IO.File]::ReadAllLines($gl, [Text.Encoding]::UTF8))
    $nLogro = @($lineas | Where-Object { $_ -match '\slogro$' }).Count
    Write-Host ("       el diario lleva " + $lineas.Count + " lineas y " + $nLogro + " son 'logro'")
    if ($nLogro -eq 0) { Write-Host "       (cero todavia: la capsula que corre es la de antes del cambio)" }
} else {
    Write-Host '       no hay tmp\gestos.log todavia'
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  el logro ya se cuenta a si mismo'
exit 0
