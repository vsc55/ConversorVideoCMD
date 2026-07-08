<#
    Convert.ps1 - Conversor de video por lotes (modelo preparar/procesar).
    PowerShell 5.1, modular en lib\ (migracion del antiguo LimpiarBorde.cmd).

    FLUJO:
      - Si hay algun archivo sin .job (y sin convertir) -> FASE PREPARAR: pregunta
        la configuracion de cada archivo y escribe Proceso\<nombre>.job.json.
      - Despues, en la misma ventana -> FASE WORKER: codifica los preparados sin
        preguntar, reclamando cada archivo con un lock atomico (fichero .lock).
      - Se pueden abrir varias ventanas: cuando todos tienen .job, cada una entra
        directa como worker y se reparten los archivos por el lock.

    Regla del prefijo _: si el nombre empieza por '_', se fuerza la deteccion de bordes.
#>

[CmdletBinding()]
param(
    # Ventana de worker adicional: salta la fase PREPARAR y va directo a codificar (lo lanzan
    # las ventanas extra que se abren al elegir varios workers en paralelo).
    [switch]$WorkerOnly
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
$modules = @('Log','Config','Context','Console','Exec','Job','Tools','MediaInfo','Profile','Video','Audio','Subtitle','Attachment','Multiplex')
foreach ($m in $modules) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

$ctx = New-CvContext -Root $Root

# Log de la ejecucion (transcript) a logs\ (behavior.log / marcador 'no_log').
$cvLog = Start-CvLog -Context $ctx -Prefix 'Convert'

# Colores, fuente, tamano y titulo de la ventana (config.json).
Set-CvAppearance -Context $ctx -Title ("ConversorVideoCMD {0}" -f $ctx.Version)

# Cabecera (app + version).
Show-CvHeader -Context $ctx

# Separador de secciones (ancho del cuadro de los menus).
$sepLine = ('=' * 64)

# ---- Comprobacion de herramientas ----
# Si faltan herramientas, ofrecer descargarlas. $didInstall marca si se instalo algo.
$didInstall = $false

# ffmpeg (siempre necesario): debe existir la version 'selected'.
if (-not (Test-CvToolInstalled -Context $ctx -Name 'ffmpeg' -Version $ctx.FFmpegVersion)) {
    if (-not (Test-CvToolSupported -Context $ctx -Name 'ffmpeg')) {
        Write-Host ("ERROR: ffmpeg no tiene build para la plataforma de este equipo ({0})." -f $ctx.Platform) -ForegroundColor Red
        exit 1
    }
    Write-CvLog 'GLOBAL' ("[FFMPEG] - Falta la version {0}." -f $ctx.FFmpegVersion)
    $ffVer = Select-CvToolVersion -Context $ctx -Name 'ffmpeg'
    if (-not [string]::IsNullOrWhiteSpace($ffVer)) {
        if (Install-CvTool -Context $ctx -Name 'ffmpeg' -Version $ffVer) {
            $didInstall = $true
            $ctx = New-CvToolContext -Context $ctx -FFmpegVersion $ffVer   # usar la version instalada
        }
    } else {
        Write-CvLog 'GLOBAL' '[FFMPEG] - Descarga cancelada.'
    }
}

# aacgain (solo si el metodo de volumen es 'aacgain').
if ("$($ctx.VolumeMethod)".ToLower() -eq 'aacgain' -and -not (Test-CvToolInstalled -Context $ctx -Name 'aacgain' -Version $ctx.AacGainVersion)) {
    if (-not (Test-CvToolSupported -Context $ctx -Name 'aacgain')) {
        Write-Host ("ERROR: aacgain no tiene build para la plataforma de este equipo ({0})." -f $ctx.Platform) -ForegroundColor Red
        exit 1
    }
    Write-CvLog 'GLOBAL' ("[AACGAIN] - Falta la version {0}." -f $ctx.AacGainVersion)
    $agVer = Select-CvToolVersion -Context $ctx -Name 'aacgain'
    if (-not [string]::IsNullOrWhiteSpace($agVer)) {
        if (Install-CvTool -Context $ctx -Name 'aacgain' -Version $agVer) {
            $didInstall = $true
            $ctx = New-CvToolContext -Context $ctx -AacGainVersion $agVer
        }
    } else {
        Write-CvLog 'GLOBAL' '[AACGAIN] - Descarga cancelada.'
    }
}

$missing = Test-CvTools -Context $ctx
if ($missing.Count -gt 0) {
    # Si algo falta (o una descarga fallo) se deja el error en pantalla, no se limpia.
    Write-Host 'ERROR: faltan herramientas:' -ForegroundColor Red
    $missing | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor Red }
    exit 1
}

