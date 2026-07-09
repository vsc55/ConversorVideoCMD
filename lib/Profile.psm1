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
        [bool]$DetectBorder = $false,
        [string]$ChangeSize = '',      # '' = no | '1920:-1' etc.
        [string]$AudioEncoder = 'aac_coder',  # aac_coder | copy
        [string]$AudioBitrate = '192k',
        [int]$AudioHz = 44100
    )
    [pscustomobject]@{
        VideoEncoder = $VideoEncoder; VideoProfile = $VideoProfile; VideoLevel = $VideoLevel
        Qmin = $Qmin; Qmax = $Qmax; Crf = $Crf; DetectBorder = $DetectBorder; ChangeSize = $ChangeSize
        AudioEncoder = $AudioEncoder; AudioBitrate = $AudioBitrate; AudioHz = $AudioHz
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
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5')
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -DetectBorder $true)
        )}
        [pscustomobject]@{ Profiles = @(
            (New-CvProfile -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -ChangeSize '1920:-1')
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
        @{ Value = 'libx264';    Text = '[h264 - CPU]' }
        @{ Value = 'h264_nvenc'; Text = '[h264 - GPU]' }
        @{ Value = 'libx265';    Text = '[h265 - CPU]' }
        @{ Value = 'hevc_nvenc'; Text = '[h265 - GPU]' }
        @{ Value = 'copy';       Text = '' }
    )
}

function Get-CvVideoSizes {
    <#
        Catalogo de tamanos de referencia para el menu de resize del perfil custom.
        Lista de @{ Label; Size } (Size = valor de -ChangeSize 'W:H'). Solo informativo: el usuario
        teclea el tamano; anadir/quitar filas aqui basta.
    #>
    @(
        @{ Label = '360p  [Mobile]';         Size = '640:360'   }
        @{ Label = '576p  [PAL Widescreen]'; Size = '1024:576'  }
        @{ Label = '720p  [HD]';             Size = '1280:720'  }
        @{ Label = '1080p [Full HD]';        Size = '1920:1080' }
        @{ Label = '4K    [UHDTV]';          Size = '3840:2160' }
    )
}

function Get-CvCodecOptions {
    <#
        Perfiles (-profile:v) y levels (-level:v) validos segun la familia del codec.
        H.265 (libx265/hevc_nvenc) y H.264 (libx264/h264_nvenc) admiten valores distintos.
        Devuelve @{ Profiles = @(...); Levels = @(...) }.
    #>
    param([string]$Encoder)
    if ($Encoder -in @('libx265','hevc_nvenc')) {
        [pscustomobject]@{
            Profiles = @('main','main10')
            Levels   = @('4.0','4.1','5.0','5.1','5.2','6.0','6.1','6.2')
        }
    } else {
        [pscustomobject]@{
            Profiles = @('baseline','main','high','high10')
            Levels   = @('3.0','3.1','4.0','4.1','4.2','5.0','5.1')
        }
    }
}

function Get-CvAudioBitrates {
    <# Catalogo de bitrates de audio (AAC) preseleccionables en el menu del perfil custom. #>
    @('128k','160k','192k','256k','320k')
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
        -DetectBorder ([bool](Get-CvProfileProp $Obj 'detectBorder' $false)) `
        -ChangeSize   "$(Get-CvProfileProp $Obj 'changeSize' '')" `
        -AudioEncoder "$(Get-CvProfileProp $Obj 'audioEncoder' 'aac_coder')" `
        -AudioBitrate "$(Get-CvProfileProp $Obj 'audioBitrate' '192k')" `
        -AudioHz ([int](Get-CvProfileProp $Obj 'audioHz' 44100))
}

function Format-CvProfileLabel {
    <#
        Etiqueta compacta de un perfil para el menu (estilo 'A: 192K, V: h265[NV]/M10/L5/Q(1-23)').
        FUENTE UNICA: la usan tanto los 7 perfiles de serie (Select-Profile) como los propios de
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
        if ($Prof.DetectBorder) { $parts += 'DETECT BORDE' }
        if ($Prof.ChangeSize)   { $parts += ('RESIZE {0}' -f $Prof.ChangeSize) }
        $v = ($parts -join '/')
    }
    $a = if ($Prof.AudioEncoder -eq 'copy') { 'COPY' } else { "$($Prof.AudioBitrate)".ToUpper() }
    ('A: {0}, V: {1}' -f $a, $v)
}

