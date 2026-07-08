<#
    Context.psm1 - Contexto de ejecucion (rutas, herramientas y opciones desde config.json)
    y helpers de contexto (idiomas, parseo de numeros invariante).
#>

function Get-CvVersion {
    <# Version del proyecto (fuente unica; la usan Convert.ps1 y setup.ps1). #>
    '4.1'
}

function Get-CvWorkDirs {
    <# Unica fuente de verdad de las carpetas de trabajo del proyecto (crear/comprobar). #>
    param([Parameter(Mandatory)]$Context)
    @($Context.Original, $Context.Proceso, $Context.Convertido, $Context.Tools, $Context.Logs)
}

function Resolve-CvPath {
    <#
        Resuelve una carpeta de trabajo desde config.json (seccion 'paths'):
        - vacio       -> por defecto en la carpeta del programa ($Root\<DefaultName>).
        - ruta absoluta (C:\..., D:\..., \\servidor\...) -> se usa tal cual.
        - ruta relativa -> relativa a $Root.
    #>
    param([string]$Root, [string]$Configured, [string]$DefaultName)
    if ([string]::IsNullOrWhiteSpace($Configured)) { return (Join-Path $Root $DefaultName) }
    if ([System.IO.Path]::IsPathRooted($Configured)) { return $Configured }
    return (Join-Path $Root $Configured)
}


function New-CvContext {
    <# Crea el objeto de contexto con rutas, herramientas y opciones (de config.json). #>
    param([Parameter(Mandatory)][string]$Root)

    $cfg = Get-CvConfig -Root $Root
    $plat  = Get-CvPlatform
    $ffSel = "$($cfg.downloads.ffmpeg.selected)"
    $agSel = "$($cfg.downloads.aacgain.selected)"

    $ctx = [pscustomobject]@{
        Root           = $Root
        Version        = Get-CvVersion
        # Carpetas de trabajo (configurables en config.json 'paths'; vacio = junto al programa).
        Original       = Resolve-CvPath $Root "$($cfg.paths.original)"   'Original'
        Proceso        = Resolve-CvPath $Root "$($cfg.paths.proceso)"    'Proceso'
        Convertido     = Resolve-CvPath $Root "$($cfg.paths.convertido)" 'Convertido'
        Logs           = Resolve-CvPath $Root "$($cfg.paths.logs)"       'logs'
        Tools          = Join-Path $Root 'tools'
        # Rutas de herramientas: las rellena New-CvToolContext mas abajo (fuente unica de
        # los nombres de exe), apuntando a la version 'selected'.
        FFmpeg         = $null
        FFprobe        = $null
        FFplay         = $null
        AacGain        = $null
        FFmpegVersion  = $ffSel
        AacGainVersion = $agSel
        Platform       = $plat
        Downloads      = $cfg.downloads
        VolumeMethod   = "$($cfg.volume.method)"
        LoudnormI      = $cfg.volume.loudnorm.I
        LoudnormTP     = $cfg.volume.loudnorm.TP
        LoudnormLRA    = $cfg.volume.loudnorm.LRA
        OutExt         = "$($cfg.encode.outputExtension)"
        Threads        = [int]$cfg.encode.threads
        Fps            = "$($cfg.encode.fps)"
        DefaultAudioHz = [int]$cfg.encode.audioHz
        BorderStart    = [int]$cfg.border.start
        BorderDur      = [int]$cfg.border.duration
        AudioLangs     = @($cfg.languages.audio)
        SubLangs       = @($cfg.languages.subtitle)
        # debug: desde config.json o creando el marcador 'debug_on' (cualquiera lo activa).
        Debug          = ([bool]$cfg.behavior.debug -or (Test-Path (Join-Path $Root 'debug_on')))
        # cleanTemps/separateWindow salen de config.json; los marcadores 'keep_temp' y
        # 'same_window' los desactivan sobre la marcha sin editar el json.
        CleanTemps     = ([bool]$cfg.behavior.cleanTemps     -and -not (Test-Path (Join-Path $Root 'keep_temp')))
        SeparateWindow = ([bool]$cfg.behavior.separateWindow -and -not (Test-Path (Join-Path $Root 'same_window')))
        LockClose      = [bool]$cfg.behavior.lockCloseButton
        # Workers en paralelo por defecto al terminar PREPARAR (esta ventana + N-1 nuevas).
        Workers        = [int]$cfg.behavior.workers
        # log: transcript de la ejecucion a logs\; el marcador 'no_log' lo desactiva.
        Log            = ([bool]$cfg.behavior.log -and -not (Test-Path (Join-Path $Root 'no_log')))
        # Postproceso: limpiar las etiquetas DURATION del MKV con mkvpropedit.
        # MkvPropEdit lo rellena New-CvToolContext: override de config o la version descargada.
        StripTags           = [bool]$cfg.postprocess.stripTags
        MkvPropEditOverride = "$($cfg.postprocess.mkvpropedit)"
        MkvPropEdit         = ''
        # Conservacion de adjuntos (por defecto ninguno). Permitir/excluir por categoria.
        Attachments         = [pscustomobject]@{
            Keep   = [bool]$cfg.postprocess.attachments.keep
            Fonts  = [bool]$cfg.postprocess.attachments.fonts
            Covers = [bool]$cfg.postprocess.attachments.covers
            Other  = [bool]$cfg.postprocess.attachments.other
        }
        ConsoleBackground = "$($cfg.console.background)"
        ConsoleForeground = "$($cfg.console.foreground)"
        ConsoleFont       = "$($cfg.console.font)"
        ConsoleFontSize   = [int]$cfg.console.fontSize
        WindowWidth       = [int]$cfg.console.windowWidth
        WindowHeight      = [int]$cfg.console.windowHeight
        Extensions     = @('*.avi','*.flv','*.mp4','*.mov','*.mkv')
    }

    # Rutas de las herramientas para la version 'selected' (fuente unica en New-CvToolContext).
    $ctx = New-CvToolContext -Context $ctx -FFmpegVersion $ffSel -AacGainVersion $agSel

    # Crear las carpetas de trabajo que falten (lista en Get-CvWorkDirs).
    foreach ($d in (Get-CvWorkDirs -Context $ctx)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    }
    return $ctx
}


function Test-CvLanguage {
    <#
        Compara un codigo de idioma con una lista de preferidos, normalizando variantes:
        'es_es', 'es-ES', 'es' y 'spa' se consideran el mismo idioma si estan en la lista.
        Compara tanto el codigo completo como su parte principal (antes de '-' o '_').
    #>
    param([string]$Lang, [string[]]$Prefs)
    if ([string]::IsNullOrWhiteSpace($Lang) -or $null -eq $Prefs) { return $false }
    $l = $Lang.Trim().ToLower()
    $primary = ($l -split '[-_]')[0]
    foreach ($p in $Prefs) {
        if ($null -eq $p) { continue }
        $pp = $p.Trim().ToLower()
        $pprimary = ($pp -split '[-_]')[0]
        if ($l -eq $pp -or $primary -eq $pp -or $primary -eq $pprimary) { return $true }
    }
    return $false
}


function ConvertTo-InvDouble {
    <# Parseo de decimales independiente del locale (ffmpeg usa siempre punto). #>
    param([string]$Text)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $out = 0.0
    if ([double]::TryParse($Text, [System.Globalization.NumberStyles]::Float, $inv, [ref]$out)) { return $out }
    return $null
}


Export-ModuleMember -Function *
