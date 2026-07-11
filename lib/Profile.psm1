<#
    Profile.psm1 - Perfiles de codificacion predefinidos y menu de seleccion.
    Espejo de select_profile.cmd. Devuelve un objeto de configuracion que se
    congela dentro de cada .job.
#>

function New-CvProfile {
    <# Estructura base de un perfil, con valores por defecto. #>
    param(
        [string]$VideoEncoder = '',   # copy | hevc_nvenc | libx265 | h264_nvenc | libx264
        [string]$VideoProfile = '',   # main10 | main | ''(=ninguno)
        [string]$VideoLevel   = '',   # 5 | 4.1 | ''
        [object]$Qmin = $null,
        [object]$Qmax = $null,
        [object]$Crf  = $null,
        [object]$DetectBorder = $false,   # $false (nunca) | $true (siempre, interactivo) | 'auto' (pre-escaneo decide)
        [string]$ChangeSize = '',      # '' = no | '1920:-2' etc. (escala SIEMPRE; altura -2 = auto y PAR)
        [object]$MaxWidth = $null,     # $null = no | 1920 etc. (reduce a ese ancho SOLO si es mayor; nunca amplia)
        [string]$Multipass = '',       # '' = usar el global (encode.multipass) | off | qres | fullres (NVENC)
        [string]$AudioEncoder = 'aac_coder',  # aac_coder (recodificar) | copy
        [string]$AudioCodec = 'aac',   # codec de salida al recodificar: aac | ac3 | eac3 | libmp3lame | flac | libopus
        [string]$AudioBitrate = '192k',
        [int]$AudioHz = 44100,
        # Salida de audio POR PERFIL (override del global; $null = usar el global encode.*):
        [object]$AudioChannels = $null,   # MAXIMO de canales (no hace upmix). $null = encode.audioChannels | 2 | 6 | 8
        [object]$DownmixMode   = $null,   # $null = encode.downmixMode | 'default' | 'dialogue' (voz reforzada, BETA)
        [object]$DownmixCoeffs = $null    # $null = encode.downmixCoeffs | @{ Center; Front; Surround }
    )
    [pscustomobject]@{
        VideoEncoder = $VideoEncoder; VideoProfile = $VideoProfile; VideoLevel = $VideoLevel
        Qmin = $Qmin; Qmax = $Qmax; Crf = $Crf; DetectBorder = $DetectBorder; ChangeSize = $ChangeSize; MaxWidth = $MaxWidth
        Multipass = $Multipass
        AudioEncoder = $AudioEncoder; AudioCodec = $AudioCodec; AudioBitrate = $AudioBitrate; AudioHz = $AudioHz
        AudioChannels = $AudioChannels; DownmixMode = $DownmixMode; DownmixCoeffs = $DownmixCoeffs
    }
}

function Get-CvAudioChannels {
    <# Catalogo de canales de salida para los menus (@{Value;Text}). #>
    @(
        @{ Value = '2'; Text = 'estereo' }
        @{ Value = '6'; Text = '5.1' }
        @{ Value = '8'; Text = '7.1' }
    )
}

function Get-CvDownmixModes {
    <# Catalogo de modos de downmix 5.1->estereo para los menus (@{Value;Text}). #>
    @(
        @{ Value = 'default';  Text = 'estandar de ffmpeg' }
        @{ Value = 'dialogue'; Text = 'voz reforzada (BETA; requiere test.betaDownmix)' }
    )
}

function ConvertTo-CvDownmixCoeffs {
    <#
        Convierte un objeto de coeficientes de config.json (camelCase center/front/surround) en
        @{ Center; Front; Surround }. Devuelve $null si el objeto es $null (=> usar el global). Las
        subclaves ausentes caen al default de Get-CvDefaultDownmixCoeffs (fuente unica de los numeros).
        El cast [double] de PS es invariante de locale (los numeros del JSON ya vienen como double).
    #>
    param($Obj)
    if ($null -eq $Obj) { return $null }
    $d = Get-CvDefaultDownmixCoeffs
    @{
        Center   = $(if ($null -ne (Get-CvProfileProp $Obj 'center'   $null)) { [double](Get-CvProfileProp $Obj 'center'   $d.Center) }   else { $d.Center })
        Front    = $(if ($null -ne (Get-CvProfileProp $Obj 'front'    $null)) { [double](Get-CvProfileProp $Obj 'front'    $d.Front) }    else { $d.Front })
        Surround = $(if ($null -ne (Get-CvProfileProp $Obj 'surround' $null)) { [double](Get-CvProfileProp $Obj 'surround' $d.Surround) } else { $d.Surround })
    }
}