function New-CustomProfile {
    <#
        Construye un perfil de forma interactiva. En CUALQUIER pregunta, escribir 'C' o
        pulsar ESC cancela y vuelve al menu de perfiles. Al final permite [R]ehacer.
        Devuelve el perfil, o $null si se cancela.
    #>
    param($Context = $null)
    # Valores por defecto (config 'customProfile' via contexto; fallback si no hay contexto).
    $defEnc  = if ($Context -and "$($Context.CustomVideoEncoder)" -ne '') { "$($Context.CustomVideoEncoder)" } else { 'hevc_nvenc' }
    $defProf = if ($Context -and "$($Context.CustomVideoProfile)" -ne '') { "$($Context.CustomVideoProfile)" } else { 'main10' }
    $defLvl  = if ($Context -and "$($Context.CustomVideoLevel)"   -ne '') { "$($Context.CustomVideoLevel)"   } else { '5.0' }
    # Si hay contexto se usa su valor TAL CUAL (puede ser $null = "auto"); sin contexto, el hardcodeado.
    $defQmin = if ($Context) { $Context.CustomQmin } else { 1 }
    $defQmax = if ($Context) { $Context.CustomQmax } else { 23 }
    $defCrf  = if ($Context) { $Context.CustomCrf }  else { 21 }
    $defAb   = if ($Context -and "$($Context.CustomAudioBitrate)" -ne '') { "$($Context.CustomAudioBitrate)" } else { '192k' }

    while ($true) {
        try {
            # Catalogo de encoders (Get-CvVideoEncoders); el numero de menu (1..N) se genera solo.
            $encList = @(Get-CvVideoEncoders)
            $encoders = [ordered]@{}
            for ($i = 0; $i -lt $encList.Count; $i++) { $encoders["$($i + 1)"] = $encList[$i] }
            # Clave por defecto = la del encoder configurado. Si el valor no esta en la lista
            # (config erronea), se cae al encoder por defecto de la app (hevc_nvenc), no a la 1a
            # opcion; y solo si ni eso existe, a la primera de la lista.
            $encDefKey = ''
            foreach ($ek in $encoders.Keys) { if ((Get-CvOptionValue $encoders $ek) -eq $defEnc)        { $encDefKey = $ek; break } }
            if (-not $encDefKey) { foreach ($ek in $encoders.Keys) { if ((Get-CvOptionValue $encoders $ek) -eq 'hevc_nvenc') { $encDefKey = $ek; break } } }
            if (-not $encDefKey) { $encDefKey = @($encoders.Keys)[0] }
            $encLines = @(Get-CvMenuLines $encoders) | ForEach-Object {
                if ($_ -match ("^{0}\. " -f $encDefKey)) { "$_  <= por defecto" } else { $_ }
            }
            Show-Menu -Title 'ENCODER DE VIDEO:' -Lines ($encLines + @('', 'C / ESC. Cancelar (volver al menu de perfiles)'))
            $enc = ''
            while ($enc -eq '') {
                $k = (Read-CvLine -Prompt ("   Opcion [{0}]" -f $encDefKey) -AllowCancel).Trim()
                if ($k -match '^[Cc]$') { throw 'CV_CANCEL' }
                if ($k -eq '') { $k = $encDefKey }
                $enc = Get-CvOptionValue $encoders $k
                if (-not $enc) { Write-Host '   Opcion no valida.' -ForegroundColor Yellow }
            }

            $p = New-CvProfile -VideoEncoder $enc

            if ($enc -ne 'copy') {
                $p.DetectBorder = Read-YesNo '   Detectar bordes negros en cada archivo?' $false -AllowCancel

                if (Read-YesNo '   Cambiar el tamano del video?' $false -AllowCancel) {
                    $sizeLines = @(Get-CvVideoSizes | ForEach-Object { '{0,-24}- {1}' -f $_.Label, $_.Size })
                    Show-Menu -Title 'TAMANOS DE REFERENCIA:' -Lines ($sizeLines + @(
                        '',
                        'Altura -1 = automatico manteniendo aspecto (ej 1920:-1)',
                        '',
                        'C / ESC. Cancelar'
                    ))
                    $sz = (Read-CvLine -Prompt '   Nuevo tamano (ej 1920:-1, 1280:720) [C/ESC = cancelar]' -AllowCancel).Trim()
                    if ($sz -match '^[Cc]$') { throw 'CV_CANCEL' }
                    if ($sz -ne '') {
                        if ($sz -notmatch ':') { $sz = "$sz`:-1" }
                        $p.ChangeSize = $sz
                    }
                }

                # Perfil y level validos segun el codec (catalogo en Get-CvCodecOptions).
                $co       = Get-CvCodecOptions -Encoder $enc
                $profOpts = @($co.Profiles)
                $lvlOpts  = @($co.Levels)
                # Indice 1-based del valor por defecto en cada lista (0 = ninguno si no aplica al codec).
                $profDefIdx = 1 + [array]::IndexOf([string[]]$profOpts, "$defProf")
                $lvlDefIdx  = 1 + [array]::IndexOf([string[]]$lvlOpts,  "$defLvl")
                $p.VideoProfile = Select-FromList -Title 'Perfil de codec:' -Options $profOpts -NoneLabel 'ninguno' -DefaultIndex $profDefIdx -AllowCancel
                $p.VideoLevel   = Select-FromList -Title 'Level:' -Options $lvlOpts -NoneLabel 'ninguno' -DefaultIndex $lvlDefIdx -AllowCancel

                # Control de tasa: CRF (CPU) o qmin/qmax (NVENC). Defaults desde config (customProfile).
                if ($enc -in @('libx264','libx265')) {
                    $p.Crf = Read-QOrNull '   CRF (calidad 0-51)' $defCrf -Max 51 -AllowCancel
                } else {
                    $p.Qmin = Read-QOrNull '   QP minimo (0-51)' $defQmin -Max 51 -AllowCancel
                    $p.Qmax = Read-QOrNull '   QP maximo (0-51)' $defQmax -Max 51 -AllowCancel
                }
            }

            # Audio ('0. copy' y '6. custom' son especiales; el resto sale del mapa). Default desde
            # config (customProfile.audioBitrate): ENTER lo usa tal cual, sea preset o valor libre.
            $abList = @(Get-CvAudioBitrates)
            $abMap = [ordered]@{}
            for ($i = 0; $i -lt $abList.Count; $i++) { $abMap["$($i + 1)"] = $abList[$i] }
            $abCustomKey = "$($abList.Count + 1)"   # opcion 'custom' = ultima+1
            $abDefKey = ''
            foreach ($ak in $abMap.Keys) { if ("$($abMap[$ak])" -eq $defAb) { $abDefKey = $ak; break } }
            $abLines = @('0. copy') + (@(Get-CvMenuLines $abMap) | ForEach-Object {
                if ($abDefKey -and $_ -match ("^{0}\. " -f $abDefKey)) { "$_  <= por defecto" } else { $_ }
            }) + @(("{0}. custom" -f $abCustomKey), '', 'C / ESC. Cancelar')
            Show-Menu -Title 'BITRATE DE AUDIO:' -Lines $abLines
            while ($true) {
                $ab = (Read-CvLine -Prompt ("   Opcion [{0}]" -f $defAb) -AllowCancel).Trim()
                if ($ab -match '^[Cc]$') { throw 'CV_CANCEL' }
                if ($ab -eq '') {
                    if ($defAb -eq 'copy') { $p.AudioEncoder = 'copy'; $p.AudioBitrate = '' }
                    else { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = $defAb }
                    break
                }
                if ($ab -eq '0') { $p.AudioEncoder = 'copy'; $p.AudioBitrate = ''; break }
                if ($abMap.Contains($ab)) { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = "$($abMap[$ab])"; break }
                if ($ab -eq $abCustomKey) {
                    $cb = (Read-CvLine -Prompt '   Bitrate (ej 96k, 224k)' -AllowCancel).Trim()
                    if ($cb -match '^[Cc]$') { throw 'CV_CANCEL' }
                    if ($cb -ne '') { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = $cb; break }
                }
                Write-Host '   Opcion no valida.' -ForegroundColor Yellow
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
        -Extra: perfiles PROPIOS de config.json (seccion 'profiles'); se ANADEN como 8, 9, ...
        despues de los 7 de serie (no los sustituyen).
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
        Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - DETECTAR BORDE: {0}" -f $Prof.DetectBorder)
        if ($Prof.ChangeSize) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - RESIZE: {0}" -f $Prof.ChangeSize) }
    }
    Write-CvLog 'GLOBAL' ("[INFO] - [AUDIO] - ENCODER: {0} / {1}" -f $Prof.AudioEncoder, $Prof.AudioBitrate)
    Write-Host ''
}

Export-ModuleMember -Function *
