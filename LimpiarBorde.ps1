<#
    LimpiarBorde.ps1 - Conversor de video por lotes (modelo preparar/procesar).
    Version 4.0 - Migracion a PowerShell 5.1 del antiguo LimpiarBorde.cmd, modular en lib\.

    FLUJO:
      - Si hay algun archivo sin .job (y sin convertir) -> FASE PREPARAR: pregunta
        la configuracion de cada archivo y escribe Proceso\<nombre>.job.json.
      - Despues, en la misma ventana -> FASE WORKER: codifica los preparados sin
        preguntar, reclamando cada archivo con un lock atomico (mkdir).
      - Se pueden abrir varias ventanas: cuando todos tienen .job, cada una entra
        directa como worker y se reparten los archivos por el lock.

    Regla del prefijo _: si el nombre empieza por '_', se fuerza la deteccion de bordes.
#>

[CmdletBinding()]
param()

$CvVersion = '4.0'

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
foreach ($m in 'Common','MediaInfo','Profile','Video','Audio','Subtitle','Multiplex') {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

$ctx = New-CvContext -Root $Root

# Colores, fuente, tamano y titulo de la ventana (config.json).
Set-CvAppearance -Context $ctx -Title ("ConversorVideoCMD {0}" -f $CvVersion)

# Separador de secciones (ancho del cuadro de los menus).
$sepLine = ('=' * 64)

# ---- Comprobacion de herramientas ----
# Si faltan herramientas, ofrecer descargarlas. $didInstall marca si se instalo algo.
$didInstall = $false

# ffmpeg (siempre necesario).
$ffMissing = @('FFmpeg','FFprobe','FFplay' | Where-Object { -not (Test-Path $ctx.$_) })
if ($ffMissing.Count -gt 0) {
    Write-CvLog 'GLOBAL' ("[FFMPEG] - No se encontro ffmpeg/ffprobe/ffplay en {0}" -f (Split-Path $ctx.FFmpeg))
    $ffVer = Select-CvToolVersion -Context $ctx -Name 'ffmpeg'
    if (-not [string]::IsNullOrWhiteSpace($ffVer)) {
        if (Install-CvTool -Context $ctx -Name 'ffmpeg' -Version $ffVer) { $didInstall = $true }
    } else {
        Write-CvLog 'GLOBAL' '[FFMPEG] - Descarga cancelada.'
    }
}

# aacgain (solo si el metodo de volumen es 'aacgain').
if ("$($ctx.VolumeMethod)".ToLower() -eq 'aacgain' -and -not (Test-Path $ctx.AacGain)) {
    Write-CvLog 'GLOBAL' ("[AACGAIN] - No se encontro aacgain.exe en {0}" -f (Split-Path $ctx.AacGain))
    $agVer = Select-CvToolVersion -Context $ctx -Name 'aacgain'
    if (-not [string]::IsNullOrWhiteSpace($agVer)) {
        if (Install-CvTool -Context $ctx -Name 'aacgain' -Version $agVer) { $didInstall = $true }
    } else {
        Write-CvLog 'GLOBAL' '[AACGAIN] - Descarga cancelada.'
    }
}

$missing = Test-CvTools -Context $ctx
if ($missing.Count -gt 0) {
    # Si algo falta (o una descarga fallo) se deja el error en pantalla, no se limpia.
    Write-Host 'ERROR: faltan herramientas en tools\:' -ForegroundColor Red
    $missing | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor Red }
    exit 1
}

# Si se instalo algo y todo fue bien, limpiar la pantalla para dejarla despejada.
if ($didInstall) { Clear-Host }

# Versiones realmente instaladas (leidas de las propias apps).
$ffInstalled = Get-CvToolInstalledVersion -Context $ctx -Name 'ffmpeg'
if ($ffInstalled) { Write-CvLog 'GLOBAL' ("[FFMPEG] - Version instalada: {0}" -f $ffInstalled) }
$agInstalled = Get-CvToolInstalledVersion -Context $ctx -Name 'aacgain'
if ($agInstalled) { Write-CvLog 'GLOBAL' ("[AACGAIN] - Version instalada: {0}" -f $agInstalled) }

function Get-SourceFiles {
    param($Context)
    $files = @()
    foreach ($ext in $Context.Extensions) {
        $files += @(Get-ChildItem -LiteralPath $Context.Original -Filter $ext -File -ErrorAction SilentlyContinue)
    }
    return ($files | Sort-Object Name)
}

# ============================================================
#  CLASIFICAR: hay algun archivo POR PREPARAR?
# ============================================================
$files = Get-SourceFiles -Context $ctx
if ($files.Count -eq 0) {
    Write-CvLog 'GLOBAL' ("[FIN] - No hay archivos en {0}" -f $ctx.Original)
    exit 0
}

# Bloquear el boton X de la ventana para no cerrarla por error a mitad de proceso.
# El trap garantiza reactivarlo si algo falla; tambien se reactiva al terminar bien.
if ($ctx.LockClose) { Set-CvCloseButton -Enabled $false }
trap { if ($ctx.LockClose) { try { Set-CvCloseButton -Enabled $true } catch {} } ; break }

$needPrepare = $false
foreach ($f in $files) {
    $name = $f.BaseName
    if ((Test-Path -LiteralPath (Get-OutputPath $ctx $name))) { continue }   # ya convertido
    if (-not (Test-CvJob -Context $ctx -Name $name)) { $needPrepare = $true; break }
}

