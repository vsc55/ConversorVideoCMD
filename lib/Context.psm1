<#
    Context.psm1 - Contexto de ejecucion (rutas, herramientas y opciones desde config.json)
    y helpers de contexto (idiomas, parseo de numeros invariante).
#>

function Get-CvVersion {
    <# Version del proyecto (fuente unica; la usan Convert.ps1 y setup.ps1). #>
    '4.2.2'
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
    param(
        [Parameter(Mandatory)][string]$Root,
        # Ruta explicita al config (parametro -Config de Convert/setup). Vacio = Root\config.json.
        [string]$ConfigPath = ''
    )

    $cfgFile = if ([string]::IsNullOrWhiteSpace($ConfigPath)) { Join-Path $Root 'config.json' } else { $ConfigPath }
    $cfg = Get-CvConfig -Root $Root -Path $cfgFile
    $plat  = Get-CvPlatform
    $ffSel = "$($cfg.downloads.ffmpeg.selected)"
    $agSel = "$($cfg.downloads.aacgain.selected)"

    $ctx = [pscustomobject]@{
        Root           = $Root
        # Fichero de config en uso (Root\config.json por defecto, o el pasado con -Config).
        ConfigPath     = $cfgFile
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
        # Pico objetivo (dBFS) del metodo 'peak'; se limita a <= 0 (positivo recortaria).
        PeakTarget     = [Math]::Min(0.0, [double]$cfg.volume.peakTarget)
        LoudnormI      = $cfg.volume.loudnorm.I
        LoudnormTP     = $cfg.volume.loudnorm.TP
        LoudnormLRA    = $cfg.volume.loudnorm.LRA
        OutExt         = "$($cfg.encode.outputExtension)"
        Threads        = [int]$cfg.encode.threads
        Fps            = "$($cfg.encode.fps)"
        DefaultAudioHz = [int]$cfg.encode.audioHz
        BorderStart    = [int]$cfg.border.start
        BorderDur      = [int]$cfg.border.duration
        # Nº de puntos del video donde se escanean bordes (1 = solo al inicio, clasico).
        BorderSamples  = [int]$cfg.border.samples
        # % de votos que debe alcanzar el recorte mas votado para aceptarse sin preguntar (0-100).
        BorderAutoAcceptPct = [Math]::Min(100, [Math]::Max(0, [int]$cfg.border.autoAcceptPct))
        # Margen minimo de votos del mas votado sobre el 2o para auto-aceptar (ademas del %).
        BorderAutoAcceptMargin = [Math]::Max(0, [int]$cfg.border.autoAcceptMinMargin)
        # Previsualizacion ffplay (inicio y duracion de la muestra en PREPARAR).
        PreviewStart   = [int]$cfg.preview.start
        PreviewSeconds = [int]$cfg.preview.seconds
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
        # Reintentos por archivo cuando la codificacion falla (antes de abandonarlo).
        Retries        = [int]$cfg.behavior.retries
        # Marcas/avisos en ASCII puro ([OK]/[ERROR]) en vez de simbolos/badge (consolas sin glifos).
        AsciiMarks     = [bool]$cfg.behavior.asciiMarks
        # Modo pruebas: limite de codificacion por archivo en SEGUNDOS (0 = off = archivo completo).
        # Se activa por config (test.enabled) o con el marcador 'test_on'; los minutos salen de
        # test.minutes (>=1). Lo consumen Invoke-VideoRun/Invoke-AudioRun/Invoke-Multiplex (-t).
        TestLimit      = $(if (([bool]$cfg.test.enabled) -or (Test-Path (Join-Path $Root 'test_on'))) {
                              [int]([Math]::Max(1, [int]$cfg.test.minutes) * 60)
                          } else { 0 })
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
        # Extensiones de ENTRADA (config encode.extensions): se normalizan a patron glob '*.ext'
        # (tolera que el usuario las escriba con o sin '*.'/'.').
        Extensions     = @(@($cfg.encode.extensions) | Where-Object { "$_" -ne '' } | ForEach-Object { '*.' + ("$_".TrimStart('*').TrimStart('.')) })
        # Canales del audio recodificado (encode.audioChannels; 2 = estereo por defecto).
        AudioChannels  = $(if ([int]$cfg.encode.audioChannels -ge 1) { [int]$cfg.encode.audioChannels } else { 2 })
        # Perfiles de codificacion propios (config 'profiles'); se anaden a los de serie.
        Profiles       = @($cfg.profiles)
    }

    # Rutas de las herramientas para la version 'selected' (fuente unica en New-CvToolContext).
    $ctx = New-CvToolContext -Context $ctx -FFmpegVersion $ffSel -AacGainVersion $agSel

    # Crear las carpetas de trabajo que falten (lista en Get-CvWorkDirs).
    foreach ($d in (Get-CvWorkDirs -Context $ctx)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    }
    return $ctx
}


