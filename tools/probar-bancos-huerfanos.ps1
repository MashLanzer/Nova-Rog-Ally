# UN BANCO QUE NADIE CORRE ES COMO NO TENERLO (25/09)
#
# LO MEDIDO: hay 198 bancos en la carpeta tools y la bateria tiene 199 secciones, asi que
# parecia que estaban todos. No lo estaban: barriendo la carpeta y buscando cada nombre dentro
# de probar-todo.ps1 aparecio **probar-microfono.py**, escrito el 22/09 -cuando braya enchufo
# un micro USB y dijo "Nova tiene que saber detectar cuando esta y no esta ese micro"- y que
# desde entonces no habia corrido NUNCA. Su propia cabecera explica que la parte que prueba se
# puede probar sin hardware; simplemente nadie lo llamaba.
#
# Y NO SE NOTA POR NINGUN LADO: un banco huerfano no sale rojo, no sale verde, no sale. El
# recuento de secciones tampoco lo delata, porque algunas secciones corren dos bancos.
#
# EL AGUJERO QUE TUVO ESTE BANCO EL PRIMER DIA, y que es la razon de la mitad del codigo de
# abajo: la primera version buscaba el nombre en el TEXTO ENTERO de la bateria, comentarios
# incluidos. Nombrar un banco en un comentario lo daba por corrido. Y no es hipotetico: hoy
# mismo hay TRES asi, los tres que la bateria deja fuera a proposito y explica en un comentario
# -probar-vivo.ps1, probar-precarga.py y probar-voz-windows.py-. Los tres pasaban en verde por
# la razon equivocada, y el cuarto que apareciera habria pasado igual sin que nadie lo supiera.
# Ahora se busca solo en el CODIGO, y esos tres son una excepcion declarada aqui abajo.
#
# LO QUE **NO** ES UN HUERFANO, ademas de esos tres: los que llama OTRO banco
# (probar-adelanto-funciones.py y probar-huerfanos-funciones.py los lanzan
# probar-adelanto-oido.ps1 y probar-huerfanos.ps1). Esos SI se corren. Y este mismo, que habla
# de los demas.
$ErrorActionPreference = 'Stop'
trap { Write-Host ("  MAL  el banco se rompio: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
$mal = 0
function Comp([string]$que, [bool]$ok, [string]$detalle) {
    if ($ok) { Write-Host ("  ok   " + $que + $(if ($detalle) { "  (" + $detalle + ")" })) }
    else { Write-Host ("  MAL  " + $que + $(if ($detalle) { "  (" + $detalle + ")" })); $script:mal++ }
}

# SOLO EL CODIGO. Corta cada linea en el primer '#' que no este dentro de comillas. No hay
# comentarios de bloque <# #> en ningun banco de tools (se comprobo: cero), y no hay ninguna
# linea que llame a un banco y lleve una almohadilla delante, asi que esto basta y no se lleva
# por delante ninguna llamada de verdad. Si algun dia se la llevara, el banco saldria ROJO
# -diria que sobran huerfanos-, que es el fallo bueno: se ve.
function Solo-Codigo([string]$texto) {
    $salida = New-Object System.Text.StringBuilder
    foreach ($linea in ($texto -split "`n")) {
        $simple = $false; $doble = $false; $corte = -1
        for ($i = 0; $i -lt $linea.Length; $i++) {
            $c = $linea[$i]
            if ($c -eq "'" -and -not $doble) { $simple = -not $simple }
            elseif ($c -eq '"' -and -not $simple) { $doble = -not $doble }
            elseif ($c -eq '#' -and -not $simple -and -not $doble) { $corte = $i; break }
        }
        if ($corte -ge 0) { $linea = $linea.Substring(0, $corte) }
        [void]$salida.AppendLine($linea)
    }
    return $salida.ToString()
}

# LOS TRES QUE SE QUEDAN FUERA A PROPOSITO. El motivo entero esta en probar-todo.ps1, al final:
# uno arranca Nova de verdad, otro carga el modelo local dos veces, y el tercero te pide hablar
# por el microfono. Aqui solo hace falta saber que su ausencia es una decision, no un olvido.
$excepciones = @('probar-vivo.ps1', 'probar-precarga.py', 'probar-voz-windows.py')

$todos = @(Get-ChildItem -LiteralPath $PSScriptRoot -File |
           Where-Object { ($_.Name -like 'probar-*.ps1' -or $_.Name -like 'probar-*.py') -and
                          $_.Name -ne 'probar-todo.ps1' -and $_.Name -ne 'probar-bancos-huerfanos.ps1' })
$bateriaTexto = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'probar-todo.ps1'))
$bateria = Solo-Codigo $bateriaTexto

