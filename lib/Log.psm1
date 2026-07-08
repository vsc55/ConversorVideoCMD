<#
    Log.psm1 - Registro: log de consola (Write-CvLog) y transcript de la ejecucion a logs\.
    Sin dependencias de otros modulos.
#>

# Estilo de las marcas/avisos: $true => ASCII puro ([OK]/[ERROR], corchetes []); $false =>
# simbolos y badge de medio bloque. Lo fija el arranque desde config (behavior.asciiMarks) via
# Set-CvMarkStyle, util en consolas/fuentes que no tengan los glifos (se verian como cuadros).
$script:CvAsciiMarks = $false
function Set-CvMarkStyle { param([bool]$Ascii) $script:CvAsciiMarks = [bool]$Ascii }

function Get-CvMark {
    <#
        Marca de estado (check/cruz). Con behavior.asciiMarks -> texto ASCII ([OK]/[ERROR]); si no,
        simbolos U+2713/U+2717 (ConvertFromUtf32 para no depender de la codificacion del fichero).
    #>
    param([bool]$Ok)
    if ($script:CvAsciiMarks) { if ($Ok) { return '[OK]' } else { return '[ERROR]' } }
    if ($Ok) { return [char]::ConvertFromUtf32(0x2713) }   # check monocromo
    else     { return [char]::ConvertFromUtf32(0x2717) }   # cruz monocroma
}

function Write-CvLog {
    <#
        Log de consola. Las lineas de error/aviso se resaltan con fondo de color y se envuelven
        en "[ ... ]" con los CORCHETES en color normal: asi la ultima celda de la linea NO lleva
        fondo, evitando el bug de la consola de Windows de que el fondo se "estira" hasta el borde
        al redimensionar la ventana. El texto interior va resaltado ([ERR] -> rojo; [AVISO]/[WARN]/
        [NO SOPORTADO] -> amarillo). Ademas se quita la redundancia del [TAG] y de los corchetes
        del token: "[AUDIO] [AVISO] - x" se muestra como "[ AVISO - x ]".
    #>
    param([string]$Tag = 'GLOBAL', [string]$Message = '', [int]$Indent = 0)
    $pad = ' ' * $Indent
    if ($Message -match '\[(ERR|AVISO|WARN|NO SOPORTADO)\]') {
        # Quitar los corchetes de TODOS los tokens iniciales, no solo del primero: "[AVISO] - x"
        # -> "AVISO - x", y tambien "[FFMPEG] - [ERR] - x" -> "FFMPEG - ERR - x" (el nivel puede
        # no ser el primer token). El padding del bloque lo aportan los espacios de abajo.
        $inner = $Message.Trim()
        $mTok = [regex]::Match($inner, '^(?:\[[^\]]+\]\s*-\s*)+')
        if ($mTok.Success) { $inner = ($mTok.Value -replace '[\[\]]', '') + $inner.Substring($mTok.Value.Length) }
        # Badge con extremos de MEDIO BLOQUE (▐ ... ▌) coloreados como el fondo: el bloque se ve
        # como una etiqueta solida con los bordes a media celda. El ultimo caracter (▌) se pinta
        # con FONDO por defecto, asi la ultima celda de la linea no lleva fondo y no se reproduce
        # el bug de Windows de que el fondo se "estira" al redimensionar la ventana.
        $dbg = $Host.UI.RawUI.BackgroundColor
        $dfg = $Host.UI.RawUI.ForegroundColor
        if ($Message -match '\[ERR\]') { $bg = 'Red'; $fg = 'White' } else { $bg = 'Yellow'; $fg = 'Black' }
        if ($script:CvAsciiMarks) {
            # ASCII: corchetes [ ] en color normal, interior con fondo (ultimo caracter ']' sin fondo).
            Write-Host ($pad + '[') -NoNewline -ForegroundColor $dfg -BackgroundColor $dbg
            Write-Host (' ' + $inner + ' ') -NoNewline -ForegroundColor $fg -BackgroundColor $bg
            Write-Host ']' -ForegroundColor $dfg -BackgroundColor $dbg
        } else {
            # Badge con caps de medio bloque (▐ ▌) coloreados como el fondo.
            $lb = [char]0x2590; $rb = [char]0x258C
            Write-Host ($pad + $lb) -NoNewline -ForegroundColor $bg -BackgroundColor $dbg
            Write-Host (' ' + $inner + ' ') -NoNewline -ForegroundColor $fg -BackgroundColor $bg
            Write-Host $rb -ForegroundColor $bg -BackgroundColor $dbg
        }
    }
    else {
        Write-Host (('{0}[{1}] ' -f $pad, $Tag) + $Message)
    }
}

