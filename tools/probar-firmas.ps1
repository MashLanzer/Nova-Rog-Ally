# LAS PALABRAS QUE ERAN LA ORDEN, NO LA FRASE ENTERA (27/09, idea 89 de las 121)
#
# EL DATO: en 14 dias la nube tradujo 58 frases y 57 eran DISTINTAS entre si; 24 de esas 58
# cayeron en un destino que la nube ya habia producido antes. El aprendizaje de frase entera dio
# 21 traducciones y UNA usada en toda su vida ('aprendida' 1 frente a 'traducida' 42), y las 6
# que quedan en traducciones.json tienen todas usos: 0.
#
# Y EL VALOR REAL, MEDIDO SOBRE ESAS 58 Y SIN ADORNOS: de los 10 destinos repetidos solo DOS
# tienen dos o mas palabras de contenido en comun, y corriendo el algoritmo en orden cronologico
# se habria ahorrado UNA llamada de 58. La ficha decia tres. Se hace igual porque cada llamada
# son 5 a 8 s de espera y porque una firma se gana una vez y sirve para siempre.
#
# LO QUE ESTE BANCO PROTEGE, y las tres primeras son el motivo de que esto no sea un arma:
#   1. que una sola palabra en comun NUNCA forme firma: en los datos reales estan {cierra} ->
#      'cierra todos los programas' y {ring} -> 'cierra elden ring'. Con firmas de una palabra,
#      "cierra steam" cerraria TODOS los programas y "abre elden ring" lo CERRARIA
#   2. que una firma cuyas palabras no aparezcan en el destino se descarte: la nube devuelve a
#      veces un destino sacado del CONTEXTO ('dije que si que lo hagas ahora' -> 'abre ajustes')
#   3. que una firma subconjunto de otra con OTRO destino se descarte por ambigua
#   4. que el caso bueno de verdad -las tres frases reales de 'lee la pantalla'- SI funcione
#   5. que las primeras veces se PREGUNTE, y que dos veces que no la borren
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
$ast = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
function Traer([string]$n) {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $n }, $true)
    if (-not $d) { Comp ('se encuentra ' + $n) $false ''; return '' }
    return $d.Extent.Text
}
foreach ($f in @('ConvertTo-Plain', 'Get-FirmasDisco', 'Save-Firmas', 'Get-ClavesFirma',
                 'Test-FirmaValida', 'Add-CandidatoFirma', 'Find-Firma', 'Get-ClaveFirma',
                 'Add-FirmaRespuesta', 'Remove-Firma')) { Invoke-Expression (Traer $f) }
$txt = [IO.File]::ReadAllText($PS1)

# LA LISTA DE PALABRAS VACIAS SALE DEL FICHERO REAL, no se copia aqui: si un dia se le anade
# 'mira', la firma buena de los datos ({mira, pantalla}) dejaria de existir y este banco lo dira.
$lineas = $txt -split "`r?`n"
$iPV = -1
for ($i = 0; $i -lt $lineas.Count; $i++) { if ($lineas[$i] -match '^\$PALABRAS_VACIAS = @\(') { $iPV = $i; break } }
Comp 'la lista de palabras vacias se lee del fichero' ($iPV -ge 0) ''
$acum = ''
for ($i = $iPV; $i -lt $lineas.Count -and $i -lt ($iPV + 8); $i++) {
    $acum += $lineas[$i] + "`n"
    if ($lineas[$i].TrimEnd().EndsWith(')')) { break }
}
Invoke-Expression $acum
Comp 'y trae lo que se espera' ($PALABRAS_VACIAS -contains 'que' -and $PALABRAS_VACIAS -notcontains 'mira' -and $PALABRAS_VACIAS -notcontains 'pantalla') ([string]@($PALABRAS_VACIAS).Count + ' palabras')

$FirmasPalabrasMin = 2
$FirmasMax = 40
$FirmasCandidatosMax = 6
$FirmasDestinosMax = [int]([regex]::Match($txt, '(?m)^\$FirmasDestinosMax = (\d+)').Groups[1].Value)   # del archivo, no copiado (28/09)
Comp 'el minimo de palabras sale del archivo' ($txt -match '\$FirmasPalabrasMin = 2') 'con una palabra esto seria un arma'
Comp 'y el tope de firmas tambien' ($txt -match '\$FirmasMax = 40') ''