# QUIEN LLAMA A QUIEN: el codigo de TODOS los bancos junto, para ver si uno lanza a otro. Sin
# comentarios tambien, por lo mismo: un banco nombrado en la cabecera de otro no es un banco
# corrido.
$deOtros = ''
foreach ($f in $todos) { $deOtros += (Solo-Codigo ([IO.File]::ReadAllText($f.FullName))) + "`n" }

$huerfanos = @()
foreach ($f in $todos) {
    if ($bateria.Contains($f.Name)) { continue }          # la bateria lo corre
    if ($excepciones -contains $f.Name) { continue }      # fuera a proposito, y dicho arriba
    # lo lanza otro banco? Se busca su nombre en el resto, sin contarse a si mismo
    $sinEl = $deOtros.Replace((Solo-Codigo ([IO.File]::ReadAllText($f.FullName))), '')
    if ($sinEl.Contains($f.Name)) { continue }
    $huerfanos += $f.Name
}

Write-Host "-- $($todos.Count) bancos en la carpeta tools --"
Comp 'ninguno se ha quedado sin correr' ($huerfanos.Count -eq 0) $(if ($huerfanos.Count) { "huerfanos: " + ($huerfanos -join ', ') } else { '' })

# UNA EXCEPCION QUE YA NO HACE FALTA ES UNA MENTIRA IGUAL. Si alguno de los tres acaba
# enganchado a la bateria, esta lista dejaria de decir la verdad y taparia al siguiente que se
# llamara igual. Sale MAL y dice exactamente que hacer, porque el arreglo es borrar una linea.
$sobran = @($excepciones | Where-Object { $bateria.Contains($_) })
Comp 'las tres excepciones siguen siendo excepciones' ($sobran.Count -eq 0) $(if ($sobran.Count) { "ya los corre la bateria, quita de la lista: " + ($sobran -join ', ') } else { '' })
# LOS NOMBRES QUE EXISTEN. Van los 198 mas los DOS que $todos se quita de en medio -la propia
# bateria y este banco-, porque para "llamas a uno que ya no esta" lo unico que importa es si
# el fichero esta ahi. Sin ellos este mismo banco se denunciaba a si mismo como fantasma en
# cuanto la bateria empezo a llamarlo.
$nombresTodos = @{}
foreach ($f in $todos) { $nombresTodos[$f.Name] = $true }
$nombresTodos['probar-todo.ps1'] = $true
$nombresTodos['probar-bancos-huerfanos.ps1'] = $true
$exFantasma = @($excepciones | Where-Object { -not $nombresTodos.ContainsKey($_) })
Comp 'y ninguna nombra un banco que ya no existe' ($exFantasma.Count -eq 0) $(if ($exFantasma.Count) { ($exFantasma -join ', ') } else { '' })

# Y AL REVES: que la bateria no llame a un banco que ya no existe. Ese fallo SI se nota -sale
# rojo- pero con un mensaje que no dice lo que pasa, asi que mejor decirlo aqui.
$fantasmas = @()
foreach ($m in [regex]::Matches($bateria, "'(probar-[A-Za-z0-9-]+\.(?:ps1|py))'")) {
    $n = $m.Groups[1].Value
    if (-not $nombresTodos.ContainsKey($n)) { $fantasmas += $n }
}
Comp 'ni la bateria llama a ninguno que ya no esta' ((@($fantasmas | Select-Object -Unique)).Count -eq 0) $(if ($fantasmas.Count) { ($fantasmas | Select-Object -Unique) -join ', ' } else { '' })

# EL DETECTOR, PROBADO CON TRES CASOS FALSOS. Sin esto lo de arriba es decoracion: un detector
# que no detecta sale verde exactamente igual que uno que si.
$falso = 'probar-esto-no-existe-de-verdad.ps1'
Comp 'el detector sabe detectar' (-not $bateria.Contains($falso)) 'con un nombre inventado, que no puede estar'
# El caso que se le escapaba: nombrado en un comentario, y nada mas.
$soloComentario = Solo-Codigo "# esto habla de probar-vivo.ps1 y no lo corre`nWrite-Host 'hola'`n"
Comp 'y que un comentario no cuenta como correrlo' (-not $soloComentario.Contains('probar-vivo.ps1')) 'nombrado en un comentario, sin llamarlo'
# Y el contrario, que importa lo mismo: si se comiera las llamadas de verdad, todo seria
# huerfano y este banco se pasaria el dia mintiendo al reves.
$conLlamada = Solo-Codigo "powershell -File (Join-Path `$PSScriptRoot 'probar-vivo.ps1') # y un comentario detras`n"
Comp 'y una llamada de verdad si cuenta' ($conLlamada.Contains('probar-vivo.ps1')) 'aunque lleve un comentario en la misma linea'

Write-Host ''
if ($mal -gt 0) { Write-Host "  $mal MAL"; exit 1 }
Write-Host '  todos los bancos se corren'
exit 0
