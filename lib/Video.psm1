<#
    Video.psm1 - Fase ASK (deteccion de bordes / resize / animacion) y fase RUN (codificacion).
    Espejo de process_video.cmd.
#>

function Find-CropDetect {
    <#
        Escanea un tramo del video con cropdetect y devuelve el recorte mas frecuente
        (formato W:H:X:Y) o $null si no se detecta nada.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$Start = -1, [int]$Duration = -1
    )
    if ($Start -lt 0)    { $Start = [int]$Context.BorderStart }
    if ($Duration -lt 0) { $Duration = [int]$Context.BorderDur }
    $stop = $Start + $Duration
    Write-CvLog 'VIDEO' ("[BORDE] - [SCAN] - Analizando bordes ({0}s desde el segundo {1})..." -f $Duration, $Start)
    $r = Invoke-ToolCapture -Exe $Context.FFmpeg -Arguments @(
        '-hide_banner','-ss', "$Start", '-to', "$stop", '-i', $File,
        '-vf','cropdetect','-f','null','-'
    ) -Context $Context
    $cropMatches = [regex]::Matches($r.StdErr, 'crop=(\d+:\d+:\d+:\d+)')
    if ($cropMatches.Count -eq 0) { return $null }
    $best = $cropMatches | ForEach-Object { $_.Groups[1].Value } |
            Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    return $best.Name
}

function Show-Preview {
    <#
        Reproduce un tramo con FFplay para revisar visualmente. Si se pasa -Crop,
        aplica el filtro de recorte. Ventana con autoexit tras unos segundos.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [string]$Crop = '', [int]$Seconds = 20
    )
    $start = [int]$Context.BorderStart
    $title = 'ORIGINAL'
    $ffArgs  = @('-hide_banner','-loglevel','error','-ss', "$start", '-t', "$Seconds", '-autoexit')
    if ($Crop) { $ffArgs += @('-vf', "crop=$Crop"); $title = "RECORTADO $Crop" }
    $ffArgs += @('-window_title', $title, $File)
    Write-CvLog 'VIDEO' ("[BORDE] - [TEST] - Reproduciendo: {0}  (se cierra solo o pulsa ESC)" -f $title)
    Invoke-ToolShow -Exe $Context.FFplay -Arguments $ffArgs -Context $Context -Preview | Out-Null
}

function Invoke-VideoAsk {
    <#
        Hace las preguntas/detecciones de video y devuelve un objeto:
        @{ Skip; Crop; Resize; Anim }
        $ForceBorder fuerza la deteccion (regla del prefijo '_').
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)]$Info,
        [bool]$ForceBorder = $false
    )
    $res = [ordered]@{ Skip = $false; Crop = ''; Resize = ''; Anim = $false }

    if ($Profile.VideoEncoder -eq 'copy') {
        Write-CvLog 'VIDEO' '[SKIP] - Se copiara la pista de video'
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $vstream = Get-VideoStream -Info $Info
    if ($null -eq $vstream) {
        Write-CvLog 'VIDEO' '[SKIP] - No se ha detectado pista de video'
        $res.Skip = $true
        return [pscustomobject]$res
    }

    # ---- Deteccion de bordes ----
    $detect = [bool]$Profile.DetectBorder
    if ($ForceBorder) {
        $detect = $true
        Write-CvLog 'VIDEO' '[BORDE] - Prefijo _ : se fuerza la deteccion de bordes'
    }
    if ($detect) {
        $start = [int]$Context.BorderStart
        $dur   = [int]$Context.BorderDur
        $done  = $false
        while (-not $done) {
            $crop = Find-CropDetect -Context $Context -File $Info.format.filename -Start $start -Duration $dur

            if (-not $crop) {
                Write-CvLog 'VIDEO' '[BORDE] - No se detectaron bordes en este tramo'
                $a = (Read-Host '[VIDEO] - [BORDE] - [R] reintentar con otro tramo / [ENTER] continuar sin recorte').Trim()
                if ($a -match '^[Rr]') {
                    $start = Read-IntOrDefault '   Segundo de inicio del scan' $start
                    $dur   = Read-IntOrDefault '   Duracion del scan (seg)'    $dur
                    continue
                }
                $res.Crop = ''; $done = $true; continue
            }

            Write-CvLog 'VIDEO' ("[BORDE] - Detectado recorte: {0}" -f $crop)
            # Previsualizacion: primero el original, luego con el recorte aplicado.
            Show-Preview -Context $Context -File $Info.format.filename
            Show-Preview -Context $Context -File $Info.format.filename -Crop $crop

            $a = (Read-Host '[VIDEO] - [BORDE] - [ENTER/S] usar este recorte / [N] volver a detectar / [M] valor manual / [0] sin recorte').Trim()
            if ($a -eq '' -or $a -match '^[SsYy]$') {
                $res.Crop = $crop; $done = $true
            }
            elseif ($a -match '^0$') {
                $res.Crop = ''; $done = $true
            }
            elseif ($a -match '^[Mm]$') {
                $manual = (Read-Host ("   Nuevo recorte en formato W:H:X:Y [{0}]" -f $crop)).Trim()
                if ($manual -eq '') { $manual = $crop }
                Show-Preview -Context $Context -File $Info.format.filename -Crop $manual
                $ok = (Read-Host ("   Usar {0}? (ENTER=si / N=volver a detectar)" -f $manual)).Trim()
                if ($ok -match '^[Nn]$') { continue }
                $res.Crop = $manual; $done = $true
            }
            else {
                # [N] u otra cosa: volver a detectar, permitiendo cambiar el tramo.
                $start = Read-IntOrDefault '   Segundo de inicio del scan' $start
                $dur   = Read-IntOrDefault '   Duracion del scan (seg)'    $dur
            }
        }
    }

    # ---- Resize (se puede combinar con recorte: se aplica crop y luego scale) ----
    if ($Profile.ChangeSize) {
        $res.Resize = $Profile.ChangeSize
        if ($res.Crop -ne '') {
            Write-CvLog 'VIDEO' ("[RESIZE] - Se aplicara recorte {0} y luego escalado {1}" -f $res.Crop, $res.Resize)
        } else {
            Write-CvLog 'VIDEO' ("[RESIZE] - Escalado a {0}" -f $res.Resize)
        }
    }

    # ---- Animacion (solo libx264/libx265) ----
    if ($Profile.VideoEncoder -in @('libx264','libx265')) {
        $a = (Read-Host '[VIDEO] - Es un video de animacion? (s/N)').Trim()
        $res.Anim = ($a -match '^[SsYy]')
    }

    return [pscustomobject]$res
}

