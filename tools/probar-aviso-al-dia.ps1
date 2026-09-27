# EL AVISO APARCADO SE REHACE AL DECIRLO, NO SE REPITE EL DE HACE HORAS (27/09, idea 119 de las 121)
#
# EL DATO: 4.187 avisos aparcados en el registro, y las tres cabezas de la lista son
#     oido-ruido 1.694    gmail-lleno 1.649    disco-poco 843
# con DOS problemas distintos:
#
# 1. LA CIFRA ENVEJECE (disco-poco, 843). Su texto lleva el numero dentro -"Te quedan 10.2 gigas en
#    el disco"- y el disco de braya no se esta quieto: de las 75 lecturas 'DISCO:' del registro salen
#    VEINTICINCO saltos de un giga o mas en menos de una hora, y el peor son 9,1 GB en UN MINUTO
#    (25/09, de 35,7 a 26,6 entre las 22:09:26 y las 22:10:26). El 25/09 el disco se movio 35,2 gigas
#    en el mismo dia, de 7,8 a 43,0.
#
# 2. EL HECHO DEJA DE SER CIERTO (oido-ruido, 1.694, el mas aparcado). No lleva cifra: dice "Tengo un
#    zumbido de fondo encima y me cuesta oirte". Decirlo cuando el zumbido ya se fue no es un numero
#    viejo, es una queja falsa.
#
# LO QUE ESTE BANCO PROTEGE, y lo primero es la promesa que esta cola vino a cumplir:
#   1. que NO se tire nada por viejo, nunca: solo si el hecho ya no se cumple
#   2. que si el dato no se puede releer, se diga igual
#   3. que la cifra se ponga al dia con la de ahora
#   4. que el liston no sea un numero nuevo, sino el mismo que disparo el aviso
#   5. que 'no se si hay ruido' no cuente como 'no hay ruido'
#   6. y que gmail-lleno -1.649 aparcados, sin cifra y con el hecho estable- se suelte como siempre
$ErrorActionPreference = 'Stop'
trap { Write-Host ('  MAL  el banco se rompio: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$arbol = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

# LAS PIEZAS Y LA LISTA, DEL FICHERO REAL
$quiero = @('Get-HechoAviso', 'Get-AvisoAlDia')
$defs = $arbol.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
$puestas = 0
foreach ($q in $quiero) {
    $d = @($defs | Where-Object { $_.Name -eq $q })
    if ($d.Count -ne 1) { Comp ("la funcion " + $q + " esta una sola vez") $false ([string]$d.Count); continue }
    Invoke-Expression $d[0].Extent.Text
    $puestas++
}
Comp 'las 2 piezas salen del fichero real' ($puestas -eq $quiero.Count) ([string]$puestas + ' de ' + $quiero.Count)
$asg = $arbol.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq '$AvisoRehacerClaves' }, $true)
Invoke-Expression ('$AvisoRehacerClaves = ' + $asg.Right.Extent.Text)
Comp 'la lista de claves sale del fichero real' (@($AvisoRehacerClaves).Count -ge 3) (@($AvisoRehacerClaves) -join ', ')

# LOS TEXTOS SON LOS DE VERDAD, copiados del registro
$TXT_POCO = 'Te quedan 10.2 gigas en el disco. Preguntame que ocupa mas.'
$TXT_CRIT = 'Quedan 1.4 gigas en el disco, casi nada. Voy a empezar a fallar: borra algo o dime que ocupa mas.'
$TXT_RUIDO = 'Tengo un zumbido de fondo encima y me cuesta oirte. Acercame el microfono si puedes.'
$TXT_GMAIL = 'Recuerda que tienes el almacenamiento de Gmail lleno y puedes dejar de recibir correos.'

Write-Host ''
Write-Host '-- 1. EL HECHO SE SACA DE LA CLAVE Y DEL TEXTO, SIN TOCAR A NADIE --'
$h1 = Get-HechoAviso 'disco-poco' $TXT_POCO
Comp '1a. de disco-poco sale su cifra' (([string]$h1.tipo -eq 'disco') -and ([double]$h1.gb -eq 10.2)) ([string]$h1.tipo + ' ' + [string]$h1.gb)
Comp '1b. y el texto de la cifra, para poder sustituirla' ([string]$h1.texto -eq '10.2') ([string]$h1.texto)
$h2 = Get-HechoAviso 'disco-critico' $TXT_CRIT
Comp '1c. de disco-critico tambien' (([string]$h2.tipo -eq 'disco') -and ([double]$h2.gb -eq 1.4)) ([string]$h2.gb)
$h3 = Get-HechoAviso 'oido-ruido' $TXT_RUIDO
Comp '1d. de oido-ruido sale el hecho, sin cifra' ([string]$h3.tipo -eq 'ruido') '1.694 aparcados, el mas de todos'
Comp '1e. de gmail-lleno NO sale nada' ($null -eq (Get-HechoAviso 'gmail-lleno' $TXT_GMAIL)) '1.649 aparcados: sin cifra y el hecho no se mueve'
# Y LO QUE DE VERDAD PROTEGE LA LISTA DE CLAVES: un aviso que hable de gigas SIN ser del disco. Sin
# ella, a ese se le cambiaria la cifra por el sitio libre de C:, que no tiene nada que ver.
Comp '1e2. ni de otro que hable de gigas' ($null -eq (Get-HechoAviso 'descarga-lista' 'La descarga de 40 gigas ya termino.')) 'esa cifra no es el disco libre'
Comp '1f. ni de una clave cualquiera' ($null -eq (Get-HechoAviso 'bateria-llena' 'Ya esta cargada del todo.')) 'esas se sueltan como siempre'
# y si el texto de un disco NO trae cifra, tampoco se inventa
Comp '1g. sin cifra en el texto, no hay hecho' ($null -eq (Get-HechoAviso 'disco-poco' 'Te queda poco disco.')) ''
Comp '1h. y la coma decimal tambien vale' ([double](Get-HechoAviso 'disco-poco' 'Te quedan 10,2 gigas en el disco.').gb -eq 10.2) 'por si el formato cambia'

