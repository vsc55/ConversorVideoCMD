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
    [switch]$WorkerOnly,
    # Fichero de configuracion a usar (por defecto config.json junto al programa). Admite ruta
    # absoluta o relativa al directorio actual. Permite tener varios perfiles de config.
    [string]$Config = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
$modules = @('Log','Config','Context','Console','Exec','Job','Tools','MediaInfo','Profile','Video','Audio','Subtitle','Attachment','Multiplex')
foreach ($m in $modules) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

# Resolver el fichero de config (-Config): relativo al directorio actual; vacio = Root\config.json.
$cfgPath = Resolve-CvConfigPathArg -Root $Root -Config $Config
if (-not [string]::IsNullOrWhiteSpace($Config) -and -not (Test-Path -LiteralPath $cfgPath)) {
    Write-Host ("AVISO: no existe el config indicado ({0}); se usan los valores por defecto." -f $cfgPath) -ForegroundColor Yellow
}

$ctx = New-CvContext -Root $Root -ConfigPath $cfgPath
Set-CvMarkStyle -Ascii $ctx.AsciiMarks   # [OK]/[ERROR] en vez de simbolos si behavior.asciiMarks

# Log de la ejecucion (transcript) a logs\ (behavior.log / marcador 'no_log').
$cvLog = Start-CvLog -Context $ctx -Prefix 'Convert'

# Colores, fuente, tamano y titulo de la ventana (config.json).
Set-CvAppearance -Context $ctx -Title ("ConversorVideoCMD {0}" -f $ctx.Version)

# Cabecera (app + version).
Show-CvHeader -Context $ctx

# Separadores de secciones (ancho del cuadro de los menus).
$sepLine  = ('=' * 64)
$dashLine = ('-' * 64)

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