function Get-VideoArgs {
    <# Construye el array de argumentos ffmpeg de la parte de codec/opciones de video. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Profile, [bool]$Anim = $false)
    $a = @()
    $enc = $Profile.VideoEncoder
    $qmin = $Profile.Qmin; $qmax = $Profile.Qmax
    $constqp = ($null -ne $qmin -and $null -ne $qmax -and "$qmin" -eq "$qmax")

    switch ($enc) {
        'hevc_nvenc' {
            $a += @('-c:v','hevc_nvenc','-tier','high')
            if ($Profile.VideoProfile -eq 'main10') { $a += @('-pix_fmt','p010le') } else { $a += @('-pix_fmt','yuv420p') }
            $a += @('-preset','slow')
            if ($Profile.VideoProfile) { $a += @('-profile:v',$Profile.VideoProfile) }
            if ($Profile.VideoLevel)   { $a += @('-level:v',"$($Profile.VideoLevel)") }
            if ($constqp) { $a += @('-rc','constqp','-qp',"$qmax") }
            else {
                if ($null -ne $qmin) { $a += @('-qmin',"$qmin") }
                if ($null -ne $qmax) { $a += @('-qmax',"$qmax") }
            }
            # NOTA: NVENC no admite -refs (muchas GPUs fallan con "No capable devices found").
            $a += @('-rc-lookahead:v','32','-r',"$($Context.Fps)",'-movflags','+faststart')
        }
        'h264_nvenc' {
            $a += @('-c:v','h264_nvenc','-pix_fmt','yuv420p','-preset','slow')
            if ($constqp) { $a += @('-rc','constqp','-qp',"$qmax") }
            else {
                if ($null -ne $qmin) { $a += @('-qmin',"$qmin") }
                if ($null -ne $qmax) { $a += @('-qmax',"$qmax") }
            }
            $a += @('-rc-lookahead:v','32','-r',"$($Context.Fps)",'-movflags','+faststart')
        }
        'libx264' {
            $a += @('-c:v','libx264','-pix_fmt','yuv420p')
            if ($null -ne $Profile.Crf) { $a += @('-crf',"$($Profile.Crf)") }
            $a += @('-preset','slow')
            if ($Anim) { $a += @('-tune','animation') }
            $a += @('-refs','4','-r',"$($Context.Fps)",'-movflags','+faststart')
        }
        'libx265' {
            $a += @('-c:v','libx265','-pix_fmt','yuv420p')
            if ($null -ne $Profile.Crf) { $a += @('-crf',"$($Profile.Crf)") }
            $a += @('-preset','slow')
            if ($Profile.VideoProfile) { $a += @('-profile:v',$Profile.VideoProfile) }
            if ($Profile.VideoLevel)   { $a += @('-level:v',"$($Profile.VideoLevel)") }
            if ($Anim) { $a += @('-tune','animation') }
            $a += @('-refs','4','-r',"$($Context.Fps)",'-movflags','+faststart')
        }
    }
    return ,$a
}

function Invoke-VideoRun {
    <# Codifica el video usando la config del job. Devuelve $true si crea la salida temporal. #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$File,
        [string]$Crop = '', [string]$Resize = '', [bool]$Anim = $false
    )
    $name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $outTmp = (Get-CvTempPaths -Context $Context -Name $name).Video
    if (Test-Path -LiteralPath $outTmp) { Remove-Item -Force -LiteralPath $outTmp -ErrorAction SilentlyContinue }

    # filtro de video
    $vf = @()
    if ($Crop)   { $vf += "crop=$Crop" }
    if ($Resize) { $vf += "scale=$Resize" }

    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)",'-i',$File,'-an','-sn','-map_chapters','-1')
    $ffArgs += @('-metadata','title=', '-metadata:s:v','title=', '-metadata:s:v','language=und')
    if ($vf.Count -gt 0) { $ffArgs += @('-vf', ($vf -join ',')) }
    $ffArgs += (Get-VideoArgs -Context $Context -Profile $Profile -Anim $Anim)
    $ffArgs += @('-map','0:0','-f','matroska',$outTmp)

    Write-CvLog 'VIDEO' 'Procesando...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    if ($code -ne 0) {
        Write-CvLog 'VIDEO' ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        if (Test-Path -LiteralPath $outTmp) { Remove-Item -Force -LiteralPath $outTmp -ErrorAction SilentlyContinue }
        return $false
    }
    return ((Test-Path -LiteralPath $outTmp) -and ((Get-Item -LiteralPath $outTmp).Length -gt 0))
}

Export-ModuleMember -Function *