Write-Host ''
Write-Host '-- 2. LA CIFRA SE PONE AL DIA CON LA DE AHORA --'
$v = @{ clave = 'disco-poco'; texto = $TXT_POCO; nivel = 'medio'; cada = 720; hecho = $h1 }
$r = Get-AvisoAlDia $v 8.3 $null 15 2
Comp '2a. sigue valiendo' ($r.vale) 'con 8,3 gigas el hecho es verdad'
Comp '2b. y la cifra es la de ahora' ($r.texto -match '8\.3 gigas') ([string]$r.texto)
Comp '2c. sin la vieja por ningun lado' (-not ($r.texto -match '10\.2')) 'lo demas de la frase no se toca'
Comp '2d. y lo dice en el log' ($r.porque -match 'la cifra pasa de 10.2 a 8.3') ([string]$r.porque)
# si la cifra es la misma, no hay nada que decir
$r0 = Get-AvisoAlDia $v 10.2 $null 15 2
Comp '2e. si no cambio, no se dice nada' (($r0.vale) -and ($r0.porque -eq '')) ''

Write-Host ''
Write-Host '-- 3. SI EL HECHO YA NO SE CUMPLE, NO SE DICE --'
# el 25/09 el disco paso de 7,8 a 43,0 el mismo dia
$r43 = Get-AvisoAlDia $v 43.0 $null 15 2
Comp '3a. con 43 gigas no se dice' (-not $r43.vale) 'el 25/09 paso de 7,8 a 43,0 en el mismo dia'
Comp '3b. y se dice POR QUE, no que sea viejo' ($r43.porque -match 'por encima de los 15') ([string]$r43.porque)
# el liston es el que dispara: 15 para poco
Comp '3c. justo en 15 ya no se dice' (-not (Get-AvisoAlDia $v 15.0 $null 15 2).vale) 'es el liston que lo dispara'
Comp '3d. con 14,9 si' ((Get-AvisoAlDia $v 14.9 $null 15 2).vale) ''
# y el critico tiene el SUYO, que es otro
$vc = @{ clave = 'disco-critico'; texto = $TXT_CRIT; nivel = 'alto'; cada = 60; hecho = $h2 }
Comp '3e. el critico vale con 1,9 gigas' ((Get-AvisoAlDia $vc 1.9 $null 15 2).vale) 'su liston son 2, no 15'
Comp '3f. y con 3 ya no' (-not (Get-AvisoAlDia $vc 3.0 $null 15 2).vale) 'aunque siga por debajo de 15'
# EL LISTON ENTRA POR PARAMETRO: si braya cambia el de config, esto cambia con el
Comp '3g. si braya sube el critico a 5, cambia' (-not (Get-AvisoAlDia $vc 6.0 $null 15 5).vale) 'no es un numero de aqui'
Comp '3h. y con 4 sigue valiendo' ((Get-AvisoAlDia $vc 4.0 $null 15 5).vale) ''

Write-Host ''
Write-Host '-- 4. SI NO SE PUEDE RELEER, SE DICE IGUAL --'
$rNo = Get-AvisoAlDia $v -1 $null 15 2
Comp '4a. sin poder leer el disco, se dice' ($rNo.vale) 'callar el que si importaba es lo que esto no puede hacer'
Comp '4b. con la cifra que tenia' ($rNo.texto -match '10\.2') ([string]$rNo.texto)
Comp '4c. y se apunta que no se pudo' ($rNo.porque -match 'no pude releer el disco') ([string]$rNo.porque)

Write-Host ''
Write-Host '-- 5. EL ZUMBIDO: "NO SE" NO ES "NO HAY" --'
$vr = @{ clave = 'oido-ruido'; texto = $TXT_RUIDO; nivel = 'medio'; cada = 120; hecho = $h3 }
Comp '5a. si sigue habiendo ruido, se dice' ((Get-AvisoAlDia $vr -1 $true 15 2).vale) ''
Comp '5b. si ya no hay, no se dice' (-not (Get-AvisoAlDia $vr -1 $false 15 2).vale) '1.694 aparcados que podian ser una queja falsa'
Comp '5c. y se dice por que' ((Get-AvisoAlDia $vr -1 $false 15 2).porque -match 'el zumbido ya no esta') ''
Comp '5d. si NO SE SABE, se dice igual' ((Get-AvisoAlDia $vr -1 $null 15 2).vale) 'no saber no calla una promesa'