# mkvtoolnix (mkvpropedit, para limpiar las etiquetas del MKV final): se asegura al arrancar
# si postprocess.stripTags esta activo y no se ha fijado una ruta propia (postprocess.mkvpropedit).
if ($ctx.StripTags -and [string]::IsNullOrWhiteSpace("$($ctx.MkvPropEditOverride)")) {
    $mkvApp = Get-CvAppDescriptor -Context $ctx -Name 'mkvtoolnix'
    $mkvSel = if ($mkvApp) { "$($mkvApp.selected)" } else { '' }
    if ($mkvSel -and (Test-CvToolSupported -Context $ctx -Name 'mkvtoolnix') -and -not (Test-CvToolInstalled -Context $ctx -Name 'mkvtoolnix' -Version $mkvSel)) {
        Write-CvLog 'GLOBAL' ("[MKVTOOLNIX] - Falta la version {0}; se descarga para limpiar las etiquetas del MKV." -f $mkvSel)
        if (Confirm-CvTool -Context $ctx -Name 'mkvtoolnix' -Version $mkvSel) { $didInstall = $true }
        else { Write-CvLog 'GLOBAL' '[MKVTOOLNIX] - [AVISO] - No disponible; el MKV final conservara las etiquetas DURATION.' }
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
    # -Filter hereda el comodin 8.3 de Windows ('*.mp4' tambien casa '.mp4v', '*.avi' casa
    # '.avix'): re-filtrar por extension EXACTA. -Unique dedupe por si dos patrones solapan.
    $allowed = @($Context.Extensions | ForEach-Object { "$_".TrimStart('*').ToLower() })   # '.mp4'
    return @($files | Where-Object { $allowed -contains $_.Extension.ToLower() } | Sort-Object Name -Unique)
}

function Get-ProcessableFiles {
    <#
        Candidatos realmente procesables: los de Get-SourceFiles MENOS los que colisionan por
        nombre. Dos entradas con el mismo BaseName y distinta extension (peli.mp4 + peli.mkv)
        comparten job/salida/lock (todo cuelga del nombre sin extension); para no procesar el
        equivocado se IGNORAN TODOS los del grupo. -Quiet omite el aviso (lo usa el bucle del
        worker, que re-escanea en cada pasada; el aviso ya se dio al arrancar).
    #>
    param($Context, [switch]$Quiet)
    $files = @(Get-SourceFiles -Context $Context)
    $dups  = @($files | Group-Object BaseName | Where-Object { $_.Count -gt 1 })
    if ($dups.Count -gt 0) {
        if (-not $Quiet) {
            foreach ($d in $dups) {
                $exts = (@($d.Group | ForEach-Object { $_.Extension }) -join ', ')
                Write-CvLog 'GLOBAL' ("[AVISO] - Nombre duplicado en Original: '{0}' ({1}); se IGNORAN (renombra o quita uno)." -f $d.Name, $exts)
            }
        }
        $dupNames = @($dups | ForEach-Object { $_.Name })
        $files = @($files | Where-Object { $dupNames -notcontains $_.BaseName })
    }
    return $files
}

function Write-PrepareHeader {
    <# Cabecera del archivo en PREPARAR (modo normal): el nombre arriba, para que las preguntas
       interactivas (video/audio/subtitulos/bordes) queden indentadas DEBAJO y se sepa siempre
       de que archivo son. #>
    param([string]$Name)
    Write-Host ''
    Write-Host (" - {0}" -f $Name) -ForegroundColor Cyan
}

function Write-PrepareStatus {
    <#
        Estado final de PREPARAR por archivo, indentado bajo su cabecera (Write-PrepareHeader),
        como una LINEA CON ETIQUETA (no un [OK] suelto): "Preparado [OK]".
          -Warn: hubo intervencion manual (seleccion de pista de video con varias, o audio sin
                 idioma preferido) -> se resalta en amarillo con [AVISO], no como error.
        El estado va en COLOR DE TEXTO (no fondo, que en la consola de Windows se "estira" al
        redimensionar la ventana).
    #>
    param([bool]$Ok, [switch]$Warn)
    if (-not $Ok) {
        Write-Host '   No se pudo preparar ' -NoNewline; Write-Host (Get-CvMark $false) -ForegroundColor Red
        return
    }
    if ($Warn) {
        Write-Host '   Preparado (seleccion manual) ' -NoNewline; Write-Host (Get-CvMark $true) -ForegroundColor Yellow
    } else {
        Write-Host '   Preparado ' -NoNewline; Write-Host (Get-CvMark $true) -ForegroundColor Green
    }
}

# ============================================================
#  CLASIFICAR: hay algun archivo POR PREPARAR?
# ============================================================
# Candidatos: carpeta Original + extension exacta, EXCLUYENDO los que colisionan por nombre
# (mismo BaseName con distinta extension: se avisa aqui y se ignoran; ver Get-ProcessableFiles).
$files = @(Get-ProcessableFiles -Context $ctx)
if ($files.Count -eq 0) {
    Write-CvLog 'GLOBAL' ("[FIN] - No hay archivos procesables en {0}" -f $ctx.Original)
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
    $cfgProfile = Select-Profile -Extra $ctx.Profiles
    if ($null -eq $cfgProfile) {
        # El usuario eligio salir (X): cierre limpio.
        Write-CvLog 'GLOBAL' '[SALIR] - Cancelado por el usuario.'
        if ($ctx.LockClose) { Set-CvCloseButton -Enabled $true }
        if ($cvLog) { Stop-CvLog }
        exit 0
    }
    Write-ProfileInfo -Prof $cfgProfile

    Write-CvLog 'GLOBAL' '[PREPARAR] - Generando configuracion de los archivos...'
    foreach ($f in $files) {
        $name = $f.BaseName
        if (Test-Path -LiteralPath (Get-OutputPath $ctx $name)) { continue }
        if (Test-CvJob -Context $ctx -Name $name)    { continue }

        # Cabecera del archivo ANTES de las preguntas: en modo normal el nombre va arriba para
        # que los menus/preguntas (video, audio, subtitulos, bordes, sincronia) queden debajo y
        # se sepa siempre de que archivo son; en debug la cabecera completa va mas abajo.
        if (-not $ctx.Debug) { Write-PrepareHeader -Name $name }

        $info = Get-MediaInfo -Context $ctx -File $f.FullName
        if ($null -eq $info) {
            if ($ctx.Debug) { Write-CvLog 'PREPARAR' ("[ERR] - No se pudo leer {0}" -f $name) } else { Write-PrepareStatus -Ok $false }
            continue
        }

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

        $vAsk   = Invoke-VideoAsk -Context $ctx -Prof $cfgProfile -Info $info -ForceBorder $forceBorder
        $aAsk   = Invoke-AudioAsk -Context $ctx -Prof $cfgProfile -Info $info
        $subManual = $false
        $subSel = Select-Subtitles -Context $ctx -Info $info -Manual ([ref]$subManual)

        # Congelar el perfil + las respuestas + las versiones de herramientas en el job
        # (autosuficiente: el worker usara estas versiones y las instalara si faltan).
        $job = [ordered]@{
            file           = $f.FullName
            profile        = $cfgProfile
            ffmpegVersion  = $ctx.FFmpegVersion
            aacgainVersion = $ctx.AacGainVersion
            video          = @{ skip = $vAsk.Skip; index = $vAsk.Index; crop = $vAsk.Crop; resize = $vAsk.Resize; anim = $vAsk.Anim }
            audio          = @{ skip = $aAsk.Skip; index = $aAsk.Index; is51 = $aAsk.Is51; sync = $aAsk.Sync; lang = $aAsk.Lang }
            subtitles      = @($subSel)
        }
        Write-CvJob -Context $ctx -Name $name -Job $job

        # Hubo intervencion manual si el archivo necesito CUALQUIER pregunta: seleccion de pista
        # de video/audio/subtitulo, deteccion de bordes, animacion o sincronia. Se marca [AVISO].
        $manual = ([bool]$vAsk.Manual) -or ([bool]$aAsk.Manual) -or $subManual
        if ($ctx.Debug) {
            Write-Host ''
            Write-CvLog 'PREPARAR' ("[OK] - Job creado: {0}.job.json{1}" -f $name, $(if ($manual) { ' (seleccion manual)' } else { '' }))
        } else {
            Write-PrepareStatus -Ok $true -Warn:$manual
        }
    }
    Write-CvLog 'GLOBAL' '[PREPARAR] - Configuracion completada.'

    # Preguntar cuantos workers codificaran EN PARALELO (esta ventana + N-1 ventanas nuevas).
    # Las ventanas nuevas se lanzan en modo -WorkerOnly: como ya esta todo preparado, entran
    # directas a codificar sin preguntar y se reparten los archivos por el lock.
    Write-Host ''
    $defW = [int]$ctx.Workers; if ($defW -lt 0) { $defW = 0 }
    $ans = (Read-Host ("[GLOBAL] - Workers en paralelo, contando esta ventana (ENTER = {0}, 0 = solo preparar y salir)" -f $defW)).Trim()
    $nw = $defW
    if ($ans -ne '') { $n = 0; if ([int]::TryParse($ans, [ref]$n) -and $n -ge 0) { $nw = $n } }

    if ($nw -le 0) {
        # Solo preparar: no se codifica ni se abre ningun worker. Los jobs quedan listos para
        # lanzar la conversion despues (abriendo Convert.cmd cuando se quiera).
        Write-CvLog 'GLOBAL' '[PREPARAR] - Solo preparar: los jobs quedan listos. Abre Convert.cmd cuando quieras codificar.'
        if ($ctx.LockClose) { Set-CvCloseButton -Enabled $true }
        if ($cvLog) { Stop-CvLog }
        exit 0
    }

    $extra = $nw - 1
    if ($extra -gt 0) {
        $cmdPath = Join-Path $Root 'Convert.cmd'
        # Los workers extra heredan el mismo -Config (ruta absoluta ya resuelta), solo si el
        # usuario lo indico (sin -Config cada ventana resuelve su config.json por defecto).
        $wArgs = @('-WorkerOnly')
        if (-not [string]::IsNullOrWhiteSpace($Config)) { $wArgs += @('-Config', ('"{0}"' -f $cfgPath)) }
        $opened = 0
        for ($i = 1; $i -le $extra; $i++) {
            try { Start-Process -FilePath $cmdPath -ArgumentList $wArgs -WorkingDirectory $Root | Out-Null; $opened++ }
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
$maxRetries = [int]$ctx.Retries; if ($maxRetries -lt 1) { $maxRetries = 1 }

$didAny = $true
while ($didAny) {
    $didAny = $false
    foreach ($f in (Get-ProcessableFiles -Context $ctx -Quiet)) {
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
            Write-Host $(if ($ctx.Debug) { $sepLine } else { $dashLine })

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
            if ($jctx.Debug) { Write-CvLog 'WORKER' ("[INFO] - ffmpeg {0}" -f $ffVer) } else { Write-Host (" - ffmpeg {0}" -f $ffVer) }
            if ("$($jctx.VolumeMethod)".ToLower() -eq 'aacgain' -and -not (Confirm-CvTool -Context $ctx -Name 'aacgain' -Version $agVer)) {
                Write-CvLog 'WORKER' ("[AVISO] - No se pudo obtener aacgain {0}; el ajuste de volumen se omitira" -f $agVer)
            }

            $info = Get-MediaInfo -Context $jctx -File $f.FullName
            if ($null -eq $info) {
                Write-CvLog 'WORKER' '[ERR] - No se pudo leer el archivo; se descarta'
                [void]$skip.Add($name); continue
            }

            # Info del archivo (util para saber cuanto durara la codificacion).
            $vs  = Get-VideoStream $info
            $res = if ($vs) { ("Resolucion: {0}  Duracion: {1}" -f (Get-VideoSize -VideoStream $vs), (Get-DurationText $info)) } else { ("Duracion: {0}" -f (Get-DurationText $info)) }
            if ($jctx.Debug) { Write-CvLog 'WORKER' ("[INFO] - {0}" -f $res) } else { Write-Host (" - {0}" -f $res) }

            # ---------- AUDIO ----------
            if ($jctx.Debug) { Write-Host '' }
            $audioOk = $true
            if ($job.audio.skip) { if ($jctx.Debug) { Write-CvLog 'AUDIO' '[SKIP] - se omite (copy/omitido)' } else { Write-Host ' - Audio (copy)' } }
            else { $audioOk = Invoke-AudioRun -Context $jctx -Prof $prof -File $f.FullName -Sync ([double]$job.audio.sync) -Index ([int]$job.audio.index) }

            # ---------- VIDEO ----------
            if ($jctx.Debug) { Write-Host '' }
            $videoOk = $true
            # Indice de la pista de video elegida (congelado en PREPARAR). Jobs antiguos sin el
            # campo -> -1, y tanto Invoke-VideoRun como Invoke-Multiplex caen a '0:v:0' como antes.
            $vIdx = if ($null -ne $job.video.index) { [int]$job.video.index } else { -1 }
            if ($job.video.skip) { if ($jctx.Debug) { Write-CvLog 'VIDEO' '[SKIP] - se omite (copy)' } else { Write-Host ' - Video (copy)' } }
            else { $videoOk = Invoke-VideoRun -Context $jctx -Prof $prof -File $f.FullName -Crop $job.video.crop -Resize $job.video.resize -Anim ([bool]$job.video.anim) -Index $vIdx }

            # ---------- MULTIPLEX ----------
            if ((-not $audioOk) -or (-not $videoOk)) {
                Write-CvLog 'WORKER' '[ERR] - Fallo la codificacion de audio o video; no se multiplexa'
                $ok = $false
            } else {
                if ($jctx.Debug) { Write-Host '' }
                $ok = Invoke-Multiplex -Context $jctx -File $f.FullName -Info $info -VideoSkipped ([bool]$job.video.skip) -AudioSkipped ([bool]$job.audio.skip) -Subtitles $job.subtitles -AudioLang "$($job.audio.lang)" -VideoIndex $vIdx
            }

            if ($ok) {
                # limpieza de temporales (activable/desactivable con el marcador 'keep_temp')
                if ($ctx.CleanTemps) {
                    Remove-CvTemps -Context $ctx -Name $name
                } elseif ($ctx.Debug) {
                    Write-CvLog 'WORKER' '[TEMP] - Se conservan los temporales (existe marcador keep_temp)'
                }
                Remove-CvJob -Context $ctx -Name $name
                $sw.Stop()
                if ($ctx.Debug) {
                    Write-Host ''
                    Write-CvLog 'WORKER' ("[OK] - Finalizado: {0}" -f $name)
                }
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