function Get-CvProfiles {
    <#
        Perfiles de serie por GRUPOS. Cada grupo (objeto con .Profiles) se muestra junto en el menu
        y se separa del siguiente con una linea en blanco; la numeracion (1..N) es CONTINUA a
        traves de los grupos. Anadir/quitar/reordenar aqui basta: el numero y el texto del menu se
        generan solos (Select-Profile + Format-CvProfileLabel), sin listas paralelas.
    #>
    @(
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'copy')
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23)
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -DetectBorder $true)
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -DetectBorder 'auto')
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -MaxWidth 1920)
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -MaxWidth 1920 -DetectBorder $true)
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -MaxWidth 1920 -DetectBorder 'auto')
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -ChangeSize '1920:-2')
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5')
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -DetectBorder $true)
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'h264_nvenc' -VideoLevel '5' -Qmin 1 -Qmax 23)
        )}
    )
}

function Get-CvVideoEncoders {
    <#
        Catalogo de encoders de video para el menu del perfil custom (ENCODER DE VIDEO). Lista
        ordenada de @{ Value; Text }: el numero de menu (1..N) lo genera New-CustomProfile, asi que
        anadir/quitar/reordenar aqui basta. Value = valor de -VideoEncoder; Text = descripcion.
    #>
    @(
        @{ Value = 'copy';       Text = 'Copia la pista de video sin recodificar' }
        @{ Value = 'libx264';    Text = '[h264 - CPU]  muy compatible, mas lento' }
        @{ Value = 'h264_nvenc'; Text = '[h264 - GPU]  rapido (GPU NVIDIA)' }
        @{ Value = 'libx265';    Text = '[h265 - CPU]  mejor compresion, mas lento' }
        @{ Value = 'hevc_nvenc'; Text = '[h265 - GPU]  rapido (GPU NVIDIA)' }
    )
}

function Get-CvVideoSizes {
    <#
        Catalogo de tamanos de referencia para el menu de resize del perfil custom. Lista de
        @{ Value; Text } (formato comun): Value = tamano 'W:H' para -ChangeSize; Text = descripcion.
        Solo informativo: el usuario teclea el tamano; anadir/quitar filas aqui basta.
    #>
    @(
        @{ Value = '640:360';   Text = '360p  [Mobile]' }
        @{ Value = '1024:576';  Text = '576p  [PAL Widescreen]' }
        @{ Value = '1280:720';  Text = '720p  [HD]' }
        @{ Value = '1920:1080'; Text = '1080p [Full HD]' }
        @{ Value = '1920:-2';   Text = '1080p [Full HD] (mantiene aspect ratio)' }
        @{ Value = '3840:2160'; Text = '4K    [UHDTV]' }
    )
}

function Get-CvCodecOptions {
    <#
        Perfiles (-profile:v) y levels (-level:v) validos segun la familia del codec, con una
        descripcion por opcion para el menu. H.265 (libx265/hevc_nvenc) y H.264 (libx264/h264_nvenc)
        admiten valores distintos.

        OJO fuente: la doc de ffmpeg NO describe estos valores (-profile remite a "x264 --fullhelp"
        y -level a "Annex A"). Las descripciones salen del ESTANDAR del codec (H.264/HEVC); las de
        level son APROXIMADAS (marcadas con '~': tope tipico de resolucion/fps del nivel).
        Devuelve @{ Profiles; Levels }, cada una lista de @{ Value; Text } (formato comun).
    #>
    param([string]$Encoder)
    if ($Encoder -in @('libx265','hevc_nvenc')) {
        [pscustomobject]@{
            Profiles = @(
                @{ Value = 'main';   Text = '8 bits' }
                @{ Value = 'main10'; Text = '10 bits (mas color, menos banding)' }
            )
            Levels = @(
                @{ Value = '4.0'; Text = '~1080p30' }
                @{ Value = '4.1'; Text = '~1080p60' }
                @{ Value = '5.0'; Text = '~4K30' }
                @{ Value = '5.1'; Text = '~4K60' }
                @{ Value = '5.2'; Text = '~4K120 / 8K limitado' }
                @{ Value = '6.0'; Text = '~8K30' }
                @{ Value = '6.1'; Text = '~8K60' }
                @{ Value = '6.2'; Text = '~8K120' }
            )
        }
    } else {
        [pscustomobject]@{
            Profiles = @(
                @{ Value = 'baseline'; Text = 'basico, sin B-frames (dispositivos antiguos)' }
                @{ Value = 'main';     Text = 'estandar (SD/broadcast)' }
                @{ Value = 'high';     Text = '8 bits, el habitual en HD' }
                @{ Value = 'high10';   Text = '10 bits' }
            )
            Levels = @(
                @{ Value = '3.0'; Text = '~480p (SD)' }
                @{ Value = '3.1'; Text = '~720p30' }
                @{ Value = '4.0'; Text = '~1080p30' }
                @{ Value = '4.1'; Text = '~1080p30 (Blu-ray)' }
                @{ Value = '4.2'; Text = '~1080p60' }
                @{ Value = '5.0'; Text = '~1080p72 / 2K' }
                @{ Value = '5.1'; Text = '~4K30' }
            )
        }
    }
}