function Get-CvLangCanon {
    <#
        Canonicaliza un codigo de idioma a una forma unica, para que las distintas variantes
        (ISO 639-1 de 2 letras, ISO 639-2 de 3 letras y nombres) del MISMO idioma se comparen
        como iguales: 'es', 'spa', 'esp', 'es-ES', 'castellano', 'spanish' -> 'es'.
        Asi basta con tener UN codigo en la lista de preferidos para reconocer cualquier variante.
    #>
    param([string]$Code)
    if ([string]::IsNullOrWhiteSpace($Code)) { return '' }
    $c = ($Code.Trim().ToLower() -split '[-_]')[0]   # parte principal (antes de '-' o '_')
    switch -Regex ($c) {
        '^(es|spa|esp|spanish|castellano|espanol)$'  { return 'es' }
        '^(en|eng|english)$'                         { return 'en' }
        '^(fr|fre|fra|french|frances)$'              { return 'fr' }
        '^(de|ger|deu|german|aleman)$'               { return 'de' }
        '^(it|ita|italian|italiano)$'                { return 'it' }
        '^(pt|por|portuguese|portugues)$'            { return 'pt' }
        '^(ja|jpn|japanese|japones)$'                { return 'ja' }
        '^(zh|chi|zho|chinese|chino)$'               { return 'zh' }
        '^(ko|kor|korean|coreano)$'                  { return 'ko' }
        '^(ru|rus|russian|ruso)$'                    { return 'ru' }
        '^(ca|cat|catalan)$'                         { return 'ca' }
        '^(gl|glg|galician|gallego)$'                { return 'gl' }
        '^(eu|baq|eus|basque|euskera|vasco)$'        { return 'eu' }
        default { return $c }
    }
}

function Get-CvSafeStart {
    <#
        Ajusta un segundo de inicio (para scan de bordes o preview) a la duracion real del video:
        si el inicio configurado (p. ej. border.start/preview.start = 120) cae fuera porque el
        video es mas corto, lo lleva a ~10% de la duracion para seguir dentro del contenido
        (dejando hueco para una ventana de $Window segundos). Duracion desconocida (<=0) = sin cambios.
    #>
    param([int]$Start, [double]$Duration, [int]$Window = 5)
    if ($Duration -le 0) { return $Start }
    if (($Start + $Window) -lt $Duration) { return $Start }
    return [int]([Math]::Max(0, [Math]::Floor($Duration * 0.1)))
}

function Test-CvLanguage {
    <#
        Compara un codigo de idioma con una lista de preferidos. Canonicaliza ambos lados
        (Get-CvLangCanon), de modo que 'es_es', 'es-ES', 'es' y 'spa' se consideran el mismo
        idioma AUNQUE la lista solo tenga uno de ellos. Tambien mantiene la comparacion por
        codigo completo y por parte principal (antes de '-' o '_') como respaldo.
    #>
    param([string]$Lang, [string[]]$Prefs)
    if ([string]::IsNullOrWhiteSpace($Lang) -or $null -eq $Prefs) { return $false }
    $l = $Lang.Trim().ToLower()
    $primary = ($l -split '[-_]')[0]
    $lc = Get-CvLangCanon $l
    foreach ($p in $Prefs) {
        if ($null -eq $p) { continue }
        $pp = $p.Trim().ToLower()
        $pprimary = ($pp -split '[-_]')[0]
        if ($l -eq $pp -or $primary -eq $pp -or $primary -eq $pprimary) { return $true }
        if ($lc -ne '' -and $lc -eq (Get-CvLangCanon $pp)) { return $true }
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
