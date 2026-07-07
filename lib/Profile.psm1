<#
    Profile.psm1 - Perfiles de codificacion predefinidos y menu de seleccion.
    Espejo de select_profile.cmd. Devuelve un objeto de configuracion que se
    congela dentro de cada .job.
#>

function New-CvProfile {
    <# Estructura base de un perfil, con valores por defecto. #>
    param(
        [string]$Name,
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
        Name = $Name; VideoEncoder = $VideoEncoder; VideoProfile = $VideoProfile; VideoLevel = $VideoLevel
        Qmin = $Qmin; Qmax = $Qmax; Crf = $Crf; DetectBorder = $DetectBorder; ChangeSize = $ChangeSize
        AudioEncoder = $AudioEncoder; AudioBitrate = $AudioBitrate; AudioHz = $AudioHz
    }
}

function Get-CvProfiles {
    @{
        '1' = New-CvProfile -Name '1' -VideoEncoder 'copy'
        '2' = New-CvProfile -Name '2' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23
        '3' = New-CvProfile -Name '3' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -DetectBorder $true
        '4' = New-CvProfile -Name '4' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5'
        '5' = New-CvProfile -Name '5' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -DetectBorder $true
        '6' = New-CvProfile -Name '6' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -ChangeSize '1920:-1'
        '7' = New-CvProfile -Name '7' -VideoEncoder 'h264_nvenc' -VideoLevel '5' -Qmin 1 -Qmax 23
    }
}

function New-CustomProfile {
    <# Construye un perfil de forma interactiva (equivale a select_profile_custom.cmd). #>
    $encoders = [ordered]@{ '1'='libx264'; '2'='h264_nvenc'; '3'='libx265'; '4'='hevc_nvenc'; '5'='copy' }
    Show-Menu -Title 'ENCODER DE VIDEO:' -Lines @(
        '1. libx264     [h264 - CPU]',
        '2. h264_nvenc  [h264 - GPU]',
        '3. libx265     [h265 - CPU]',
        '4. hevc_nvenc  [h265 - GPU]',
        '5. copy'
    )
    $enc = ''
    while ($enc -eq '') {
        $k = (Read-Host '   Opcion').Trim()
        if ($encoders.Contains($k)) { $enc = $encoders[$k] } else { Write-Host '   Opcion no valida.' -ForegroundColor Yellow }
    }

    $p = New-CvProfile -Name 'custom' -VideoEncoder $enc

    if ($enc -ne 'copy') {
        $p.DetectBorder = Read-YesNo '   Detectar bordes negros en cada archivo?' $false

        if (Read-YesNo '   Cambiar el tamano del video?' $false) {
            Show-Menu -Title 'TAMANOS DE REFERENCIA:' -Lines @(
                '360p  [Mobile]          - 640:360',
                '576p  [PAL Widescreen]  - 1024:576',
                '720p  [HD]              - 1280:720',
                '1080p [Full HD]         - 1920:1080',
                '4K    [UHDTV]           - 3840:2160',
                '',
                'Altura -1 = automatico manteniendo aspecto (ej 1920:-1)'
            )
            $sz = (Read-Host '   Nuevo tamano (ej 1920:-1, 1280:720)').Trim()
            if ($sz -ne '') {
                if ($sz -notmatch ':') { $sz = "$sz`:-1" }
                $p.ChangeSize = $sz
            }
        }

        # Perfil y level segun el codec (selectores)
        $isH265 = ($enc -in @('libx265','hevc_nvenc'))
        if ($isH265) {
            $profOpts = @('main','main10')
            $lvlOpts  = @('4.0','4.1','5.0','5.1','5.2','6.0','6.1','6.2')
        } else {
            $profOpts = @('baseline','main','high','high10')
            $lvlOpts  = @('3.0','3.1','4.0','4.1','4.2','5.0','5.1')
        }
        $p.VideoProfile = Select-FromList -Title 'Perfil de codec:' -Options $profOpts -NoneLabel 'ninguno'
        $p.VideoLevel   = Select-FromList -Title 'Level:' -Options $lvlOpts -NoneLabel 'ninguno'

        # Control de tasa: CRF (CPU) o qmin/qmax (NVENC)
        if ($enc -in @('libx264','libx265')) {
            $p.Crf = Read-QOrNull '   CRF (0-51)' 21
        } else {
            $p.Qmin = Read-QOrNull '   QMIN (0-51)' 1
            $p.Qmax = Read-QOrNull '   QMAX (0-51)' 23
        }
    }

    # Audio
    Show-Menu -Title 'BITRATE DE AUDIO:' -Lines @(
        '0. copy',
        '1. 128k',
        '2. 160k',
        '3. 192k',
        '4. 256k',
        '5. 320k',
        '6. custom'
    )
    $abMap = @{ '1'='128k'; '2'='160k'; '3'='192k'; '4'='256k'; '5'='320k' }
    while ($true) {
        $ab = (Read-Host '   Opcion [3]').Trim()
        if ($ab -eq '') { $ab = '3' }
        if ($ab -eq '0') { $p.AudioEncoder = 'copy'; $p.AudioBitrate = ''; break }
        if ($abMap.ContainsKey($ab)) { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = $abMap[$ab]; break }
        if ($ab -eq '6') {
            $c = (Read-Host '   Bitrate (ej 96k, 224k)').Trim()
            if ($c -ne '') { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = $c; break }
        }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }

    return $p
}

function Select-Profile {
    <# Muestra el menu y devuelve el perfil elegido (o $null si se aborta). #>
    Show-Menu -Title 'USAR PERFIL:' -Lines @(
        '1. A: 192K, V: COPY',
        '2. A: 192K, V: h265[NV]/M10/L5/Q(1-23)',
        '3. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/DETECT BORDE',
        '4. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)',
        '5. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)/DETECT BORDE',
        '6. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/RESIZE 1080P',
        '7. A: 192K, V: h264[NV]/L5/Q(1-23)',
        '',
        '0. Custom (configuracion personalizada)'
    )

    $profiles = Get-CvProfiles
    while ($true) {
        $sel = (Read-Host '[GLOBAL] - [PROFILE] - OPCION NUMERO').Trim()
        if ($sel -eq '0') { return (New-CustomProfile) }
        if ($profiles.ContainsKey($sel)) { return $profiles[$sel] }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }
}

function Write-ProfileInfo {
    param([Parameter(Mandatory)]$Profile)
    Write-Host ''
    Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - ENCODER: {0}" -f $Profile.VideoEncoder.ToUpper())
    if ($Profile.VideoEncoder -ne 'copy') {
        if ($Profile.VideoProfile) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - PROFILE: {0}" -f $Profile.VideoProfile) }
        if ($Profile.VideoLevel)   { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - LEVEL:   {0}" -f $Profile.VideoLevel) }
        if ($null -ne $Profile.Qmin) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - QMIN:    {0}" -f $Profile.Qmin) }
        if ($null -ne $Profile.Qmax) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - QMAX:    {0}" -f $Profile.Qmax) }
        if ($null -ne $Profile.Crf)  { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - CRF:     {0}" -f $Profile.Crf) }
        Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - DETECTAR BORDE: {0}" -f $Profile.DetectBorder)
        if ($Profile.ChangeSize) { Write-CvLog 'GLOBAL' ("[INFO] - [VIDEO] - RESIZE: {0}" -f $Profile.ChangeSize) }
    }
    Write-CvLog 'GLOBAL' ("[INFO] - [AUDIO] - ENCODER: {0} / {1}" -f $Profile.AudioEncoder, $Profile.AudioBitrate)
    Write-Host ''
}

Export-ModuleMember -Function *
