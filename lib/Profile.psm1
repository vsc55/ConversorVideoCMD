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
    <#
        Construye un perfil de forma interactiva. En CUALQUIER pregunta, escribir 'C' o
        pulsar ESC cancela y vuelve al menu de perfiles. Al final permite [R]ehacer.
        Devuelve el perfil, o $null si se cancela.
    #>
    while ($true) {
        try {
            $encoders = [ordered]@{
                '1' = @{ Value = 'libx264';    Text = '[h264 - CPU]' }
                '2' = @{ Value = 'h264_nvenc'; Text = '[h264 - GPU]' }
                '3' = @{ Value = 'libx265';    Text = '[h265 - CPU]' }
                '4' = @{ Value = 'hevc_nvenc'; Text = '[h265 - GPU]' }
                '5' = @{ Value = 'copy';       Text = '' }
            }
            Show-Menu -Title 'ENCODER DE VIDEO:' -Lines (@(Get-CvMenuLines $encoders) + @('', 'C / ESC. Cancelar (volver al menu de perfiles)'))
            $enc = ''
            while ($enc -eq '') {
                $k = (Read-CvLine -Prompt '   Opcion' -AllowCancel).Trim()
                if ($k -match '^[Cc]$') { throw 'CV_CANCEL' }
                $enc = Get-CvOptionValue $encoders $k
                if (-not $enc) { Write-Host '   Opcion no valida.' -ForegroundColor Yellow }
            }

            $p = New-CvProfile -Name 'custom' -VideoEncoder $enc

            if ($enc -ne 'copy') {
                $p.DetectBorder = Read-YesNo '   Detectar bordes negros en cada archivo?' $false -AllowCancel

                if (Read-YesNo '   Cambiar el tamano del video?' $false -AllowCancel) {
                    Show-Menu -Title 'TAMANOS DE REFERENCIA:' -Lines @(
                        '360p  [Mobile]          - 640:360',
                        '576p  [PAL Widescreen]  - 1024:576',
                        '720p  [HD]              - 1280:720',
                        '1080p [Full HD]         - 1920:1080',
                        '4K    [UHDTV]           - 3840:2160',
                        '',
                        'Altura -1 = automatico manteniendo aspecto (ej 1920:-1)',
                        '',
                        'C / ESC. Cancelar'
                    )
                    $sz = (Read-CvLine -Prompt '   Nuevo tamano (ej 1920:-1, 1280:720) [C/ESC = cancelar]' -AllowCancel).Trim()
                    if ($sz -match '^[Cc]$') { throw 'CV_CANCEL' }
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
                $p.VideoProfile = Select-FromList -Title 'Perfil de codec:' -Options $profOpts -NoneLabel 'ninguno' -AllowCancel
                $p.VideoLevel   = Select-FromList -Title 'Level:' -Options $lvlOpts -NoneLabel 'ninguno' -AllowCancel

                # Control de tasa: CRF (CPU) o qmin/qmax (NVENC)
                if ($enc -in @('libx264','libx265')) {
                    $p.Crf = Read-QOrNull '   CRF (0-51)' 21 -AllowCancel
                } else {
                    $p.Qmin = Read-QOrNull '   QMIN (0-51)' 1 -AllowCancel
                    $p.Qmax = Read-QOrNull '   QMAX (0-51)' 23 -AllowCancel
                }
            }

            # Audio ('0. copy' y '6. custom' son especiales; el resto sale del mapa)
            $abMap = [ordered]@{ '1'='128k'; '2'='160k'; '3'='192k'; '4'='256k'; '5'='320k' }
            Show-Menu -Title 'BITRATE DE AUDIO:' -Lines (@('0. copy') + @(Get-CvMenuLines $abMap) + @('6. custom', '', 'C / ESC. Cancelar'))
            while ($true) {
                $ab = (Read-CvLine -Prompt '   Opcion [3]' -AllowCancel).Trim()
                if ($ab -match '^[Cc]$') { throw 'CV_CANCEL' }
                if ($ab -eq '') { $ab = '3' }
                if ($ab -eq '0') { $p.AudioEncoder = 'copy'; $p.AudioBitrate = ''; break }
                if ($abMap.Contains($ab)) { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = "$($abMap[$ab])"; break }
                if ($ab -eq '6') {
                    $cb = (Read-CvLine -Prompt '   Bitrate (ej 96k, 224k)' -AllowCancel).Trim()
                    if ($cb -match '^[Cc]$') { throw 'CV_CANCEL' }
                    if ($cb -ne '') { $p.AudioEncoder = 'aac_coder'; $p.AudioBitrate = $cb; break }
                }
                Write-Host '   Opcion no valida.' -ForegroundColor Yellow
            }

            # Resumen y confirmacion.
            Write-ProfileInfo -Profile $p
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
    <# Muestra el menu y devuelve el perfil elegido, o $null si el usuario elige salir (X). #>
    $profiles = Get-CvProfiles
    $show = $true
    while ($true) {
        if ($show) {
            Show-Menu -Title 'USAR PERFIL:' -Lines @(
                '1. A: 192K, V: COPY',
                '2. A: 192K, V: h265[NV]/M10/L5/Q(1-23)',
                '3. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/DETECT BORDE',
                '4. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)',
                '5. A: 192K, V: h265[NV]/M10/L5/Q(AUTO)/DETECT BORDE',
                '6. A: 192K, V: h265[NV]/M10/L5/Q(1-23)/RESIZE 1080P',
                '7. A: 192K, V: h264[NV]/L5/Q(1-23)',
                '',
                '0. Custom (configuracion personalizada)',
                '',
                'X. Salir'
            )
            $show = $false
        }
        $sel = (Read-Host '[GLOBAL] - [PROFILE] - OPCION NUMERO (X = salir)').Trim()
        if ($sel -match '^[Xx]$') { return $null }                 # salir
        if ($sel -eq '0') {
            $custom = New-CustomProfile
            if ($null -ne $custom) { return $custom }
            Clear-Host                                             # custom cancelado -> limpiar y re-mostrar
            $show = $true
            continue
        }
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
