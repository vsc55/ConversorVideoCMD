<#
    Audio.psm1 - Fase ASK (seleccion de pista + sincronia) y RUN (extraccion + volumen).
    Espejo de process_audio.cmd. La normalizacion de volumen en v1 se hace midiendo el
    pico con volumedetect de ffmpeg (independiente del locale) y aplicando ganancia al
    recodificar; se puede cambiar a aacgain si se prefiere el gain sin perdida.
#>

function Get-AudioInitDelay {
    <# Devuelve el pts_time del primer frame de audio (desfase inicial) o 0. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File, [int]$Index)
    $r = Invoke-ToolCapture -Exe $Context.FFmpeg -Arguments @(
        '-hide_banner','-i',$File,'-map',"0:$Index",'-af','ashowinfo','-f','alaw','-frames:a','1','-y','NUL'
    ) -Context $Context
    $m = [regex]::Match($r.StdErr, 'pts_time:\s*(\d+(\.\d+)?)')
    if ($m.Success) {
        $v = ConvertTo-InvDouble $m.Groups[1].Value
        if ($null -ne $v) { return $v }
    }
    return 0.0
}

function Select-AudioInteractive {
    <# Menu para elegir pista de audio cuando hay ambiguedad. Devuelve el objeto de seleccion. #>
    param([Parameter(Mandatory)]$AudioStreams, [int]$DefaultIndex)
    $lines = @()
    foreach ($s in $AudioStreams) {
        $lang  = Get-Tag $s 'language'
        $title = Get-Tag $s 'title'
        $mark  = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
        $titleTxt = ''; if ($title) { $titleTxt = "'$title'" }
        $lines += ("{0} [{1}] idioma={2} codec={3} canales={4} {5}" -f $mark, $s.index, $lang, $s.codec_name, $s.channels, $titleTxt)
    }
    Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (mismo idioma) [* = por defecto]:' -Lines $lines
    while ($true) {
        $a = (Read-Host ("[AUDIO] - Indice de pista a usar [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }
        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $match = $AudioStreams | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            if ($match) { return (ConvertTo-AudioSel $match) }
        }
        Write-Host '   Indice no valido.' -ForegroundColor Yellow
    }
}

function Invoke-AudioAsk {
    <# Devuelve @{ Skip; Index; Is51; Sync }. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Profile, [Parameter(Mandatory)]$Info)
    $res = [ordered]@{ Skip = $false; Index = -1; Is51 = $false; Sync = 0 }

    if ($Profile.AudioEncoder -eq 'copy') {
        Write-CvLog 'AUDIO' '[SKIP] - Se copiara la pista de audio original'
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $aud = @(Get-AudioStreams -Info $Info)
    if ($aud.Count -eq 0) {
        Write-CvLog 'AUDIO' '[SKIP] - No se ha detectado pista de audio'
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $sel = Select-AudioStream -Info $Info -PrefLangs $Context.AudioLangs
    # Ambiguedad: si hay 2+ pistas en el idioma preferido, preguntar cual usar.
    $prefTracks = @($aud | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.AudioLangs })
    if ($prefTracks.Count -gt 1) {
        $sel = Select-AudioInteractive -AudioStreams $aud -DefaultIndex $sel.Index
    }

    $res.Index = $sel.Index
    $res.Is51  = $sel.Is51
    Write-CvLog 'AUDIO' ("[INFO] - Pista {0} (idioma={1}, canales={2})" -f $sel.Index, $sel.Language, $sel.Channels)

    # ---- Sincronia audio/video ----
    $delay = Get-AudioInitDelay -Context $Context -File $Info.format.filename -Index $sel.Index
    if ($delay -gt 0) {
        Write-CvLog 'AUDIO' ("[SYNC] - El audio empieza {0}s mas tarde que el video" -f $delay)
        $ans = (Read-Host ("[VIDEO] - [SYNC] - Silencio a anadir al inicio en seg [{0}] (ENTER=usar / 0=ninguno)" -f $delay)).Trim()
        if ($ans -eq '') { $res.Sync = $delay }
        else {
            $v = ConvertTo-InvDouble $ans
            if ($null -ne $v) { $res.Sync = $v }
        }
    } else {
        Write-CvLog 'AUDIO' '[SYNC] - Audio y video inician a la vez [OK]'
    }
    return [pscustomobject]$res
}

function Get-MaxVolume {
    <# Mide el pico (max_volume, dB) de una fuente descrita por sus args de entrada. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string[]]$InputArgs)
    $a = @('-hide_banner') + $InputArgs + @('-af','volumedetect','-f','null','-')
    $r = Invoke-ToolCapture -Exe $Context.FFmpeg -Arguments $a -Context $Context
    $m = [regex]::Match($r.StdErr, 'max_volume:\s*(-?\d+(\.\d+)?)')
    if ($m.Success) { return (ConvertTo-InvDouble $m.Groups[1].Value) }
    return $null
}

function Invoke-AudioRun {
    <# Extrae/recodifica el audio a m4a (AAC), con sincronia y normalizacion de volumen. #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Profile,
        [Parameter(Mandatory)][string]$File, [double]$Sync = 0, [int]$Index = 0
    )
    $name   = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $outM4a = Join-Path $Context.Proceso ("{0}.m4a" -f $name)
    if (Test-Path $outM4a) { Remove-Item -Force $outM4a -ErrorAction SilentlyContinue }

    $hz = if ($Profile.AudioHz) { $Profile.AudioHz } else { $Context.DefaultAudioHz }

    # Fuente: si hay que sincronizar, generamos un wav (silencio + audio) en estereo.
    $sourceInput = $null   # args de -i para medir y para codificar
    $mapPre      = @()     # -map o filtro previo
    if ($Sync -gt 0) {
        $wav = Join-Path $Context.Proceso ("{0}_concat.wav" -f $name)
        if (Test-Path $wav) { Remove-Item -Force $wav -ErrorAction SilentlyContinue }
        $fc = ("[0:{0}]aformat=channel_layouts=stereo[a2];aevalsrc=0:d={1}:sample_rate={2}:channel_layout=stereo[sil];[sil][a2]concat=n=2:v=0:a=1[out]" -f $Index, $Sync, $hz)
        Write-CvLog 'AUDIO' ("[SYNC] - [FIX] - Generando silencio de {0}s + pista..." -f $Sync)
        Invoke-ToolShow -Exe $Context.FFmpeg -Arguments @('-hide_banner','-y','-i',$File,'-filter_complex',$fc,'-map','[out]',$wav) -Context $Context | Out-Null
        if (-not (Test-Path $wav)) { Write-CvLog 'AUDIO' '[ERR] - No se pudo generar el audio sincronizado'; return $false }
        $sourceInput = @('-i',$wav)
        $mapPre      = @('-map','0:a')
    } else {
        $sourceInput = @('-i',$File)
        $mapPre      = @('-map',"0:$Index",'-vn','-sn','-map_chapters','-1')
    }

    # Medir pico y calcular ganancia (llevar el pico a 0 dB).
    $peak = Get-MaxVolume -Context $Context -InputArgs ($sourceInput + $mapPre)
    $gain = 0.0
    if ($null -ne $peak -and $peak -lt 0) { $gain = [math]::Round(-$peak, 1) }
    if ($gain -gt 0) { Write-CvLog 'AUDIO' ("[VOL] - Aplicando ganancia +{0} dB" -f $gain) }
    else { Write-CvLog 'AUDIO' '[VOL] - Sin ajuste de volumen' }

    # Etiqueta de la pista de audio en el filtro: si venimos del wav sincronizado solo
    # hay una pista (0:a); si no, hay que referenciar el indice concreto (0:Index), no [0:a]
    # (que seria la PRIMERA pista y podria no ser la seleccionada).
    $aLabel = if ($Sync -gt 0) { '0:a' } else { "0:$Index" }

    # Codificar a AAC.
    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)") + $sourceInput
    if ($gain -gt 0) {
        $inv  = [System.Globalization.CultureInfo]::InvariantCulture
        $gtxt = $gain.ToString($inv)
        $ffArgs += @('-filter_complex', ("[{0}]volume={1}dB:precision=fixed[a]" -f $aLabel, $gtxt), '-map','[a]')
    } else {
        $ffArgs += $mapPre
    }
    $ffArgs += @('-c:a','aac','-aac_coder','twoloop','-ac','2','-ar',"$hz")
    if ($Profile.AudioBitrate) { $ffArgs += @('-b:a',"$($Profile.AudioBitrate)") }
    $ffArgs += $outM4a

    Write-CvLog 'AUDIO' 'Recodificando audio...'
    Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context | Out-Null

    # limpieza del wav temporal
    $wav = Join-Path $Context.Proceso ("{0}_concat.wav" -f $name)
    if (Test-Path $wav) { Remove-Item -Force $wav -ErrorAction SilentlyContinue }

    return (Test-Path $outM4a)
}

Export-ModuleMember -Function *