# ============================================================
#  FASE PREPARAR
# ============================================================
if ($needPrepare) {
    $cfgProfile = Select-Profile
    if ($null -eq $cfgProfile) {
        Write-CvLog 'GLOBAL' 'ERROR: no se ha seleccionado perfil.'
        if ($ctx.LockClose) { Set-CvCloseButton -Enabled $true }
        exit 1
    }
    Write-ProfileInfo -Profile $cfgProfile

    Write-CvLog 'GLOBAL' '[PREPARAR] - Generando configuracion de los archivos...'
    foreach ($f in $files) {
        $name = $f.BaseName
        if (Test-Path -LiteralPath (Get-OutputPath $ctx $name)) { continue }
        if (Test-CvJob -Context $ctx -Name $name)    { continue }

        Write-Host ''
        Write-Host ''
        Write-Host $sepLine
        Write-CvLog 'PREPARAR' ("ARCHIVO: {0}" -f $name)
        Write-Host $sepLine

        $info = Get-MediaInfo -Context $ctx -File $f.FullName
        if ($null -eq $info) { Write-CvLog 'PREPARAR' '[SKIP] - No se pudo leer el archivo (ffprobe)'; continue }

        Write-CvLog 'PREPARAR' ("[INFO] - Tamano: {0}  Duracion: {1}" -f (Get-VideoSize (Get-VideoStream $info)), (Get-DurationText $info))

        $forceBorder = $name.StartsWith('_')

        Write-Host ''
        $vAsk = Invoke-VideoAsk -Context $ctx -Profile $cfgProfile -Info $info -ForceBorder $forceBorder

        Write-Host ''
        $aAsk = Invoke-AudioAsk -Context $ctx -Profile $cfgProfile -Info $info

        Write-Host ''
        $subSel = Select-Subtitles -Context $ctx -Info $info

        # Congelar el perfil + las respuestas en el job (autosuficiente para el worker).
        $job = [ordered]@{
            file      = $f.FullName
            profile   = $cfgProfile
            video     = @{ skip = $vAsk.Skip; crop = $vAsk.Crop; resize = $vAsk.Resize; anim = $vAsk.Anim }
            audio     = @{ skip = $aAsk.Skip; index = $aAsk.Index; is51 = $aAsk.Is51; sync = $aAsk.Sync }
            subtitles = @($subSel)
        }
        Write-CvJob -Context $ctx -Name $name -Job $job
        Write-Host ''
        Write-CvLog 'PREPARAR' ("[OK] - Job creado: {0}.job.json" -f $name)
    }
    Write-CvLog 'GLOBAL' '[PREPARAR] - Configuracion completada.'
}

# ============================================================
#  FASE WORKER
# ============================================================
Write-Host ''
Write-CvLog 'GLOBAL' '[WORKER] - Buscando archivos preparados para codificar...'

$didAny = $true
while ($didAny) {
    $didAny = $false
    foreach ($f in (Get-SourceFiles -Context $ctx)) {
        $name = $f.BaseName
        $out  = Get-OutputPath $ctx $name
        if (Test-Path -LiteralPath $out) { continue }                       # ya hecho
        if (-not (Test-CvJob -Context $ctx -Name $name)) { continue }  # sin preparar

        # Reclamo atomico
        if (-not (Enter-Lock -Context $ctx -Name $name)) { continue }  # lo tiene otro worker
        $didAny = $true
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            Write-Host ''
            Write-Host ''
            Write-Host $sepLine
            Write-CvLog 'WORKER' ("CODIFICANDO: {0}" -f $name)
            Write-Host $sepLine

            $job  = Read-CvJob -Context $ctx -Name $name
            $prof = $job.profile
            $info = Get-MediaInfo -Context $ctx -File $f.FullName
            if ($null -eq $info) { Write-CvLog 'WORKER' '[ERR] - No se pudo leer el archivo'; continue }

            # ---------- AUDIO ----------
            Write-Host ''
            if ($job.audio.skip) { Write-CvLog 'AUDIO' '[SKIP] - se omite (copy/omitido)' }
            else {
                [void](Invoke-AudioRun -Context $ctx -Profile $prof -File $f.FullName -Sync ([double]$job.audio.sync) -Index ([int]$job.audio.index))
            }

            # ---------- VIDEO ----------
            Write-Host ''
            if ($job.video.skip) { Write-CvLog 'VIDEO' '[SKIP] - se omite (copy)' }
            else {
                [void](Invoke-VideoRun -Context $ctx -Profile $prof -File $f.FullName -Crop $job.video.crop -Resize $job.video.resize -Anim ([bool]$job.video.anim))
            }

            # ---------- MULTIPLEX ----------
            Write-Host ''
            $ok = Invoke-Multiplex -Context $ctx -File $f.FullName -Info $info -VideoSkipped ([bool]$job.video.skip) -AudioSkipped ([bool]$job.audio.skip) -Subtitles $job.subtitles

            if ($ok) {
                # limpieza de temporales (activable/desactivable con el marcador 'keep_temp')
                if ($ctx.CleanTemps) {
                    Remove-CvTemps -Context $ctx -Name $name
                } else {
                    Write-CvLog 'WORKER' '[TEMP] - Se conservan los temporales (existe marcador keep_temp)'
                }
                Remove-CvJob -Context $ctx -Name $name
                $sw.Stop()
                Write-Host ''
                Write-CvLog 'WORKER' ("[OK] - Finalizado: {0}" -f $name)
                Write-ConversionSummary -Context $ctx -File $f.FullName -Info $info -Output $out -Elapsed $sw.Elapsed
            } else {
                Write-Host ''
                Write-CvLog 'WORKER' ("[ERR] - No se genero la salida, se reintentara: {0}" -f $name)
            }
        }
        finally {
            Exit-Lock -Context $ctx -Name $name
        }
    }
}

Write-Host ''
Write-CvLog 'GLOBAL' '[END] - No quedan archivos libres por procesar'

# Reactivar el boton X al terminar.
if ($ctx.LockClose) { Set-CvCloseButton -Enabled $true }
