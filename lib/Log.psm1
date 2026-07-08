<#
    Log.psm1 - Registro: log de consola (Write-CvLog) y transcript de la ejecucion a logs\.
    Sin dependencias de otros modulos.
#>

function Write-CvLog {
    <#
        Log de consola. Resalta con fondo de color las lineas de error/aviso:
        [ERR] -> fondo rojo; [AVISO]/[WARN]/[NO SOPORTADO] -> fondo amarillo.
    #>
    param([string]$Tag = 'GLOBAL', [string]$Message = '')
    $prefix = "[{0}] " -f $Tag
    if ($Message -match '\[ERR\]') {
        Write-Host $prefix -NoNewline
        Write-Host $Message -ForegroundColor White -BackgroundColor Red
    }
    elseif ($Message -match '\[(AVISO|WARN|NO SOPORTADO)\]') {
        Write-Host $prefix -NoNewline
        Write-Host $Message -ForegroundColor Black -BackgroundColor Yellow
    }
    else {
        Write-Host ($prefix + $Message)
    }
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