function Get-CvAudioBitrates {
    <#
        Catalogo de bitrates del menu del perfil custom, APROPIADO AL CODEC (-Codec). Lista
        @{ Value; Text } (+ 'Position' opcional): sin Position -> preset numerado en orden;
        'end' -> siempre la ultima ('custom', bitrate a mano). Para AC-3/E-AC-3 se ofrecen
        bitrates de sonido envolvente (hasta 640k, el maximo de AC-3); para el resto (AAC/MP3/Opus),
        el rango estereo/lossy habitual. FLAC no llama aqui (es sin perdida). Descripciones =
        orientativas (no de la doc de ffmpeg). El menu se muestra DESPUES de elegir el codec.
    #>
    param([string]$Codec = 'aac')
    if ("$Codec".ToLower() -in @('ac3','eac3')) {
        @(
            @{ Value = '192k';   Text = 'estereo / 5.1 basico' }
            @{ Value = '256k';   Text = '5.1 buena' }
            @{ Value = '384k';   Text = '5.1 alta (recomendado)' }
            @{ Value = '448k';   Text = '5.1 muy alta' }
            @{ Value = '640k';   Text = 'maxima de AC-3' }
            @{ Value = 'custom'; Text = 'introducir un bitrate a mano (p. ej. 768k)'; Position = 'end' }
        )
    } else {
        @(
            @{ Value = '96k';    Text = 'estereo bajo' }
            @{ Value = '128k';   Text = 'estereo basico' }
            @{ Value = '160k';   Text = 'estereo bueno' }
            @{ Value = '192k';   Text = 'estereo alta calidad (recomendado)' }
            @{ Value = '256k';   Text = 'muy alta' }
            @{ Value = '320k';   Text = 'maxima habitual' }
            @{ Value = 'custom'; Text = 'introducir un bitrate a mano (p. ej. 224k)'; Position = 'end' }
        )
    }
}

function Get-CvAudioCodecs {
    <#
        Catalogo de la SALIDA de audio del perfil custom: 'copy' (no recodificar) + codecs a los que
        recodificar. Lista @{ Value; Short; Text }: Value = 'copy' o el codec de ffmpeg (-c:a).
        Al recodificar, el intermedio va en '.m4a' para AAC (compatible con la normalizacion aacgain)
        y en '.mka' (Matroska) para el resto, que luego se remultiplexa igual al MKV final. 'aac' es
        el codec por defecto. Notas: FLAC es sin perdida (se salta el bitrate); Opus fuerza 48 kHz.
        Short = nombre corto para la etiqueta compacta del perfil (Format-CvProfileLabel); asi el
        nombre "bonito" (p. ej. libmp3lame -> MP3) se define UNA sola vez, aqui.
    #>
    @(
        @{ Value = 'copy';       Short = 'COPY'; Text = 'copiar la pista original (sin recodificar)' }
        @{ Value = 'aac';        Short = 'AAC';  Text = 'AAC-LC  - muy compatible (por defecto)' }
        @{ Value = 'ac3';        Short = 'AC3';  Text = 'Dolby Digital (AC-3)  - 5.1 compatible con TV/receptores' }
        @{ Value = 'eac3';       Short = 'EAC3'; Text = 'Dolby Digital Plus (E-AC-3)  - mejor que AC-3 a igual bitrate' }
        @{ Value = 'libmp3lame'; Short = 'MP3';  Text = 'MP3  - universal, con perdida' }
        @{ Value = 'flac';       Short = 'FLAC'; Text = 'FLAC  - sin perdida (ignora el bitrate)' }
        @{ Value = 'libopus';    Short = 'OPUS'; Text = 'Opus  - muy eficiente (fuerza 48 kHz)' }
    )
}