function Start-CvStep {
    <#
        Inicia una linea de "paso" del worker. En uso normal imprime " - <msg>" SIN salto
        (se cierra con Stop-CvStep, que anade OK/ERROR en la misma linea). En modo debug
        imprime el log detallado normal ("[TAG] <msg>") para no romper el volcado de comandos.
    #>
    param($Context, [string]$Tag, [string]$Message)
    if ($Context.Debug) { Write-CvLog $Tag $Message }
    else { Write-Host (" - {0}" -f $Message) -NoNewline }
}

function Stop-CvStep {
    <# Cierra el paso iniciado con Start-CvStep. Normal: " [extra] OK|ERROR" en la misma linea.
       Debug: escribe OkMsg (si OK) o FailMsg (si falla) como log normal. #>
    param($Context, [string]$Tag, [bool]$Ok = $true, [string]$Extra = '', [string]$OkMsg = '', [string]$FailMsg = '')
    if ($Context.Debug) {
        if ($Ok) { if (-not [string]::IsNullOrEmpty($OkMsg)) { Write-CvLog $Tag $OkMsg } }
        else     { if (-not [string]::IsNullOrEmpty($FailMsg)) { Write-CvLog $Tag $FailMsg } }
    } else {
        if ($Extra) { Write-Host (" {0}" -f $Extra) -NoNewline }
        if ($Ok) { Write-Host (' {0}' -f (Get-CvMark $true)) -ForegroundColor Green } else { Write-Host (' {0}' -f (Get-CvMark $false)) -ForegroundColor Red }
    }
}

function Write-CvInfoStep {
    <# Linea de paso informativa (sin OK/ERROR). Normal: " - <msg>". Debug: "[TAG] <msg>". #>
    param($Context, [string]$Tag, [string]$Message)
    if ($Context.Debug) { Write-CvLog $Tag $Message }
    else { Write-Host (" - {0}" -f $Message) }
}

function Start-CvLog {
    <#
        Inicia el transcript de la ejecucion en logs\<Prefix>_<fecha>_<PID>.log si el
        contexto tiene Log activo. Devuelve la ruta del log (o '' si no se inicia).
        Cada ventana/worker genera su propio fichero (el PID lo hace unico).
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Prefix)
    if (-not $Context.Log) { return '' }
    $path = Join-Path $Context.Logs ("{0}_{1}_{2}.log" -f $Prefix, (Get-Date -Format 'yyyyMMdd_HHmmss'), $PID)
    try { Start-Transcript -LiteralPath $path -Append -ErrorAction Stop | Out-Null; return $path }
    catch { return '' }
}

function Stop-CvLog {
    <# Detiene el transcript si hay uno activo (seguro de llamar aunque no haya). #>
    try { Stop-Transcript | Out-Null } catch {}
}

function Get-CvLogFiles {
    <#
        Ficheros de log (*.log) de la carpeta logs\, excluyendo opcionalmente ExceptPath
        (por ejemplo el log de la sesion actual, que esta en uso).
    #>
    param([Parameter(Mandatory)]$Context, [string]$ExceptPath = '')
    $dir = $Context.Logs
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    @(Get-ChildItem -LiteralPath $dir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne "$ExceptPath" })
}

function Remove-CvLogFiles {
    <# Borra los ficheros de log indicados. Devuelve cuantos habia. #>
    param([Parameter(Mandatory)][AllowEmptyCollection()]$Files)
    $Files | Remove-Item -Force -ErrorAction SilentlyContinue
    return @($Files).Count
}

Export-ModuleMember -Function *
