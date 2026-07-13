<#
    Context.psm1 - Contexto de ejecucion (rutas, herramientas y opciones desde config.json)
    y helpers de contexto (idiomas, parseo de numeros invariante).
#>

function Get-CvVersion {
    <# Version del proyecto (fuente unica; la usan Convert.ps1 y setup.ps1). #>
    '4.4.0'
}

function Get-CvAppName {
    <# Nombre del proyecto/aplicacion (fuente unica: titulos de ventana, cabecera). #>
    'ConvertVideo'
}

function Start-CvSession {
    <#
        Arranque COMUN de Convert.ps1 y setup.ps1 (evita duplicar la secuencia y desincronizar el
        orden): resuelve el -Config (avisa si la ruta indicada no existe), crea el contexto, fija las
        marcas ASCII, arranca el transcript y aplica apariencia (titulo = "<AppName> <Version><Suffix>")
        y cabecera. Devuelve @{ Context; ConfigPath; LogFile }. El bootstrap (encoding + Import-Module)
        se queda en cada script por ser previo a que existan estas funciones.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$Config = '',        # argumento -Config (vacio = Root\config.json)
        [string]$TitleSuffix = '',   # p. ej. ' - Setup' para el titulo de ventana
        [string]$Subtitle = '',      # subtitulo de la cabecera (p. ej. 'Setup')
        [string]$LogPrefix = 'app'   # prefijo del fichero de transcript en logs\
    )
    $cfgPath = Resolve-CvConfigPathArg -Root $Root -Config $Config
    if (-not [string]::IsNullOrWhiteSpace($Config) -and -not (Test-Path -LiteralPath $cfgPath)) {
        Write-Host ("AVISO: no existe el config indicado ({0}); se usan los valores por defecto." -f $cfgPath) -ForegroundColor Yellow
    }
    $ctx = New-CvContext -Root $Root -ConfigPath $cfgPath
    Set-CvMarkStyle -Ascii $ctx.AsciiMarks     # [OK]/[ERROR] en vez de simbolos si behavior.asciiMarks
    Set-CvSepWidth -Width $ctx.SepWidth         # ancho de los separadores de seccion (config console.sepWidth)
    Set-CvProgressBarWidth -Width $ctx.ProgressBarWidth   # ancho de la barra de progreso (config console.progressBarWidth)
    Set-CvPromptStopOnType -Value $ctx.PromptStopOnType   # auto-timeout: desactivar al teclear (behavior.promptTimeoutStopOnType)
    $log = Start-CvLog -Context $ctx -Prefix $LogPrefix   # transcript a logs\ (antes de pintar, para capturarlo)
    Set-CvAppearance -Context $ctx -Title ("{0} {1}{2}" -f $ctx.AppName, $ctx.Version, $TitleSuffix)
    Show-CvHeader -Context $ctx -Subtitle $Subtitle
    [pscustomobject]@{
        Context    = $ctx
        ConfigPath = $cfgPath
        LogFile    = $log
    }
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
    # Defaults (fuente unica): se usan como fallback cuando un valor de $cfg es INVALIDO (no cuando
    # falta, que ya lo cubre la fusion de Get-CvConfig). Asi los numeros/opciones por defecto viven
    # SOLO en Get-CvConfigDefaults y no se re-hardcodean aqui.
    $def = Get-CvConfigDefaults
    $plat  = Get-CvPlatform
    $ffSel = "$($cfg.downloads.ffmpeg.selected)"
    $agSel = "$($cfg.downloads.aacgain.selected)"

    $ctx = [pscustomobject]@{
        Root           = $Root
        # Fichero de config en uso (Root\config.json por defecto, o el pasado con -Config).
        ConfigPath     = $cfgFile
        Version        = Get-CvVersion
        AppName        = Get-CvAppName
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
        # Forzar el fps de salida (-r). $true = como hasta ahora; $false = conserva el fps de origen.
        ForceFps       = [bool]$cfg.encode.forceFps
        # 2-pass de NVENC (-multipass): 'off'|'qres'|'fullres'. Solo lo usan los encoders NVENC.
        Multipass      = (Resolve-CvOneOf "$($cfg.encode.multipass)" @('off','qres','fullres') "$($def.encode.multipass)")
        # Tone-mapping HDR->SDR (BT.709): 'auto' = solo si el origen es HDR; 'off' = nunca.
        TonemapHdr     = (Resolve-CvOneOf "$($cfg.encode.tonemapHdr)" @('auto','off') "$($def.encode.tonemapHdr)")
        # Video anamorfico (SAR!=1): 'keep' = conserva SAR; 'square'/'squareheight' = cuadra a pixeles
        # cuadrados (fijando ancho/alto). Lo consume Get-CvResize al decidir el reescalado.
        Anamorphic     = (Resolve-CvOneOf "$($cfg.encode.anamorphic)" @('keep','square','squareheight') "$($def.encode.anamorphic)")
        # Downmix 5.1->estereo: 'dialogue' = voz reforzada (pan); 'default' = downmix estandar.
        DownmixMode    = (Resolve-CvOneOf "$($cfg.encode.downmixMode)" @('default','dialogue') "$($def.encode.downmixMode)")
        # Pesos del downmix 'dialogue' (center/front/surround); el pan se construye de estos valores.
        # Del JSON llegan como numero; el cast [double] de PowerShell es invariante de locale. Con la
        # clave ausente (null) se usa el default de Get-CvDefaultDownmixCoeffs (fuente unica de los
        # numeros, sin repetirlos aqui). El LFE siempre se descarta.
        DownmixCoeffs  = $(
            $d = Get-CvDefaultDownmixCoeffs
            @{
                Center   = $(if ($null -ne $cfg.encode.downmixCoeffs.center)   { [double]$cfg.encode.downmixCoeffs.center }   else { $d.Center })
                Front    = $(if ($null -ne $cfg.encode.downmixCoeffs.front)    { [double]$cfg.encode.downmixCoeffs.front }    else { $d.Front })
                Surround = $(if ($null -ne $cfg.encode.downmixCoeffs.surround) { [double]$cfg.encode.downmixCoeffs.surround } else { $d.Surround })
            }
        )
        DefaultAudioHz = [int]$cfg.encode.audioHz
        BorderStart    = [int]$cfg.border.start
        BorderDur      = [int]$cfg.border.duration
        # Nº de puntos del video donde se escanean bordes (1 = solo al inicio, clasico).
        BorderSamples  = [int]$cfg.border.samples
        # % de votos que debe alcanzar el recorte mas votado para aceptarse sin preguntar (0-100).
        BorderAutoAcceptPct = [Math]::Min(100, [Math]::Max(0, [int]$cfg.border.autoAcceptPct))
        # Margen minimo de votos del mas votado sobre el 2o para auto-aceptar (ademas del %).
        BorderAutoAcceptMargin = [Math]::Max(0, [int]$cfg.border.autoAcceptMinMargin)
        # Modo DetectBorder='auto': puntos/seg del pre-escaneo y reduccion minima (%) para tomar el
        # recorte como barras reales (por debajo = ruido de borde -> no recorta).
        BorderAutoSamples = [Math]::Max(1, [int]$cfg.border.autoSamples)
        BorderAutoDuration = [Math]::Max(1, [int]$cfg.border.autoDuration)
        BorderMinCropPct  = [Math]::Max(0.0, [double]$cfg.border.minCropPct)   # 0.0 (no 0) para forzar el overload double y no truncar un valor fraccionario
        # Previsualizacion ffplay: inicio (0 = principio) y duracion de la muestra (0 = sin limite).
        PreviewStart   = [Math]::Max(0, [int]$cfg.preview.start)
        PreviewSeconds = [Math]::Max(0, [int]$cfg.preview.seconds)
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
        # Progreso inline (% + ETA) en los pasos largos de recodificacion en vez de ventana aparte.
        Progress       = [bool]$cfg.behavior.progress
        # Timeout de inactividad (seg) en las preguntas simples de PREPARAR: mapa {tipo -> segundos}
        # normalizado desde behavior.promptTimeout. 'default' es el generico; los tipos con -1 heredan
        # de 'default'. Lo resuelve Get-CvPromptTimeout $Context <tipo>. Tolera el formato antiguo
        # (escalar) tratandolo como el generico. 0 = desactivado.
        PromptTimeouts = (ConvertTo-CvPromptTimeouts $cfg.behavior.promptTimeout)
        # Al teclear en una pregunta con auto: $true desactiva el auto (solo ENTER); $false = clasico.
        PromptStopOnType = [bool]$cfg.behavior.promptTimeoutStopOnType
        # Modo pruebas: limite de codificacion por archivo en SEGUNDOS (0 = off = archivo completo).
        # Se activa por config (test.enabled) o con el marcador 'test_on'; los minutos salen de
        # test.minutes (>=1). Lo consumen Invoke-VideoRun/Invoke-AudioRun/Invoke-Multiplex (-t).
        TestLimit      = $(if (([bool]$cfg.test.enabled) -or (Test-Path (Join-Path $Root 'test_on'))) {
                              [int]([Math]::Max(1, [int]$cfg.test.minutes) * 60)
                          } else { 0 })
        # BETA: sincronia con el filtro 'adelay' en una pasada (combinada con el volumen), sin WAV
        # intermedio. Config test.syncAdelay. Lo consume Invoke-AudioRun.
        SyncAdelay     = [bool]$cfg.test.syncAdelay
        # BETA: activador del downmix 'dialogue' (voz reforzada). Doble llave: DownmixMode='dialogue'
        # fija el modo, pero solo refuerza la voz si BetaDownmix. Config test.betaDownmix; lo usa
        # Invoke-AudioRun junto con DownmixMode.
        BetaDownmix    = [bool]$cfg.test.betaDownmix
        # BETA: multipista de audio (conservar varias pistas del idioma preferido + elegir la default).
        # Doble llave: MultiAudio (encode.multiAudio) habilita la funcion, pero solo actua si
        # BetaMultiAudio (test.betaMultiAudio). Effectivo = MultiAudio -and BetaMultiAudio. Lo consumen
        # Invoke-AudioAsk (seleccion) y el worker/Multiplex (varias pistas). Al promocionar: quitar
        # BetaMultiAudio y dejar MultiAudio como toggle.
        MultiAudio     = [bool]$cfg.encode.multiAudio
        BetaMultiAudio = [bool]$cfg.test.betaMultiAudio
        # Conservar el titulo del audio de origen en la salida (false = titulo en blanco). Lo aplica
        # Invoke-Multiplex leyendo el titulo del origen por el indice de cada pista.
        AudioKeepTitle = [bool]$cfg.encode.audioKeepTitle
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
        # Ancho de los separadores de seccion (=== / ---) de la UI; lo aplica Set-CvSepWidth al arrancar.
        SepWidth          = [Math]::Max(1, [int]$cfg.console.sepWidth)
        # Ancho de la barra visual de progreso del worker (0 = sin barra); lo aplica Set-CvProgressBarWidth.
        ProgressBarWidth  = [Math]::Max(0, [int]$cfg.console.progressBarWidth)
        # Extensiones de ENTRADA (config encode.extensions): se normalizan a patron glob '*.ext'
        # (tolera que el usuario las escriba con o sin '*.'/'.').
        Extensions     = @(@($cfg.encode.extensions) | Where-Object { "$_" -ne '' } | ForEach-Object { '*.' + ("$_".TrimStart('*').TrimStart('.')) })
        # Canales del audio recodificado (encode.audioChannels; 2 = estereo por defecto).
        AudioChannels  = $(if ([int]$cfg.encode.audioChannels -ge 1) { [int]$cfg.encode.audioChannels } else { [int]$def.encode.audioChannels })
        # Perfiles de codificacion propios (config 'profiles'); se anaden a los de serie.
        Profiles       = @($cfg.profiles)
        # Valores por defecto del constructor de perfil CUSTOM interactivo (config 'customProfile').
        CustomVideoEncoder = "$($cfg.customProfile.videoEncoder)"
        CustomVideoProfile = "$($cfg.customProfile.videoProfile)"
        CustomVideoLevel   = "$($cfg.customProfile.videoLevel)"
        # Defaults del control de tasa: NEGATIVO (p. ej. -1) => $null = "auto" (sin -qmin/-qmax ni
        # -crf; decide el encoder); el resto se acota a 0-51 (escala QP de H.264/HEVC y CRF x264/x265).
        CustomQmin         = $(if ([int]$cfg.customProfile.qmin -lt 0) { $null } else { [Math]::Min(51, [int]$cfg.customProfile.qmin) })
        CustomQmax         = $(if ([int]$cfg.customProfile.qmax -lt 0) { $null } else { [Math]::Min(51, [int]$cfg.customProfile.qmax) })
        CustomCrf          = $(if ([int]$cfg.customProfile.crf  -lt 0) { $null } else { [Math]::Min(51, [int]$cfg.customProfile.crf) })
        CustomMultipass    = (Resolve-CvOneOf "$($cfg.customProfile.multipass)" @('off','qres','fullres') "$($def.customProfile.multipass)")
        CustomAudioBitrate = "$($cfg.customProfile.audioBitrate)"
        CustomAudioCodec   = "$($cfg.customProfile.audioCodec)"
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
        Ajusta un segundo de inicio (scan de bordes, o el inicio explicito de una preview 'P N seg')
        a la duracion real del video: si el inicio configurado (p. ej. border.start = 120) cae fuera
        porque el video es mas corto, lo lleva a ~10% de la duracion para seguir dentro del contenido
        (dejando hueco para una ventana de $Window segundos). Duracion desconocida (<=0) = sin cambios.
    #>
    param([int]$Start, [double]$Duration, [int]$Window = 5)
    if ($Duration -le 0) { return $Start }
    if (($Start + $Window) -lt $Duration) { return $Start }
    return [int]([Math]::Max(0.0, [Math]::Floor($Duration * 0.1)))
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

function Get-CvFiles {
    <#
        Lista los ficheros de $Dir que casen con uno o varios -Filters (p. ej. '*.mkv','*.srt'); con
        -Recurse baja a subcarpetas. Devuelve FileInfo UNICOS ordenados por ruta; @() si el dir no existe.
        Fuente unica del "listar ficheros por extension/patron" (clasificacion de Original, limpieza de
        Proceso, selector de subtitulos).
          -Exact: endurece el match. El `-Filter` del proveedor hereda el comodin 8.3 de Windows
        ('*.mp4' tambien casa '.mp4v', '*.avi' casa '.avix'); con -Exact se re-comprueba cada resultado
        con `-like` (comparacion real de PowerShell, sin la trampa 8.3), asi el llamador no re-filtra.
    #>
    param([Parameter(Mandatory)][string]$Dir, [string[]]$Filters = @('*'), [switch]$Recurse, [switch]$Exact)
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    $out = @()
    foreach ($f in $Filters) {
        $found = @(Get-ChildItem -LiteralPath $Dir -Filter $f -File -Recurse:$Recurse -ErrorAction SilentlyContinue)
        if ($Exact) { $found = @($found | Where-Object { $_.Name -like $f }) }
        $out += $found
    }
    @($out | Sort-Object -Property FullName -Unique)
}

function Get-CvTimeParts {
    <#
        Descompone unos segundos (double) en @{ H; M; S; MS } (milisegundos redondeados; negativo -> 0).
        Base comun de los formateadores de tiempo (Format-CvEta, ConvertTo-CvSrtStamp), cada uno con su
        propio formato de salida.
    #>
    param([double]$Seconds)
    if ($Seconds -lt 0) { $Seconds = 0 }
    $ms = [long][math]::Round($Seconds * 1000)
    $h = [math]::Floor($ms / 3600000); $ms -= $h * 3600000
    $m = [math]::Floor($ms / 60000);   $ms -= $m * 60000
    $s = [math]::Floor($ms / 1000);    $ms -= $s * 1000
    @{ H = [int]$h; M = [int]$m; S = [int]$s; MS = [int]$ms }
}


Export-ModuleMember -Function *