function Get-CvNvencMultipass {
    <#
        Catalogo del 2-pass de NVENC (-multipass) para el menu del perfil custom. Lista de
        @{ Value; Text } (formato comun) con off/qres/fullres. Descripciones tomadas de ffmpeg
        (-h encoder=hevc_nvenc): la parte de resolucion es literal; el resto es la consecuencia
        practica (mas pasadas = mas calidad y mas tiempo). 'off' se usa como opcion 0 en el menu.
    #>
    @(
        @{ Value = 'off';     Text = 'sin 2-pass (1 sola pasada, lo mas rapido)'; Position = 'first' }
        @{ Value = 'qres';    Text = '2 pasadas, la 1a a 1/4 de resolucion (mejora calidad; algo mas lento)' }
        @{ Value = 'fullres'; Text = '2 pasadas, la 1a a resolucion completa (mejor calidad; el mas lento)' }
    )
}

function Get-CvProfileProp($obj, [string]$key, $default) {
    <# Valor de una propiedad del objeto de perfil de config, o $default si falta / es null. #>
    if ($null -eq $obj) { return $default }
    $p = $obj.PSObject.Properties[$key]
    if ($p -and $null -ne $p.Value) { return $p.Value }
    return $default
}

function ConvertTo-CvProfile {
    <# Convierte un objeto de perfil de config.json (camelCase) en un perfil (New-CvProfile). #>
    param([Parameter(Mandatory)]$Obj)
    New-CvProfile `
        -VideoEncoder "$(Get-CvProfileProp $Obj 'videoEncoder' '')" `
        -VideoProfile "$(Get-CvProfileProp $Obj 'videoProfile' '')" `
        -VideoLevel   "$(Get-CvProfileProp $Obj 'videoLevel' '')" `
        -Qmin (Get-CvProfileProp $Obj 'qmin' $null) `
        -Qmax (Get-CvProfileProp $Obj 'qmax' $null) `
        -Crf  (Get-CvProfileProp $Obj 'crf'  $null) `
        -DetectBorder $(if ("$(Get-CvProfileProp $Obj 'detectBorder' $false)".ToLower() -eq 'auto') { 'auto' } else { [bool](Get-CvProfileProp $Obj 'detectBorder' $false) }) `
        -ChangeSize   "$(Get-CvProfileProp $Obj 'changeSize' '')" `
        -MaxWidth     (Get-CvProfileProp $Obj 'maxWidth' $null) `
        -Multipass    "$(Get-CvProfileProp $Obj 'multipass' '')" `
        -AudioEncoder "$(Get-CvProfileProp $Obj 'audioEncoder' 'aac_coder')" `
        -AudioCodec   "$(Get-CvProfileProp $Obj 'audioCodec' 'aac')" `
        -AudioBitrate "$(Get-CvProfileProp $Obj 'audioBitrate' '192k')" `
        -AudioHz ([int](Get-CvProfileProp $Obj 'audioHz' 44100)) `
        -AudioChannels (Get-CvProfileProp $Obj 'audioChannels' $null) `
        -DownmixMode   (Get-CvProfileProp $Obj 'downmixMode' $null) `
        -DownmixCoeffs (ConvertTo-CvDownmixCoeffs (Get-CvProfileProp $Obj 'downmixCoeffs' $null))
}

function Format-CvProfileLabel {
    <#
        Etiqueta compacta de un perfil para el menu (estilo 'A: 192K, V: h265[NV]/M10/L5/Q(1-23)').
        FUENTE UNICA: la usan tanto los perfiles de serie (Select-Profile) como los propios de
        config.json, para no duplicar la lista del menu y que siempre refleje los valores reales.
    #>
    param([Parameter(Mandatory)]$Prof)
    $encMap = @{ 'hevc_nvenc' = 'h265[NV]'; 'h264_nvenc' = 'h264[NV]'; 'libx265' = 'h265'; 'libx264' = 'h264' }
    $profMap = @{ 'main10' = 'M10'; 'main' = 'M' }
    if ($Prof.VideoEncoder -eq 'copy' -or -not $Prof.VideoEncoder) {
        $v = 'COPY'
    } else {
        $enc = $encMap["$($Prof.VideoEncoder)"]; if (-not $enc) { $enc = "$($Prof.VideoEncoder)".ToUpper() }
        $parts = @($enc)
        if ($Prof.VideoProfile) {
            $pm = $profMap["$($Prof.VideoProfile)"]; if (-not $pm) { $pm = "$($Prof.VideoProfile)" }
            $parts += $pm
        }
        if ($Prof.VideoLevel) { $parts += ('L{0}' -f $Prof.VideoLevel) }
        # Control de tasa: CRF (CPU) / Q(min-max) (NVENC) / Q(AUTO) (NVENC sin qmin ni qmax).
        $isCpu = ($Prof.VideoEncoder -in @('libx264','libx265'))
        if ($null -ne $Prof.Crf) { $parts += ('CRF{0}' -f $Prof.Crf) }
        elseif (($null -ne $Prof.Qmin) -or ($null -ne $Prof.Qmax)) { $parts += ('Q({0}-{1})' -f $Prof.Qmin, $Prof.Qmax) }
        elseif (-not $isCpu) { $parts += 'Q(AUTO)' }
        if ("$($Prof.Multipass)" -in @('qres','fullres')) { $parts += ('2PASS:{0}' -f $Prof.Multipass) }
        if ("$($Prof.DetectBorder)".ToLower() -eq 'auto') { $parts += 'AUTO-BORDE' }
        elseif ([bool]$Prof.DetectBorder)                 { $parts += 'DETECT BORDE' }
        if ($Prof.ChangeSize)   { $parts += ('RESIZE {0}' -f $Prof.ChangeSize) }
        if ($null -ne $Prof.MaxWidth -and [int]$Prof.MaxWidth -gt 0) { $parts += ('RESIZE<={0}w' -f [int]$Prof.MaxWidth) }
        $v = ($parts -join '/')
    }
    if ($Prof.AudioEncoder -eq 'copy') {
        $a = 'COPY'
    } else {
        # Codec solo si no es el AAC por defecto (AAC 192K queda como '192K'; AC3/EAC3/... se muestran).
        # El nombre corto sale del catalogo Get-CvAudioCodecs (columna Short), fuente unica.
        $codec = "$($Prof.AudioCodec)"; if (-not $codec) { $codec = 'aac' }
        $ac = ''
        if ($codec -ne 'aac') {
            $e = @(Get-CvAudioCodecs | Where-Object { $_.Value -eq $codec })[0]
            $short = if ($e -and $e.Short) { "$($e.Short)" } else { "$codec".ToUpper() }
            $ac = "$short "
        }
        $a = '{0}{1}' -f $ac, "$($Prof.AudioBitrate)".ToUpper()
    }
    # Overrides de salida de audio del perfil: canales (si != estereo) y downmix con voz reforzada.
    if ($null -ne $Prof.AudioChannels -and [int]$Prof.AudioChannels -ge 1 -and [int]$Prof.AudioChannels -ne 2) { $a += (' {0}CH' -f [int]$Prof.AudioChannels) }
    if ("$($Prof.DownmixMode)".ToLower() -eq 'dialogue') { $a += ' DLG' }
    ('A: {0}, V: {1}' -f $a, $v)
}

function New-CustomProfile {
    <#
        Construye un perfil de forma interactiva. En CUALQUIER pregunta, escribir 'C' o
        pulsar ESC cancela y vuelve al menu de perfiles. Al final permite [R]ehacer.
        Devuelve el perfil, o $null si se cancela.
    #>
    param($Context = $null)
    # Valores por defecto: del contexto (config 'customProfile'); si no hay contexto, de los defaults
    # de config (Get-CvConfigDefaults, fuente unica) en vez de literales hardcodeados aqui.
    $dflt = Get-CvConfigDefaults; $cp = $dflt.customProfile
    $defEnc  = if ($Context -and "$($Context.CustomVideoEncoder)" -ne '') { "$($Context.CustomVideoEncoder)" } else { "$($cp.videoEncoder)" }
    $defProf = if ($Context -and "$($Context.CustomVideoProfile)" -ne '') { "$($Context.CustomVideoProfile)" } else { "$($cp.videoProfile)" }
    $defLvl  = if ($Context -and "$($Context.CustomVideoLevel)"   -ne '') { "$($Context.CustomVideoLevel)"   } else { "$($cp.videoLevel)" }
    # Si hay contexto se usa su valor TAL CUAL (puede ser $null = "auto"); sin contexto, el default de config.
    $defQmin = if ($Context) { $Context.CustomQmin } else { [int]$cp.qmin }
    $defQmax = if ($Context) { $Context.CustomQmax } else { [int]$cp.qmax }
    $defCrf  = if ($Context) { $Context.CustomCrf }  else { [int]$cp.crf }
    $defMp    = if ($Context -and "$($Context.CustomMultipass)" -ne '') { "$($Context.CustomMultipass)" } else { "$($cp.multipass)" }
    $defAb    = if ($Context -and "$($Context.CustomAudioBitrate)" -ne '') { "$($Context.CustomAudioBitrate)" } else { "$($cp.audioBitrate)" }
    $defCodec = if ($Context -and "$($Context.CustomAudioCodec)" -ne '') { "$($Context.CustomAudioCodec)" } else { "$($cp.audioCodec)" }

    while ($true) {
        try {
            # Encoder: menu generico (Select-FromList) sin opcion "0" (-NoNone). El default es el
            # encoder configurado; si no esta en la lista (config erronea), cae a hevc_nvenc y, si
            # ni eso, a la 1a opcion.
            $encList = @(Get-CvVideoEncoders)
            $encVals = @($encList | ForEach-Object { "$($_.Value)" })
            $encDefIdx = 1 + [array]::IndexOf($encVals, "$defEnc")
            if ($encDefIdx -le 0) { $encDefIdx = 1 + [array]::IndexOf($encVals, 'hevc_nvenc') }
            if ($encDefIdx -le 0) { $encDefIdx = 1 }
            $enc = Select-FromList -Title 'ENCODER DE VIDEO:' -Options $encList -NoNone -DefaultIndex $encDefIdx `
                -CancelLabel 'C / ESC. Cancelar (volver al menu de perfiles)' -AllowCancel

            $p = New-CvProfile -VideoEncoder $enc

            if ($enc -ne 'copy') {
                $p.DetectBorder = Read-YesNo '   Detectar bordes negros en cada archivo?' $false -AllowCancel

                if (Read-YesNo '   Cambiar el tamano del video?' $false -AllowCancel) {
                    $sizeLines = @(Get-CvVideoSizes | ForEach-Object { '{0,-24}- {1}' -f $_.Text, $_.Value })
                    Show-Menu -Title 'TAMANOS DE REFERENCIA:' -Lines ($sizeLines + @(
                        '',
                        'Altura -2 = automatica manteniendo aspecto y PAR (ej 1920:-2)',
                        '',
                        'C / ESC. Cancelar'
                    ))
                    $sz = (Read-CvLine -Prompt '   Nuevo tamano (ej 1920:-2, 1280:720) [C/ESC = cancelar]' -AllowCancel).Trim()
                    if ($sz -match '^[Cc]$') { throw 'CV_CANCEL' }
                    if ($sz -ne '') {
                        # Si solo dan el ancho, se completa con ':-2' (no ':-1'): -2 mantiene el aspecto
                        # y ademas fuerza altura PAR, requisito de 4:2:0 (con -1 podria salir impar y
                        # fallar la codificacion en CPU: libx264/libx265).
                        if ($sz -notmatch ':') { $sz = "$sz`:-2" }
                        $p.ChangeSize = $sz
                    }
                }

                # Perfil y level validos segun el codec (catalogo @{Value;Text} en Get-CvCodecOptions).
                $co       = Get-CvCodecOptions -Encoder $enc
                $profOpts = @($co.Profiles)
                $lvlOpts  = @($co.Levels)
                # Indice 1-based del valor por defecto. Perfil y level son OBLIGATORIOS (-NoNone): si
                # el default de config no aplica al codec, caen a la 1a opcion (nunca a "ninguno").
                $profDefIdx = 1 + [array]::IndexOf(@($profOpts | ForEach-Object { "$($_.Value)" }), "$defProf")
                if ($profDefIdx -le 0) { $profDefIdx = 1 }
                $lvlDefIdx  = 1 + [array]::IndexOf(@($lvlOpts  | ForEach-Object { "$($_.Value)" }), "$defLvl")
                if ($lvlDefIdx -le 0) { $lvlDefIdx = 1 }
                $p.VideoProfile = Select-FromList -Title 'Perfil de codec:' -Options $profOpts -NoNone -DefaultIndex $profDefIdx -AllowCancel
                $p.VideoLevel   = Select-FromList -Title 'Level (resolucion/fps orientativos):' -Options $lvlOpts -NoNone -DefaultIndex $lvlDefIdx -AllowCancel

                # Control de tasa: CRF (CPU) o qmin/qmax (NVENC). Defaults desde config (customProfile).
                if ($enc -in @('libx264','libx265')) {
                    $p.Crf = Read-QOrNull '   CRF (calidad 0-51)' $defCrf -Max 51 -AllowCancel
                } else {
                    $p.Qmin = Read-QOrNull '   QP minimo (0-51)' $defQmin -Max 51 -AllowCancel
                    $p.Qmax = Read-QOrNull '   QP maximo (0-51)' $defQmax -Max 51 -AllowCancel
                    # 2-pass NVENC (multipass): catalogo @{Value;Text} en Get-CvNvencMultipass. Solo
                    # NVENC. 'off' es la opcion 0 (None); qres/fullres van como opciones normales.
                    # Catalogo @{Value;Text;Position} ('off'=first/opcion 0). Default por valor.
                    $p.Multipass = Select-FromList -Title '2-pass NVENC (multipass):' `
                        -Options (Get-CvNvencMultipass) -DefaultValue "$defMp" -AllowCancel
                }
            }

            # AUDIO en dos pasos: 1) SALIDA = copy (no recodificar) o codec (Get-CvAudioCodecs); luego,
            # solo al recodificar, 2) BITRATE apropiado al codec (Get-CvAudioBitrates -Codec). FLAC (sin
            # perdida) y copy se saltan el bitrate. El default de salida = 'copy' si customProfile.audioBitrate
            # es 'copy' (compatibilidad), si no el codec por defecto (customProfile.audioCodec).
            $defOut = if ("$defAb" -eq 'copy') { 'copy' } else { "$defCodec" }
            $out = Select-FromList -Title 'SALIDA DE AUDIO (codec):' -Options (Get-CvAudioCodecs) -NoNone -DefaultValue "$defOut" -AllowCancel
            if ($out -eq 'copy') {
                $p.AudioEncoder = 'copy'; $p.AudioCodec = 'aac'; $p.AudioBitrate = ''
            } else {
                $p.AudioEncoder = 'aac_coder'; $p.AudioCodec = $out
                if ($out -eq 'flac') {
                    $p.AudioBitrate = ''    # sin perdida: el bitrate no aplica
                } else {
                    while ($true) {
                        $ab = Select-FromList -Title 'BITRATE DE AUDIO:' -Options (Get-CvAudioBitrates -Codec $out) -NoNone -DefaultValue "$defAb" -AllowCancel
                        if ($ab -eq 'custom') {
                            $cb = (Read-CvLine -Prompt '   Bitrate (ej 96k, 448k)' -AllowCancel).Trim()
                            if ($cb -match '^[Cc]$') { throw 'CV_CANCEL' }
                            if ($cb -ne '') { $p.AudioBitrate = $cb; break }
                            continue   # vacio -> volver a mostrar el menu
                        }
                        $p.AudioBitrate = $ab; break
                    }
                }
                # Canales de salida (override del global encode.audioChannels). Default = el global.
                $defCh = if ($Context -and [int]$Context.AudioChannels -ge 1) { [int]$Context.AudioChannels } else { [int]$dflt.encode.audioChannels }
                $chSel = Select-FromList -Title 'CANALES DE SALIDA:' -Options (Get-CvAudioChannels) -NoNone -DefaultValue "$defCh" -AllowCancel
                $p.AudioChannels = [int]$chSel
                # Downmix SOLO si la salida es estereo (2): solo entonces se baja 5.1 -> estereo.
                if ([int]$chSel -eq 2) {
                    $defDm = if ($Context -and "$($Context.DownmixMode)" -ne '') { "$($Context.DownmixMode)" } else { "$($dflt.encode.downmixMode)" }
                    $p.DownmixMode = Select-FromList -Title 'DOWNMIX 5.1 -> estereo:' -Options (Get-CvDownmixModes) -NoNone -DefaultValue "$defDm" -AllowCancel
                }
            }

            # Resumen y confirmacion.
            Write-ProfileInfo -Prof $p
            $conf = (Read-CvLine -Prompt '[ENTER] usar esta config / [R] rehacer / [C o ESC] cancelar' -AllowCancel).Trim()
            if ($conf -match '^[Rr]$') { continue }
            return $p
        }
        catch {
            if ("$($_.Exception.Message)" -eq 'CV_CANCEL') { return $null }
            throw
        }
    }
}

function Select-Profile {
    <#
        Muestra el menu y devuelve el perfil elegido, o $null si el usuario elige salir (X).
        -Extra: perfiles PROPIOS de config.json (seccion 'profiles'); se ANADEN despues de los de
        serie (numeracion continua, 12, 13, ...) sin sustituirlos.
    #>
    param([object[]]$Extra = @(), $Context = $null)
    # Perfiles de serie por GRUPOS; se numeran automaticamente 1..N (continuo entre grupos) y el
    # texto del menu se GENERA de sus valores (Format-CvProfileLabel). Entre grupos, linea en blanco.
    $groups   = @(Get-CvProfiles)
    $profiles = [ordered]@{}
    $baseLines = @()
    $n = 0
    for ($g = 0; $g -lt $groups.Count; $g++) {
        if ($g -gt 0) { $baseLines += '' }                       # separador entre grupos
        foreach ($pr in @($groups[$g].Profiles)) {
            $n++
            $profiles["$n"] = $pr
            $baseLines += ('{0}. {1}' -f $n, (Format-CvProfileLabel -Prof $pr))
        }
    }
    # Perfiles propios de config.json: CONTINUAN la numeracion (N+1, N+2, ...); etiqueta = 'label' o resumen.
    $extraLines = @()
    $base = $n
    for ($i = 0; $i -lt @($Extra).Count; $i++) {
        $obj = @($Extra)[$i]
        if ($null -eq $obj) { continue }
        $key = "$($base + $i + 1)"
        $p   = ConvertTo-CvProfile -Obj $obj
        $profiles[$key] = $p
        $lbl = "$(Get-CvProfileProp $obj 'label' '')"
        if ([string]::IsNullOrWhiteSpace($lbl)) { $lbl = Format-CvProfileLabel -Prof $p }
        $extraLines += ('{0}. {1}' -f $key, $lbl)
    }
    $menuLines = @($baseLines)
    if ($extraLines.Count) { $menuLines += @('', '-- Perfiles de config.json --') + $extraLines }
    $menuLines += @('', '0. Custom (configuracion personalizada)', '', 'X. Salir')

    $show = $true
    while ($true) {
        if ($show) {
            Show-Menu -Title 'USAR PERFIL:' -Lines $menuLines
            $show = $false
        }
        $sel = (Read-Host '[GLOBAL] - [PROFILE] - OPCION NUMERO (X = salir)').Trim()
        if ($sel -match '^[Xx]$') { return $null }                 # salir
        if ($sel -eq '0') {
            $custom = New-CustomProfile -Context $Context
            if ($null -ne $custom) { return $custom }
            Clear-Host                                             # custom cancelado -> limpiar y re-mostrar
            $show = $true
            continue
        }
        if ($profiles.Contains($sel)) { return $profiles[$sel] }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }
}

function Write-ProfileInfo {
    param([Parameter(Mandatory)]$Prof)
    Write-Host ''
    Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - ENCODER: {0}" -f $Prof.VideoEncoder.ToUpper())
    if ($Prof.VideoEncoder -ne 'copy') {
        if ($Prof.VideoProfile) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - PROFILE: {0}" -f $Prof.VideoProfile) }
        if ($Prof.VideoLevel)   { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - LEVEL:   {0}" -f $Prof.VideoLevel) }
        if ($null -ne $Prof.Qmin) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - QMIN:    {0}" -f $Prof.Qmin) }
        if ($null -ne $Prof.Qmax) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - QMAX:    {0}" -f $Prof.Qmax) }
        if ($null -ne $Prof.Crf)  { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - CRF:     {0}" -f $Prof.Crf) }
        $dbTxt = if ("$($Prof.DetectBorder)".ToLower() -eq 'auto') { 'auto' } elseif ([bool]$Prof.DetectBorder) { 'si' } else { 'no' }
        Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - DETECTAR BORDE: {0}" -f $dbTxt)
        if ($Prof.ChangeSize) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - RESIZE: {0}" -f $Prof.ChangeSize) }
        if ($null -ne $Prof.MaxWidth -and [int]$Prof.MaxWidth -gt 0) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - RESIZE: <= {0}px de ancho (solo si es mayor)" -f [int]$Prof.MaxWidth) }
    }
    if ($Prof.AudioEncoder -eq 'copy') {
        Write-CvLog 'GLOBAL' '[INFO] - [AUDIO] - ENCODER: copy (sin recodificar)'
    } else {
        $codec = "$($Prof.AudioCodec)"; if (-not $codec) { $codec = 'aac' }
        Write-CvLog 'GLOBAL' ("[INFO] - [AUDIO] - CODEC: {0} / {1}" -f $codec, $Prof.AudioBitrate)
        # Overrides de salida del perfil (si no, se usa el global encode.*).
        if ($null -ne $Prof.AudioChannels -and [int]$Prof.AudioChannels -ge 1) {
            Write-CvLog 'GLOBAL' ("[INFO] - [AUDIO] - CANALES: {0}" -f [int]$Prof.AudioChannels)
        }
        if ($Prof.DownmixMode) {
            Write-CvLog 'GLOBAL' ("[INFO] - [AUDIO] - DOWNMIX 5.1->estereo: {0}" -f "$($Prof.DownmixMode)".ToLower())
        }
    }
    Write-Host ''
}

Export-ModuleMember -Function *