# Si se instalo algo y todo fue bien, limpiar la pantalla para dejarla despejada.
if ($didInstall) { Clear-Host }

# Version en uso (leida de la propia app de la version seleccionada).
$ffInstalled = Get-CvToolInstalledVersion -Context $ctx -Name 'ffmpeg' -Version $ctx.FFmpegVersion
if ($ffInstalled) { Write-CvLog 'GLOBAL' ("[FFMPEG] - Version en uso: {0}" -f $ffInstalled) }
if ("$($ctx.VolumeMethod)".ToLower() -eq 'aacgain') {
    $agInstalled = Get-CvToolInstalledVersion -Context $ctx -Name 'aacgain' -Version $ctx.AacGainVersion
    if ($agInstalled) { Write-CvLog 'GLOBAL' ("[AACGAIN] - Version en uso: {0}" -f $agInstalled) }
}

function Get-SourceFiles {
    param($Context)
    $files = @()
    foreach ($ext in $Context.Extensions) {
        $files += @(Get-ChildItem -LiteralPath $Context.Original -Filter $ext -File -ErrorAction SilentlyContinue)
    }
    return ($files | Sort-Object Name)
}

function Write-PrepareStatus {
    <#
        Estado de PREPARAR por archivo, como badge de color (mismo estilo que la compatibilidad
        GPU). Se usa ASCII con fondo de color en vez de simbolos unicode (✓/✗) porque la fuente
        de la consola no siempre trae esos glifos y saldria un cuadro.
    #>
    param([string]$Name, [bool]$Ok)
    Write-Host ("[PREPARAR] ARCHIVO: {0}  " -f $Name) -NoNewline
    if ($Ok) { Write-Host ' OK '    -ForegroundColor Black -BackgroundColor Green }
    else     { Write-Host ' ERROR ' -ForegroundColor White -BackgroundColor Red }
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
trap {
    if ($ctx.LockClose) { try { Set-CvCloseButton -Enabled $true } catch {} }
    if ($cvLog) { Stop-CvLog }
    break
}

$needPrepare = $false
if (-not $WorkerOnly) {
    foreach ($f in $files) {
        $name = $f.BaseName
        if ((Test-Path -LiteralPath (Get-OutputPath $ctx $name))) { continue }   # ya convertido
        if (-not (Test-CvJob -Context $ctx -Name $name)) { $needPrepare = $true; break }
    }
}

# ============================================================
#  FASE PREPARAR
# ============================================================
if ($needPrepare) {
    $cfgProfile = Select-Profile
    if ($null -eq $cfgProfile) {
        # El usuario eligio salir (X): cierre limpio.
        Write-CvLog 'GLOBAL' '[SALIR] - Cancelado por el usuario.'
        if ($ctx.LockClose) { Set-CvCloseButton -Enabled $true }
        if ($cvLog) { Stop-CvLog }
        exit 0
    }
    Write-ProfileInfo -Profile $cfgProfile

    Write-CvLog 'GLOBAL' '[PREPARAR] - Generando configuracion de los archivos...'
    foreach ($f in $files) {
        $name = $f.BaseName
        if (Test-Path -LiteralPath (Get-OutputPath $ctx $name)) { continue }
        if (Test-CvJob -Context $ctx -Name $name)    { continue }

        $info = Get-MediaInfo -Context $ctx -File $f.FullName
        if ($null -eq $info) { Write-PrepareStatus -Name $name -Ok $false; continue }

        $forceBorder = $name.StartsWith('_')

        # Modo debug: detalle completo (cabecera + logs de cada modulo). Modo normal: los
        # modulos van en silencio (sus [INFO] solo con debug) y se resume en 1 linea al final.
        if ($ctx.Debug) {
            Write-Host ''
            Write-Host ''
            Write-Host $sepLine
            Write-CvLog 'PREPARAR' ("ARCHIVO: {0}" -f $name)
            Write-Host $sepLine
            Write-CvLog 'PREPARAR' ("[INFO] - Tamano: {0}  Duracion: {1}" -f (Get-VideoSize (Get-VideoStream $info)), (Get-DurationText $info))
            Write-Host ''
        }

        $vAsk   = Invoke-VideoAsk -Context $ctx -Profile $cfgProfile -Info $info -ForceBorder $forceBorder
        $aAsk   = Invoke-AudioAsk -Context $ctx -Profile $cfgProfile -Info $info
        $subSel = Select-Subtitles -Context $ctx -Info $info

        # Congelar el perfil + las respuestas + las versiones de herramientas en el job
        # (autosuficiente: el worker usara estas versiones y las instalara si faltan).
        $job = [ordered]@{
            file           = $f.FullName
            profile        = $cfgProfile
            ffmpegVersion  = $ctx.FFmpegVersion
            aacgainVersion = $ctx.AacGainVersion
            video          = @{ skip = $vAsk.Skip; crop = $vAsk.Crop; resize = $vAsk.Resize; anim = $vAsk.Anim }
            audio          = @{ skip = $aAsk.Skip; index = $aAsk.Index; is51 = $aAsk.Is51; sync = $aAsk.Sync }
            subtitles      = @($subSel)
        }
        Write-CvJob -Context $ctx -Name $name -Job $job

        if ($ctx.Debug) {
            Write-Host ''
            Write-CvLog 'PREPARAR' ("[OK] - Job creado: {0}.job.json" -f $name)
        } else {
            Write-PrepareStatus -Name $name -Ok $true
        }
    }
    Write-CvLog 'GLOBAL' '[PREPARAR] - Configuracion completada.'

    # Preguntar cuantos workers codificaran EN PARALELO (esta ventana + N-1 ventanas nuevas).
    # Las ventanas nuevas se lanzan en modo -WorkerOnly: como ya esta todo preparado, entran
    # directas a codificar sin preguntar y se reparten los archivos por el lock.
    Write-Host ''
    $defW = [int]$ctx.Workers; if ($defW -lt 1) { $defW = 1 }
    $ans = (Read-Host ("[GLOBAL] - Cuantos workers en paralelo, contando esta ventana? (ENTER = {0})" -f $defW)).Trim()
    $nw = $defW
    if ($ans -ne '') { $n = 0; if ([int]::TryParse($ans, [ref]$n) -and $n -ge 1) { $nw = $n } }
    $extra = $nw - 1
    if ($extra -gt 0) {
        $cmdPath = Join-Path $Root 'Convert.cmd'
        $opened = 0
        for ($i = 1; $i -le $extra; $i++) {
            try { Start-Process -FilePath $cmdPath -ArgumentList '-WorkerOnly' -WorkingDirectory $Root | Out-Null; $opened++ }
            catch { Write-CvLog 'GLOBAL' ("[AVISO] - No se pudo abrir un worker adicional: {0}" -f $_.Exception.Message) }
        }
        Write-CvLog 'GLOBAL' ("[WORKER] - Abiertos {0} worker(s) adicional(es); {1} en paralelo." -f $opened, ($opened + 1))
    }
}

# ============================================================
#  FASE WORKER
# ============================================================
Write-Host ''
Write-CvLog 'GLOBAL' '[WORKER] - Buscando archivos preparados para codificar...'

# Reintentos: nº de fallos por archivo; a partir de $maxRetries se abandona (evita bucle
# infinito con inputs corruptos, perfiles que fallan o ffmpeg que no arranca).
$skip = New-Object 'System.Collections.Generic.HashSet[string]'
$fail = @{}
$maxRetries = 2

$didAny = $true
while ($didAny) {
    $didAny = $false
    foreach ($f in (Get-SourceFiles -Context $ctx)) {
        $name = $f.BaseName
        if ($skip.Contains($name)) { continue }                        # marcado como no procesable
        $out  = Get-OutputPath $ctx $name
        if (Test-Path -LiteralPath $out) { continue }                       # ya hecho
        if (-not (Test-CvJob -Context $ctx -Name $name)) { continue }  # sin preparar

        # Reclamo atomico
        if (-not (Enter-Lock -Context $ctx -Name $name)) { continue }  # lo tiene otro worker
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            Write-Host ''
            Write-Host ''
            Write-Host $sepLine
            Write-CvLog 'WORKER' ("CODIFICANDO: {0}" -f $name)
            Write-Host $sepLine

            $job  = Read-CvJob -Context $ctx -Name $name
            $prof = $job.profile

            # Versiones de herramientas fijadas en el job (fallback a la del contexto).
            $ffVer = "$($job.ffmpegVersion)";  if ([string]::IsNullOrWhiteSpace($ffVer)) { $ffVer = $ctx.FFmpegVersion }
            $agVer = "$($job.aacgainVersion)"; if ([string]::IsNullOrWhiteSpace($agVer)) { $agVer = $ctx.AacGainVersion }

            # Asegurar ffmpeg de la version del job (se instala si falta). Si no se puede,
            # se marca para no reintentar en bucle y se pasa al siguiente.
            if (-not (Confirm-CvTool -Context $ctx -Name 'ffmpeg' -Version $ffVer)) {
                Write-CvLog 'WORKER' ("[ERR] - No se pudo obtener ffmpeg {0}; se omite este archivo" -f $ffVer)
                [void]$skip.Add($name); continue
            }
            $didAny = $true
            $jctx = New-CvToolContext -Context $ctx -FFmpegVersion $ffVer -AacGainVersion $agVer
            Write-CvLog 'WORKER' ("[INFO] - ffmpeg {0}" -f $ffVer)
            if ("$($jctx.VolumeMethod)".ToLower() -eq 'aacgain' -and -not (Confirm-CvTool -Context $ctx -Name 'aacgain' -Version $agVer)) {
                Write-CvLog 'WORKER' ("[AVISO] - No se pudo obtener aacgain {0}; el ajuste de volumen se omitira" -f $agVer)
            }

            $info = Get-MediaInfo -Context $jctx -File $f.FullName
            if ($null -eq $info) {
                Write-CvLog 'WORKER' '[ERR] - No se pudo leer el archivo; se descarta'
                [void]$skip.Add($name); continue
            }

            # Info del archivo (util para saber cuanto durara la codificacion).
            $vs = Get-VideoStream $info
            if ($vs) { Write-CvLog 'WORKER' ("[INFO] - Resolucion: {0}  Duracion: {1}" -f (Get-VideoSize -VideoStream $vs), (Get-DurationText $info)) }
            else     { Write-CvLog 'WORKER' ("[INFO] - Duracion: {0}" -f (Get-DurationText $info)) }

            # ---------- AUDIO ----------
            Write-Host ''
            $audioOk = $true
            if ($job.audio.skip) { Write-CvLog 'AUDIO' '[SKIP] - se omite (copy/omitido)' }
            else { $audioOk = Invoke-AudioRun -Context $jctx -Profile $prof -File $f.FullName -Sync ([double]$job.audio.sync) -Index ([int]$job.audio.index) }

            # ---------- VIDEO ----------
            Write-Host ''
            $videoOk = $true
            if ($job.video.skip) { Write-CvLog 'VIDEO' '[SKIP] - se omite (copy)' }
            else { $videoOk = Invoke-VideoRun -Context $jctx -Profile $prof -File $f.FullName -Crop $job.video.crop -Resize $job.video.resize -Anim ([bool]$job.video.anim) }

            # ---------- MULTIPLEX ----------
            if ((-not $audioOk) -or (-not $videoOk)) {
                Write-CvLog 'WORKER' '[ERR] - Fallo la codificacion de audio o video; no se multiplexa'
                $ok = $false
            } else {
                Write-Host ''
                $ok = Invoke-Multiplex -Context $jctx -File $f.FullName -Info $info -VideoSkipped ([bool]$job.video.skip) -AudioSkipped ([bool]$job.audio.skip) -Subtitles $job.subtitles
            }

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
                Write-ConversionSummary -Context $jctx -File $f.FullName -Info $info -Output $out -Elapsed $sw.Elapsed
            } else {
                $n = 1 + [int]$fail[$name]; $fail[$name] = $n
                Write-Host ''
                if ($n -ge $maxRetries) {
                    Write-CvLog 'WORKER' ("[ERR] - Fallo {0} intento(s), se abandona: {1}" -f $n, $name)
                    [void]$skip.Add($name)
                } else {
                    Write-CvLog 'WORKER' ("[ERR] - No se genero la salida (intento {0}/{1}), se reintentara: {2}" -f $n, $maxRetries, $name)
                }
            }
        }
        catch {
            # Error inesperado: no abortar todo el lote; contar el fallo y pasar al siguiente.
            $n = 1 + [int]$fail[$name]; $fail[$name] = $n
            Write-CvLog 'WORKER' ("[ERR] - Error inesperado en {0}: {1}" -f $name, $_.Exception.Message)
            if ($n -ge $maxRetries) { [void]$skip.Add($name) }
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

# Cerrar el log de la ejecucion.
if ($cvLog) { Stop-CvLog }