# EL MUNDO DE MENTIRA, DESPUES de cargar lo de verdad
$script:logs = @()
function Log([string]$msg) { $script:logs += @($msg) }
function Add-Estadistica([string]$r, [string]$d = '', [bool]$c = $false) { }
$script:invitado = $false
$script:oidoDudoso = @()
function Test-OidoDudoso([string]$t) { return ($script:oidoDudoso -contains $t) }
$MemoriaDir = Join-Path ([IO.Path]::GetTempPath()) ('nova-firmas-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $MemoriaDir -Force | Out-Null
$FirmasPath = Join-Path $MemoriaDir 'firmas.json'
$FirmasOn = $true
$UTF8 = New-Object Text.UTF8Encoding($false)
function Write-Atomico([string]$ruta, [string]$contenido) { [IO.File]::WriteAllText($ruta, $contenido, $UTF8) }
function Reset {
    $script:firmas = $null
    $script:logs = @()
    $script:invitado = $false
    $script:oidoDudoso = @()
    if (Test-Path -LiteralPath $FirmasPath) { Remove-Item -LiteralPath $FirmasPath -Force }
}
# LA COMA NO SOBRA: 'return @(lista)' en PowerShell desenvuelve la coleccion, y con UNA firma
# dentro llegaba el hashtable suelto, cuyo .Count son sus 6 claves. La casa hace lo mismo en
# Get-Recetas ('return ,$script:recetas') y por esto exactamente.
function Firmas { return ,@((Get-FirmasDisco).firmas) }
function DeQuien([string]$destino) {
    $e = @((Get-FirmasDisco).firmas | Where-Object { $_.destino -eq $destino })
    if ($e.Count -eq 0) { return '' }
    return ((@($e[0].palabras) | Sort-Object) -join ' ')
}

try {
    Write-Host ''
    Write-Host '-- 1. UNA SOLA PALABRA EN COMUN NUNCA ES UNA FIRMA (los casos reales) --'
    Reset
    # las dos primeras frases reales que la nube tradujo a 'cierra todos los programas'
    $null = Add-CandidatoFirma 'cierra todos' 'cierra todos los programas'
    $null = Add-CandidatoFirma 'cierra lo ultimo que habrete' 'cierra todos los programas'
    Comp '1a. {cierra} no forma firma' ((DeQuien 'cierra todos los programas') -eq '') 'si no, "cierra steam" cerraria TODO'
    # y el de elden ring, que es peor: la firma diria CERRAR lo que se pidio abrir
    $null = Add-CandidatoFirma 'sabe que cierra el del ring' 'cierra elden ring'
    $null = Add-CandidatoFirma 'oh elden ring si esta abierto quiero que lo cierres pero dices que ya lo cerraste' 'cierra elden ring'
    Comp '1b. ni {ring}' ((DeQuien 'cierra elden ring') -eq '') '"abre elden ring" lo cerraria'
    # y los otros dos de los datos
    $null = Add-CandidatoFirma 'voy a dejar abrir el steam' 'abre steam'
    $null = Add-CandidatoFirma 'si abre steam' 'abre steam'
    Comp '1c. ni {steam}' ((DeQuien 'abre steam') -eq '') 'lo dice la propia ficha'
    $null = Add-CandidatoFirma 'mira por que no me dices cuanto espacio libre me queda en la consola' 'cuanto espacio me queda'
    $null = Add-CandidatoFirma 'que espacio tengo disponible' 'cuanto espacio me queda'
    Comp '1d. ni {espacio}' ((DeQuien 'cuanto espacio me queda') -eq '') ''
    Comp '1e. y con todo eso no hay ni una firma' ((Firmas).Count -eq 0) ([string](Firmas).Count)

    Write-Host ''
    Write-Host '-- 2. EL CASO DE CONTEXTO: LA NUBE DEVUELVE UN DESTINO QUE LA FRASE NO DICE --'
    Reset
    # dos palabras en comun, pero NINGUNA aparece en el destino: es un destino del contexto
    $null = Add-CandidatoFirma 'dije que si que lo hagas mismo' 'abre ajustes'
    $null = Add-CandidatoFirma 'venga hagas eso mismo' 'abre ajustes'
    Comp '2a. no entra aunque haya dos palabras comunes' ((DeQuien 'abre ajustes') -eq '') 'ninguna palabra esta en el destino'
    Comp '2b. y la guarda esta escrita, no es casualidad' (-not (Test-FirmaValida @('hagas', 'mismo') 'abre ajustes')) ''
    Comp '2c. mientras que con una sola palabra dentro, SI' (Test-FirmaValida @('mira', 'pantalla') 'lee la pantalla') '"pantalla" esta en el destino'

    Write-Host ''
    Write-Host '-- 3. EL CASO BUENO DE VERDAD: LAS TRES FRASES REALES DE "lee la pantalla" --'
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y encuentra otra solucion para llegar a la plataforma' 'lee la pantalla'
    Comp '3a. un solo caso no hace firma' ((Firmas).Count -eq 0) 'hace falta ver la intencion dos veces'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '3b. con el segundo sale {mira pantalla}' ((DeQuien 'lee la pantalla') -eq 'mira pantalla') (DeQuien 'lee la pantalla')
    Comp '3c. y se dice en el registro' (@($script:logs | Where-Object { $_ -match 'FIRMA APRENDIDA' }).Count -eq 1) ''
    $null = Add-CandidatoFirma 'mira la pantalla tu mismo y dime que esta pasando ahora' 'lee la pantalla'
    Comp '3d. la tercera no la rompe' ((DeQuien 'lee la pantalla') -eq 'mira pantalla') (DeQuien 'lee la pantalla')
    # y ahora lo que de verdad importa: una CUARTA frase distinta la encuentra
    $enc = Find-Firma 'mira la pantalla y dime si la descarga acabo'
    Comp '3e. y una frase nueva la encuentra' ($null -ne $enc -and $enc.destino -eq 'lee la pantalla') ''
    Comp '3f. esa frase por texto exacto no existia' ($null -eq (Get-FirmasDisco).candidatos['lee la pantalla'] -or
        @((Get-FirmasDisco).candidatos['lee la pantalla'] | Where-Object { (@($_) -join ' ') -match 'descarga' }).Count -eq 0) 'eso es lo que esta idea arregla'

    Write-Host ''
    Write-Host '-- 4. FALTANDO UNA PALABRA NO CASA --'
    Comp '4a. "mira lo que pone" no casa' ($null -eq (Find-Firma 'mira lo que pone aqui abajo')) 'falta "pantalla"'
    Comp '4b. "pon la pantalla en dos" tampoco' ($null -eq (Find-Firma 'pon la pantalla en dos mitades')) 'falta "mira"'
    Comp '4c. y una palabra suelta nunca' ($null -eq (Find-Firma 'pantalla')) ''

    Write-Host ''
    Write-Host '-- 5. LA MAS LARGA GANA, Y LAS AMBIGUAS NO ENTRAN --'
    Reset
    $null = Add-CandidatoFirma 'abre youtube y pinterest en pantalla dividida' 'abre youtube y abre pinterest y a mitad de pantalla'
    $null = Add-CandidatoFirma 'abre youtube en la pantalla izquierda y pinterest en la pantalla derecha en modo split screen' 'abre youtube y abre pinterest y a mitad de pantalla'
    Comp '5a. la de los datos sale con cuatro palabras' ((DeQuien 'abre youtube y abre pinterest y a mitad de pantalla') -eq 'abre pantalla pinterest youtube') (DeQuien 'abre youtube y abre pinterest y a mitad de pantalla')
    # una firma que es SUBCONJUNTO de esa y va a otro sitio: ambigua
    $null = Add-CandidatoFirma 'abre youtube en la pantalla grande' 'abre youtube'
    $null = Add-CandidatoFirma 'abre youtube y ponlo en la pantalla' 'abre youtube'
    Comp '5b. {abre pantalla youtube} no entra: es subconjunto de otra' ((DeQuien 'abre youtube') -eq '') 'ambigua'
    Comp '5c. y la de cuatro sigue ahi' ((Firmas).Count -eq 1) ([string](Firmas).Count)
    # la mas larga gana cuando dos caben
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y busca la solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    [void](Get-FirmasDisco).firmas.Add(@{ palabras = @('mira', 'pantalla', 'juego'); destino = 'lee la pantalla del juego'
                                         confirmadas = 0; rechazos = 0; usos = 0; visto = '2026-09-27' })
    $g5 = Find-Firma 'mira la pantalla del juego y dime que pone'
    Comp '5d. gana la mas especifica' ($null -ne $g5 -and $g5.destino -eq 'lee la pantalla del juego') ([string]$g5.destino)

    Write-Host ''
    Write-Host '-- 6. LO QUE NO CUENTA COMO UN CASO NUEVO --'
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y dime que ves' 'lee la pantalla'
    $r6 = Add-CandidatoFirma 'mira mi pantalla y dime que ves' 'lee la pantalla'
    Comp '6a. la misma frase dos veces no forma firma' ((Firmas).Count -eq 0) 'un caso repetido es el mismo caso'
    Reset
    $script:oidoDudoso = @('mira la pantalla y dime que ves')
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '6b. de lo mal oido no se aprende' ((Firmas).Count -eq 0) 'el mismo freno que el aprendizaje de frase entera'
    Reset
    $script:invitado = $true
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '6c. y en modo invitado tampoco' ((Firmas).Count -eq 0) 'lo que diga otro no se queda'

    Write-Host ''
    Write-Host '-- 7. UN CASO NUEVO QUE ROMPE LA FIRMA LA RETIRA --'
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '7a. la firma existe' ((DeQuien 'lee la pantalla') -eq 'mira pantalla') ''
    $null = Add-CandidatoFirma 'leeme lo que sale escrito arriba' 'lee la pantalla'
    Comp '7b. y un caso sin esas palabras la retira' ((DeQuien 'lee la pantalla') -eq '') 'entonces no eran la firma de la intencion'
    Comp '7c. y lo dice' (@($script:logs | Where-Object { $_ -match 'retirada' }).Count -eq 1) ''

    Write-Host ''
    Write-Host '-- 8. LA RESPUESTA CUENTA, Y SE PUEDE QUITAR --'
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '8a. nace sin confirmaciones' ((Firmas)[0].confirmadas -eq 0) 'asi las primeras veces pregunta'
    $null = Add-FirmaRespuesta 'mira pantalla' $true
    $null = Add-FirmaRespuesta 'mira pantalla' $true
    Comp '8b. dos veces que si y ya son dos' ((Firmas)[0].confirmadas -eq 2) ([string](Firmas)[0].confirmadas)
    Comp '8c. y cuenta los usos' ((Firmas)[0].usos -eq 2) ([string](Firmas)[0].usos)
    $null = Add-FirmaRespuesta 'mira pantalla' $false
    Comp '8d. un no no la borra' ((Firmas).Count -eq 1) ''
    # Y NO LA CUENTA OTRA PERSONA (27/09): el trinquete de probar-invitado.ps1 pidio decidir esto.
    # El 'si' de una visita no puede confirmar una firma de braya, ni su 'no' borrarsela.
    $script:invitado = $true
    Comp '8d bis. el si de una visita no cuenta' (-not (Add-FirmaRespuesta 'mira pantalla' $true)) ''
    Comp '  ni le sube las confirmaciones' ((Firmas)[0].confirmadas -eq 2) ([string](Firmas)[0].confirmadas)
    Comp '  ni su no se la borra' (-not (Add-FirmaRespuesta 'mira pantalla' $false)) ''
    $script:invitado = $false
    $null = Add-FirmaRespuesta 'mira pantalla' $false
    Comp '8e. dos si' ((Firmas).Count -eq 0) 'como una receta'
    Comp '8f. y lo dice' (@($script:logs | Where-Object { $_ -match 'olvidada: dos veces que no' }).Count -eq 1) ''
    # y a mano, por el destino
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    Comp '8g. se puede quitar por el destino' (Remove-Firma 'lee la pantalla') ''
    Comp '8h. y se va de verdad' (($null -eq (Find-Firma 'mira la pantalla y dime que ves'))) ''
    Comp '8i. con sus candidatos, para que no renazca' (-not (Get-FirmasDisco).candidatos.ContainsKey('lee la pantalla')) ''
    Comp '8j. quitar lo que no hay no revienta' (-not (Remove-Firma 'nunca-visto')) ''

    Write-Host ''
    Write-Host '-- 9. SOBREVIVE AL REINICIO Y NO CRECE SIN FIN --'
    Reset
    $null = Add-CandidatoFirma 'mira mi pantalla y busca otra solucion' 'lee la pantalla'
    $null = Add-CandidatoFirma 'mira la pantalla y dime que ves' 'lee la pantalla'
    $null = Add-FirmaRespuesta 'mira pantalla' $true
    $script:firmas = $null                      # como si Nova se reiniciara
    Comp '9a. la firma se relee del disco' ((DeQuien 'lee la pantalla') -eq 'mira pantalla') ''
    Comp '9b. con su cuenta de confirmaciones' ((Firmas)[0].confirmadas -eq 1) ([string](Firmas)[0].confirmadas)
    Comp '9c. y los candidatos tambien' (@((Get-FirmasDisco).candidatos['lee la pantalla']).Count -eq 2) ([string]@((Get-FirmasDisco).candidatos['lee la pantalla']).Count)
    # el tope
    for ($i = 0; $i -lt ($FirmasMax + 12); $i++) {
        [void](Get-FirmasDisco).firmas.Add(@{ palabras = @(('palabrota' + $i), 'pantalla'); destino = ('destino pantalla ' + $i)
                                             confirmadas = 0; rechazos = 0; usos = 0; visto = '2026-09-27' })
    }
    [void](Save-Firmas)
    $script:firmas = $null
    Comp '9d. la lista se queda en su tope' ((Firmas).Count -le $FirmasMax) ([string](Firmas).Count + ' de ' + [string]$FirmasMax)
    Comp '9e. y la que se usa sobrevive al recorte' ((DeQuien 'lee la pantalla') -eq 'mira pantalla') 'se quitan las que menos se usan'
    # y los candidatos de un destino no crecen sin fin
    Reset
    for ($i = 0; $i -lt ($FirmasCandidatosMax + 5); $i++) {
        $null = Add-CandidatoFirma ('mira la pantalla numero ' + $i + ' ahora') 'lee la pantalla'
    }
    Comp '9f. los candidatos de un destino tienen tope' (@((Get-FirmasDisco).candidatos['lee la pantalla']).Count -le $FirmasCandidatosMax) ([string]@((Get-FirmasDisco).candidatos['lee la pantalla']).Count)

    Write-Host ''
    Write-Host '-- 10. EL CABLEADO --'
    $sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"
    Comp '10a. se prueban ANTES de la nube' ($sinCom -match '(?s)if \(\$FirmasOn -and -not \$script:enFirma\).{0,3000}if \(\$TraducirOn\) \{ Submit-Command \$text ''traducir'' \}') ''
    Comp '10b. y DESPUES del filtro de ruido' ($sinCom -match '(?s)RUIDO descartado.{0,9000}if \(\$FirmasOn -and -not \$script:enFirma\)') 'lo mismo que las recetas, y por lo mismo'
    Comp '10c. las primeras veces pregunta, con el contador de las recetas' ($sinCom -match '\[int\]\$firEnc\.confirmadas -lt \$RecetasConfirmar') ''
    Comp '10d. y si la capa local quiere confirmar, se le deja' ($sinCom -match '\$rF -and \$script:pendiente') ''
    Comp '10e. la bandera corta el bucle en las dos salidas' (@([regex]::Matches($sinCom, '\$script:enFirma = \$true')).Count -eq 2) ([string]@([regex]::Matches($sinCom, '\$script:enFirma = \$true')).Count + ' sitios')
    Comp '10f. y se apaga siempre, en un finally' (@([regex]::Matches($sinCom, 'finally \{[^}]*\$script:enFirma = \$false')).Count -eq 2) ''
    Comp '10g. el caso se apunta cuando la nube acierta' ($sinCom -match '\[void\]\(Add-CandidatoFirma \$original \$propuesta\)') ''
    Comp '10h. y eso va ANTES del filtro que tira las frases largas' ($sinCom -match '(?s)Add-CandidatoFirma \$original \$propuesta.{0,800}no aprendo ''\$original''') 'son justo esas las que traen las palabras buenas'
    Comp '10i. la firma no se ejecuta con confirmado puesto de fabrica' ($sinCom -match '-not \$script:confirmado -and \[int\]\$firEnc\.confirmadas') 'un si hablado tiene que valer'
    Write-Host ''
    Write-Host '-- 11. Y SE PUEDE MEDIR (un ajuste que no se cuenta no ha pasado) --'
    Comp '11a. firma es un destino propio del registro de uso' ($sinCom -match "\`$DestinosUso = @\('local', 'aprendida', 'firma'") 'si fuera local no se sabria nunca si sirve'
    Comp '11b. y la que acierta lo apunta' ($sinCom -match "\`$script:intentoActual\.llego = 'firma'") ''
    Comp '11c. cuenta como acierto, no como fallo' ($sinCom -match "\`$UsoBien   = @\('local', 'aprendida', 'firma'") ''
    Comp '11d. y sale en la leyenda del markdown' ($txt -match 'las palabras que eran la orden, aprendidas de dos formas') ''
} finally {
    Remove-Item -LiteralPath $MemoriaDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'las firmas aprenden las palabras que eran la orden, con dos palabras minimo' -ForegroundColor Green
exit 0
