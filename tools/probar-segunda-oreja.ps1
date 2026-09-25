# TODO LO QUE OYO CADA MOTOR VA JUNTO A CLAUDE (25/09, idea de braya)
#
# SU FRASE: "lo que entienden todos los modelos deberia enviarse y una IA como Claude debe
# armar la frase entera de ser necesario".
#
# EL CASO QUE LO PIDE, del 25/09 a la 01:25, con braya delante y enfadado: pregunto hace cuanto
# que un amigo suyo se habia desconectado. Parakeet lo transcribio PERFECTO, con el nombre bien.
# Y Nova tiro ese texto porque "no cubre la voz (3.8 letras por segundo, mi liston de hoy 4.0)":
# braya hablaba algo mas despacio de lo normal, y ese es justo el sintoma que se usa para
# sospechar que una transcripcion se dejo palabras. Viajo la de Whisper, que habia convertido
# el nombre del amigo en "base". Con "base" dentro, ni el reconocedor local ni Claude podian
# hacer nada, y Nova contesto que no sabia. La respuesta correcta estuvo en memoria y se tiro.
#
# LO MEDIDO: 29 descartes por cobertura en 514 transcripciones (5,6 %). De los cuatro ultimos,
# en TRES la descartada era mejor que la que se uso. Dos de ellos, por DOS DECIMAS.
#
# POR QUE ESTA ES LA SOLUCION BUENA Y NO SUBIR EL LISTON: el liston esta medido y hace su
# trabajo -desconfiar de una transcripcion que parece corta-. Lo que sobraba era TIRAR lo
# descartado. Y el envio sale gratis: cuando el local no entiende una orden, Nova YA llama a
# Claude para traducirla (1,5 s medidos). Mandarle las tres candidatas es la MISMA llamada con
# mas informacion, ni una peticion mas.
#
# DONDE NO SE HACE, a proposito: en modo 'accion' no van. Ahi el agente tiene manos, y una
# frase alternativa mal entendida podria ejecutar algo que braya no pidio, que es la regla 1.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$PY = Join-Path $Raiz 'wake_vosk.py'
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
$py = [IO.File]::ReadAllText($PY)
$pyCod = (($py -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host '-- 1. el oido guarda lo que descarta en vez de tirarlo --'
Comp 'el oido tiene ruta para las candidatas' ($pyCod -match 'RUTA_OIDOS\s*=') ''
Comp 'y aparta lo que la cobertura descarta' ($pyCod -match '_parakeet_descartado\s*=\s*texto') 'antes se perdia aqui'
Comp 'el descarte por cobertura sigue existiendo' ($pyCod -match 'no cubre la voz') 'el liston esta medido: no se toca'
Comp 'y las entrega con el dictado' ($pyCod -match 'escribir\(RUTA_OIDOS') ''
Comp 'con los cuatro motores' (($pyCod -match 'parakeet-corto') -and ($pyCod -match '"whisper"') -and ($pyCod -match '"vosk"')) ''
# HAY DOS CAMINOS QUE ENTREGAN UN DICTADO (25/09, lo cazo este banco): el normal y el del
# boton cortado a mano. LOS DOS tienen que tocar el fichero de candidatas: el que no lo haga
# deja ahi las de la orden anterior, y el asistente se las mandaria a Claude junto a una frase
# que no tiene nada que ver. Se comprueba cada entrega por separado, no la primera que salga.
$entregas = @([regex]::Matches($pyCod, 'escribir\(TEXTO, texto_final\)'))
Comp 'se encuentran las dos entregas de dictado' ($entregas.Count -eq 2) "$($entregas.Count)"
$conLimpieza = 0
foreach ($m in $entregas) {
    $desde = [Math]::Max(0, $m.Index - 900)
    $antes = $pyCod.Substring($desde, $m.Index - $desde)
    if ($antes -match 'escribir\(RUTA_OIDOS') { $conLimpieza++ }
}
Comp 'y las DOS tocan el fichero de candidatas antes de entregar' ($conLimpieza -eq $entregas.Count) "$conLimpieza de $($entregas.Count)"
Comp 'y se vacia lo de la orden anterior' ($pyCod -match '_parakeet_descartado = ""') 'si no, contestaria a lo de antes'
# EL FILTRO DE REPETIDAS DEL LADO PYTHON (25/09, lo cazo una rotura). El banco ejecuta la
# funcion de PowerShell, que tiene su propio filtro, pero el del oido no lo ejecuta nadie aqui:
# si se cae, dos motores que oyeron lo mismo mandan la misma linea dos veces y Claude recibe
# ruido. Se mira que siga estando.
Comp 'y el oido no repite dos candidatas iguales' ($pyCod -match 'if any\(_t == _y for _x, _y in _cands\)') 'dos motores aciertan igual muy a menudo'

Write-Host ''
Write-Host '-- 2. el asistente se las manda a Claude, y solo al traducir --'
Comp 'existe Get-OtrosOidos' ($sinCom -match 'function Get-OtrosOidos') ''
# SE ANCLA EN LA LLAMADA, NO EN EL PRIMER "if modo -eq traducir" (25/09, lo cazo el propio
# banco): esa condicion aparece varias veces en la funcion -una para el rotulo de la capsula,
# otra para el contexto- y coger la primera miraba un bloque que no tiene nada que ver.
$iU = $sinCom.IndexOf('Get-OtrosOidos $text')
Comp 'y se usa al montar el prompt de traducir' ($iU -gt 0) ''
# el bloque que la envuelve: desde el "if" de mas arriba hasta un poco despues
$iP = if ($iU -gt 0) { $sinCom.LastIndexOf('if (', $iU) } else { -1 }
$blP = if ($iP -gt 0) { $sinCom.Substring($iP, [Math]::Min(700, $sinCom.Length - $iP)) } else { '' }
Comp 'dentro de una guarda de modo' ($blP -match "modo -eq 'traducir'") "$($blP.Split([char]10)[0].Trim())"
# LA GUARDA QUE MAS IMPORTA: en 'accion' el agente tiene manos
Comp 'y NO en modo accion' ($blP -and -not ($blP -match "modo -eq 'accion'")) 'ahi una frase mal entendida ejecutaria algo'
# LA FUNCION ENTERA, DEL ARBOL, NO 2200 CARACTERES (25/09, lo cazo una rotura). Con un
# Substring de largo fijo el bloque se quedaba corto POR POCO -la linea que importa cae sobre
# el caracter 2300- y una rotura que borraba justo esa linea salia verde. Es la manera 8 de
# salir verde mintiendo. El arbol devuelve la funcion entera mida lo que mida.
$dF = $ast.Find({ param($x)
    $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq 'Get-OtrosOidos' }, $true)
$blA = if ($dF) { $dF.Extent.Text } else { '' }
Comp 'le dice a Claude que son la MISMA frase' ($blA -match 'MISMA frase') 'si no, contestaria a varias'
Comp 'y que las ignore si la de arriba se entiende' ($blA -match 'IGNORA') ''

Write-Host ''
Write-Host '-- 3. LA FUNCION, SACADA DEL ARCHIVO Y EJECUTADA --'
foreach ($f in @('ConvertTo-Plain', 'Get-OtrosOidos')) {
    $d = $ast.Find({ param($x)
        $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    if (-not $d) {
        Comp ("se saca " + $f + " del arbol") $false ''
        Write-Host ''
        Write-Host "  $mal MAL"
        exit 1
    }
    Invoke-Expression $d.Extent.Text
}
function Log([string]$m) { }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('nova-oidos-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $ruta = Join-Path $tmp 'dictado-oidos.txt'

    Comp 'sin fichero no manda nada' ([string]::IsNullOrEmpty((Get-OtrosOidos 'lo que sea' $ruta))) ''

    # EL CASO REAL DEL 25/09
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @(
        'parakeet-corto: Hace cuanto que Bey se desconecto',
        'vosk: hace cuanto que bei se desconecto')
    $r = Get-OtrosOidos 'hace cuanto que base desconecto' $ruta
    Comp 'con candidatas distintas, arma el bloque' ($r -match 'Bey') ''
    Comp '  y van las dos' (($r -match 'parakeet-corto') -and ($r -match 'vosk')) ''
    Comp '  y explica que son la misma frase' ($r -match 'MISMA frase') ''

    # LA QUE YA SE PROBO NO ES UNA SEGUNDA OPINION
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @('whisper: abre steam')
    Comp 'la que ya se probo no se manda' ([string]::IsNullOrEmpty((Get-OtrosOidos 'abre steam' $ruta))) ''
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @('whisper: Abre Steam')
    Comp 'ni con otras tildes o mayusculas' ([string]::IsNullOrEmpty((Get-OtrosOidos 'abre steam' $ruta))) 'se compara en plano'

    # VACIAS FUERA
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @('whisper:   ', '   ')
    Comp 'las vacias no cuentan' ([string]::IsNullOrEmpty((Get-OtrosOidos 'abre steam' $ruta))) ''

    # SE CONSUME
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @('whisper: pon musica')
    [void](Get-OtrosOidos 'otra cosa' $ruta)
    Comp 'se consume al leerla' (-not (Test-Path -LiteralPath $ruta)) 'unas candidatas viejas contestarian a lo de antes'

    # Y NO SE DUPLICAN
    Set-Content -LiteralPath $ruta -Encoding UTF8 -Value @('whisper: abre steam', 'whisper: abre steam', 'vosk: abre steam')
    $r = Get-OtrosOidos 'otra cosa' $ruta
    Comp 'no repite la misma linea dos veces' ((@([regex]::Matches($r, 'whisper: abre steam'))).Count -eq 1) ''
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  lo que oyo cada motor llega junto'
exit 0