Write-Host ''
Write-Host '-- 6. LO QUE NO TIENE HECHO SE SUELTA COMO SIEMPRE --'
$vg = @{ clave = 'gmail-lleno'; texto = $TXT_GMAIL; nivel = 'medio'; cada = 10080; hecho = (Get-HechoAviso 'gmail-lleno' $TXT_GMAIL) }
$rg = Get-AvisoAlDia $vg 43.0 $false 15 2
Comp '6a. gmail-lleno se dice igual' ($rg.vale) 'aunque el disco este lleno y no haya ruido'
Comp '6b. y con su texto sin tocar' ($rg.texto -eq $TXT_GMAIL) ''
# y un aviso guardado ANTES de este cambio (sin campo 'hecho') no se rompe
$viejo = @{ clave = 'disco-poco'; texto = $TXT_POCO; nivel = 'medio'; cada = 720 }
$rv = Get-AvisoAlDia $viejo 43.0 $null 15 2
# (la guarda del campo ausente es defensa doble: PowerShell aguanta el nulo y devuelve lo mismo sin
#  ella. Se deja porque leerla explica que pasa con los que ya estan en tmp, no porque haga falta.)
Comp '6c. un aviso guardado antes del cambio se dice' ($rv.vale) 'los que ya estan en tmp no traen el campo'
Comp '6d. y con su texto de entonces' ($rv.texto -eq $TXT_POCO) 'mejor una cifra vieja que perderlo'

Write-Host ''
Write-Host '-- 7. EL CABLEADO --'
Comp '7a. el hecho se guarda con el aviso' ($sinCom -match '(?s)hecho = \$hechoA') ''
Comp '7b. y sale de la clave y el texto' ($sinCom -match '\$hechoA = Get-HechoAviso \$clave \$texto') 'ni un llamador de Send-AvisoEntorno cambia'
Comp '7c. se rehace al soltarlo' ($sinCom -match '\$al = Get-AvisoAlDia \$v \$gbAhora \$ruidoAhora') ''
# SOBRE EL CUERPO DE LA FUNCION: hay otro DriveInfo('C') en el bloque del disco del bucle, y
# buscarlo en el fichero entero hacia que quitar este no pusiera rojo nada. Y el ancla del orden es
# la llamada a Get-AvisoAlDia y no 'foreach ($v in $vivos)', que sale DOS veces en esta funcion -la
# primera en la rama de solo-caducar-.
$cuerpoS = @($defs | Where-Object { $_.Name -eq 'Send-AvisoEsperaSuelta' })[0].Extent.Text
Comp '7d. el disco se lee UNA vez para todos' ($cuerpoS -match "DriveInfo\('C'\)") 'tres avisos de disco no son tres DriveInfo'
Comp '7d2. y antes del bucle que los suelta' (($cuerpoS.IndexOf("DriveInfo('C')") -ge 0) -and ($cuerpoS.IndexOf("DriveInfo('C')") -lt $cuerpoS.IndexOf('Get-AvisoAlDia'))) ''
Comp '7e. el liston critico sale de config' ($sinCom -match "Get-AvisoAlDia \`$v \`$gbAhora \`$ruidoAhora 15 \(\[double\]\(Get-Cfg 'entorno' 'discoCriticoGb'") 'el mismo que dispara el aviso'
Comp '7f. y el ruido solo se cree si el estado esta fresco' ($sinCom -match 'if \(Test-EstadoFresco\) \{ \$ruidoAhora = \[bool\]\(Get-OidoConRuido\) \}') 'Get-OidoConRuido da $false tambien cuando no sabe'
Comp '7g. lo tirado se cuenta aparte' ($sinCom -match "Add-Estadistica 'aviso-caduco-hecho'") 'para poder ver si esto se lleva de mas'
Comp '7h. y la cola de caducados por PLAZO sigue igual' ($sinCom -match "Add-Estadistica 'aviso-caducado'") 'esos se siguen diciendo tarde'
Comp '7i. y se siguen diciendo, no se tiran' ($sinCom -match "Send-AvisoEntorno 'lo-que-no-dije'") ''
$cuerpoA = ((@($defs | Where-Object { $_.Name -eq 'Get-AvisoAlDia' })[0].Extent.Text -split "`n") |
            Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
Comp '7j. Get-AvisoAlDia es pura' (-not ($cuerpoA -match '(Get-Date|Test-Path|DriveInfo|Get-Cfg|Log |Get-OidoConRuido)')) 'por eso se le pueden correr veinte casos'
Comp '7k. y no lleva ningun factor inventado' (-not ($cuerpoA -match '\* 2\.0|\* 1\.[0-9]|\* 3\b')) 'el liston es el que dispara el aviso'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el aviso aparcado se dice con el dato de ahora, o no se dice' -ForegroundColor Green
exit 0
