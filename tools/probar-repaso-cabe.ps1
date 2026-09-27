$ErrorActionPreference = 'Stop'
# EL OIDO SABE CUANTO VA A TARDAR CADA MOTOR (27/09, idea 71 de las 121)
#
# Banco en PowerShell porque lo que hay que vigilar son DOS lados: la decision vive en
# wake_vosk.py (se prueba con probar-repaso-cabe.py, que ejecuta las funciones de verdad) y el
# plazo lo tiene que MANDAR el asistente en el fichero de la marca. Aqui se comprueba el cableado
# del lado de PowerShell, que es el que se olvida al mover codigo.
$Raiz = Split-Path -Parent $PSScriptRoot
$PS1 = Join-Path $Raiz 'assistant.ps1'
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ('  ok   ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })) }
    else { Write-Host ('  MAL  ' + $que + $(if ($detalle) { '  (' + $detalle + ')' })); $script:mal++ }
}
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($PS1, [ref]$null, [ref]$err)
Comp 'assistant.ps1 se parsea entero' ($err.Count -eq 0) ([string]$err.Count + ' error(es)')
$txt = [IO.File]::ReadAllText($PS1)
# los comentarios fuera: una marca escrita en un comentario no manda ningun plazo (manera 17)
$sinCom = (($txt -split "`n") | Where-Object { $_.TrimStart() -notmatch '^#' }) -join "`n"

Write-Host ''
Write-Host '-- el plazo viaja con el pedido, en las CINCO marcas --'
$marcas = @([regex]::Matches($sinCom, 'WriteAllText\(\$MarcaReintento, ([^\r\n]+)\)'))
Comp 'hay cinco sitios que piden repaso' ($marcas.Count -eq 5) ([string]$marcas.Count)
$sinPlazo = @($marcas | Where-Object { $_.Groups[1].Value -notmatch "\|" })
Comp 'y los cinco mandan el plazo detras del motor' ($sinPlazo.Count -eq 0) ([string]$sinPlazo.Count + ' sin plazo')
Comp 'el del motor que toca usa el plazo ya calculado' ($sinCom -match "\(\`$quien \+ '\|' \+ \`$script:reintentoPlazo\)") 'el mismo numero que espera el asistente'
Comp 'y se calcula ANTES de escribir la marca' ($sinCom -match "(?s)\`$script:reintentoPlazo = \[int\]\(Get-PlazoOido \`$quien \`$ReintentoMaxMs\)\s*\r?\n\s*\[System\.IO\.File\]::WriteAllText") 'si no, viajaria el plazo de la vez anterior'
Comp 'el ultimo recurso manda el plazo de turbo' ($sinCom -match "'ultimo\|' \+ \[int\]\(Get-PlazoOido 'turbo'") ''
$xs = @([regex]::Matches($sinCom, "'x\|' \+ \[int\]\(Get-PlazoOido 'small'"))
Comp 'y las tres de small, el de small' ($xs.Count -eq 3) ([string]$xs.Count)

Write-Host ''
Write-Host '-- y el oido lo usa (sobre wake_vosk.py) --'
$py = [IO.File]::ReadAllText((Join-Path $Raiz 'wake_vosk.py'))
Comp 'el oido parte el pedido por la barra' ($py -match 'pedido, _, resto = pedido\.partition\("\|"\)') ''
Comp 'canary y omni ya pasan por la comprobacion' ($py -match '(?s)if pedido in \("canary", "omni"\):.{0,400}cabe_el_repaso\(pedido, duracion, plazo_s\)') 'hasta hoy no tenian NINGUN tope'
Comp 'los de whisper tambien' ($py -match 'cabe, por_que = cabe_el_repaso\(motor_nombre, duracion, plazo_s, ultimo\)') ''
Comp 'el ultimo escalon no se salta nunca' ($py -match '(?s)def cabe_el_repaso.{0,600}if ultimo:\s*\r?\n\s*return True') 'detras de turbo no hay nada'
Comp 'se apunta lo que costo cada repaso' (@([regex]::Matches($py, 'apuntar_ritmo\(')).Count -ge 3) 'canary/omni, whisper y la definicion'
Comp 'con la MEDIANA, no con la peor' ($py -match '(?s)def ritmo_motor.{0,500}return mediana\(vals\)') 'un arranque en frio no puede dejar fuera a un motor'
Comp 'y sin plazo o sin ritmo, el tope de siempre' ($py -match 'tope = REPASO_MAX_BASE if motor == "base" else REPASO_MAX') 'un asistente viejo sigue funcionando igual'

Write-Host ''
if ($mal -gt 0) { Write-Host ([string]$mal + ' MAL') -ForegroundColor Red; exit 1 }
Write-Host 'el plazo viaja con el pedido y el oido decide antes de cargar' -ForegroundColor Green
exit 0
