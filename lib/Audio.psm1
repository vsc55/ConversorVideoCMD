<#
    Audio.psm1 - Fase ASK (seleccion de pista + sincronia) y RUN (extraccion + volumen).
    La normalizacion de volumen se hace midiendo el pico con volumedetect de ffmpeg
    (independiente del locale) y aplicando ganancia al recodificar.
#>

function Get-CvChannelLayout {
    <# Nombre de layout de ffmpeg para N canales (para aformat/aevalsrc del audio de salida). #>
    param([int]$Channels)
    switch ($Channels) {
        1 { 'mono' }; 2 { 'stereo' }; 6 { '5.1' }; 8 { '7.1' }
        default { 'stereo' }
    }
}

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

function Show-AudioPreview {
    <#
        Reproduce un tramo de una pista de audio concreta con FFplay para revisarla.
        -AudioPos: posicion 0-based entre las pistas de AUDIO (se selecciona con '-ast a:N').
        -AudioOnly: sin ventana de video ('-nodisp'); si no, muestra el video con esa pista.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$AudioPos, [string]$Label = 'AUDIO', [switch]$AudioOnly, [int]$Seconds = -1, [int]$Start = -1, [double]$Duration = 0
    )
    $start = if ($Start -ge 0) { $Start } else { [int]$Context.PreviewStart }
    $start = Get-CvSafeStart -Start $start -Duration $Duration -Window 1
    if ($Seconds -lt 0) { $Seconds = [int]$Context.PreviewSeconds }
    $ffArgs = @('-hide_banner','-loglevel','error','-ss', "$start", '-t', "$Seconds", '-autoexit', '-ast', ("a:{0}" -f $AudioPos))
    if ($AudioOnly) { $ffArgs += '-nodisp' }
    $ffArgs += @('-window_title', $Label, $File)
    $modo = if ($AudioOnly) { 'solo audio' } else { 'video + audio' }
    Write-CvLog 'AUDIO' ("[TEST] - Reproduciendo {0} ({1}); se cierra solo o pulsa ESC/Q" -f $Label, $modo) -Indent 3
    Invoke-ToolShow -Exe $Context.FFplay -Arguments $ffArgs -Context $Context -Preview | Out-Null
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
    Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (mismo idioma) [* = por defecto]:' -Lines $lines -Indent 3
    while ($true) {
        $a = (Read-Host ("   [AUDIO] - Indice de pista a usar [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }
        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $match = $AudioStreams | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            if ($match) { Write-Host ''; return (ConvertTo-AudioSel $match) }
        }
        Write-Host '   Indice no valido.' -ForegroundColor Yellow
    }
}

function Select-AudioFallback {
    <#
        Cuando NO hay ninguna pista en el idioma preferido: muestra la lista de pistas,
        deja REPRODUCIR (video+audio o solo audio) para confirmar cual es, y luego pregunta
        que IDIOMA asignar (el que trae la pista, otro codigo, o 'und'), porque el tag de
        idioma puede ser una errata. Devuelve un objeto de seleccion {Index,Language,Channels,Is51}.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$AudioStreams, [int]$DefaultIndex, [double]$Duration = 0
    )
    $streams = @($AudioStreams)
    # Posicion 0-based de cada pista de audio (para '-ast a:N' en la reproduccion).
    $posByIndex = @{}
    for ($i = 0; $i -lt $streams.Count; $i++) { $posByIndex[[int]$streams[$i].index] = $i }

    # ---- 1) Elegir pista (con opcion de reproducir para confirmar) ----
    $chosen = $null
    while ($null -eq $chosen) {
        $lines = @()
        foreach ($s in $streams) {
            $lang  = Get-Tag $s 'language'; $title = Get-Tag $s 'title'
            $mark  = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
            $titleTxt = ''; if ($title) { $titleTxt = "'$title'" }
            $lines += ("{0} [{1}] idioma={2} codec={3} canales={4} {5}" -f $mark, $s.index, $lang, $s.codec_name, $s.channels, $titleTxt)
        }
        Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (ningun idioma preferido) [* = descarte]:' -Lines $lines -Indent 3
        $a = (Read-Host ("   [AUDIO] - Indice / 'P N'=video+audio / 'A N'=solo audio (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }

        # Reproducir para revisar: 'P N' (video+audio) o 'A N' (solo audio); 3er numero = segundo
        # de inicio opcional (para buscar dialogo cuando el punto por defecto no tiene voces).
        $mPlay = [regex]::Match($a, '^([PpAa])\s*(\d+)(?:\s+(\d+))?$')
        if ($mPlay.Success) {
            $pi = [int]$mPlay.Groups[2].Value
            $st = if ($mPlay.Groups[3].Success) { [int]$mPlay.Groups[3].Value } else { -1 }
            if ($posByIndex.ContainsKey($pi)) {
                $audioOnly = ($mPlay.Groups[1].Value -match '^[Aa]$')
                Show-AudioPreview -Context $Context -File $File -AudioPos $posByIndex[$pi] -Label ("PISTA {0}" -f $pi) -AudioOnly:$audioOnly -Start $st -Duration $Duration
            } else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }

        $n = 0
        if ([int]::TryParse($a, [ref]$n) -and $posByIndex.ContainsKey($n)) {
            $ok = (Read-Host ("   Usar la pista {0}? (ENTER=si / N=volver a la lista)" -f $n)).Trim()
            if ($ok -match '^[Nn]$') { continue }
            $chosen = $streams | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            continue
        }
        Write-Host '   Indice no valido.' -ForegroundColor Yellow
    }

    $sel = ConvertTo-AudioSel $chosen
    # ---- 2) Idioma a asignar (el tag puede ser una errata) ----
    $trackLang = if ($sel.Language) { "$($sel.Language)" } else { '' }
    $lang = 'und'
    while ($true) {
        if ($trackLang) {
            $r = (Read-Host ("   [AUDIO] - Idioma a asignar: [ENTER]='{0}' / [O]tro codigo / [U]nd" -f $trackLang)).Trim()
        } else {
            $r = (Read-Host '   [AUDIO] - La pista no trae idioma: [O]tro codigo / [ENTER]=und').Trim()
        }
        if ($r -eq '')            { $lang = if ($trackLang) { $trackLang } else { 'und' }; break }
        if ($r -match '^[Uu]$')   { $lang = 'und'; break }
        if ($r -match '^[Oo]$') {
            $c = (Read-Host '   Codigo de idioma ISO 639-2 (ej: spa, eng, fre)').Trim()
            if ($c -ne '') { $lang = $c.ToLower(); break }
            continue
        }
        # Permitir teclear el codigo directamente (2-3 letras).
        if ($r -match '^[A-Za-z]{2,3}$') { $lang = $r.ToLower(); break }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }
    Write-Host ''
    # Devolver la seleccion con el idioma ELEGIDO (no el del tag original).
    return [pscustomobject]@{ Index = $sel.Index; Language = $lang; Channels = $sel.Channels; Is51 = $sel.Is51 }
}

function Invoke-AudioAsk {
    <# Devuelve @{ Skip; Index; Is51; Sync; Lang; Manual }. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof, [Parameter(Mandatory)]$Info)
    $res = [ordered]@{ Skip = $false; Index = -1; Is51 = $false; Sync = 0; Lang = ''; Manual = $false }

    if ($Prof.AudioEncoder -eq 'copy') {
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[SKIP] - Se copiara la pista de audio original' }
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $aud = @(Get-AudioStreams -Info $Info)
    if ($aud.Count -eq 0) {
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[SKIP] - No se ha detectado pista de audio' }
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $sel = Select-AudioStream -Info $Info -PrefLangs $Context.AudioLangs
    $prefTracks = @($aud | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.AudioLangs })
    if ($prefTracks.Count -gt 1) {
        # Ambiguedad: 2+ pistas en el idioma preferido, preguntar cual usar.
        $sel = Select-AudioInteractive -AudioStreams $aud -DefaultIndex $sel.Index
        $res.Manual = $true   # se eligio pista de audio a mano (varias del idioma preferido)
    }
    elseif ($prefTracks.Count -eq 0) {
        # No hay NINGUNA pista en el idioma preferido: elegir a mano (con reproduccion para
        # confirmar) y decidir que idioma asignar (el tag puede ser una errata).
        Write-CvLog 'AUDIO' ("[AVISO] - No hay pista de audio en el idioma preferido ({0}); elige una manualmente." -f ($Context.AudioLangs -join '/')) -Indent 3
        $adur = 0.0
        if ($Info.format.PSObject.Properties['duration']) { $dd = ConvertTo-InvDouble $Info.format.duration; if ($null -ne $dd) { $adur = [double]$dd } }
        $sel = Select-AudioFallback -Context $Context -File $Info.format.filename -AudioStreams $aud -DefaultIndex $sel.Index -Duration $adur
        $res.Manual = $true   # se eligio pista/idioma a mano (no habia idioma preferido)
    }

    $lang = if ($sel.Language) { "$($sel.Language)" } else { 'und' }

    $res.Index = $sel.Index
    $res.Is51  = $sel.Is51
    $res.Lang  = $lang
    if ($Context.Debug) { Write-CvLog 'AUDIO' ("[INFO] - Pista {0} (idioma={1}, canales={2})" -f $sel.Index, $lang, $sel.Channels) }

    # ---- Sincronia audio/video ----
    $delay = Get-AudioInitDelay -Context $Context -File $Info.format.filename -Index $sel.Index
    if ($delay -gt 0) {
        # Indentado bajo la linea del archivo (y linea en blanco despues) para agrupar la
        # pregunta interactiva con su archivo en el listado compacto de PREPARAR.
        Write-CvLog 'AUDIO' ("[SYNC] - El audio empieza {0}s mas tarde que el video" -f $delay) -Indent 3
        $ans = (Read-Host ("   [VIDEO] - [SYNC] - Silencio a anadir al inicio en seg [{0}] (ENTER=usar / 0=ninguno)" -f $delay)).Trim()
        $res.Manual = $true   # se pregunto por el silencio de sincronia (intervencion manual)
        if ($ans -eq '') { $res.Sync = $delay }
        else {
            $v = ConvertTo-InvDouble $ans
            if ($null -ne $v) { $res.Sync = $v }
        }
        Write-Host ''
    } elseif ($Context.Debug) {
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
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)][string]$File, [double]$Sync = 0, [int]$Index = 0
    )
    $name   = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $tmp    = Get-CvTempPaths -Context $Context -Name $name
    $outM4a = $tmp.Audio
    if (Test-Path -LiteralPath $outM4a) { Remove-Item -Force -LiteralPath $outM4a -ErrorAction SilentlyContinue }

    $hz = if ($Prof.AudioHz) { $Prof.AudioHz } else { $Context.DefaultAudioHz }
    # Canales de salida del audio recodificado (config encode.audioChannels; 2 = estereo).
    $ch     = [int]$Context.AudioChannels; if ($ch -lt 1) { $ch = 2 }
    $layout = Get-CvChannelLayout $ch

    # Fuente: si hay que sincronizar, generamos un wav (silencio + audio) en el layout de salida.
    $sourceInput = $null   # args de -i para medir y para codificar
    $mapPre      = @()     # -map o filtro previo
    if ($Sync -gt 0) {
        $wav = $tmp.SyncWav
        if (Test-Path -LiteralPath $wav) { Remove-Item -Force -LiteralPath $wav -ErrorAction SilentlyContinue }
        $fc = ("[0:{0}]aformat=channel_layouts={3}[a2];aevalsrc=0:d={1}:sample_rate={2}:channel_layout={3}[sil];[sil][a2]concat=n=2:v=0:a=1[out]" -f $Index, $Sync, $hz, $layout)
        Start-CvStep $Context 'AUDIO' ("Generando silencio de {0}s + pista..." -f $Sync)
        Invoke-ToolShow -Exe $Context.FFmpeg -Arguments @('-hide_banner','-y','-i',$File,'-filter_complex',$fc,'-map','[out]',$wav) -Context $Context | Out-Null
        $syncOk = (Test-Path -LiteralPath $wav)
        Stop-CvStep $Context 'AUDIO' $syncOk -FailMsg '[ERR] - No se pudo generar el audio sincronizado'
        if (-not $syncOk) { return $false }
        $sourceInput = @('-i',$wav)
        $mapPre      = @('-map','0:a')
    } else {
        $sourceInput = @('-i',$File)
        $mapPre      = @('-map',"0:$Index",'-vn','-sn','-map_chapters','-1')
    }

    # Etiqueta de la pista de audio en el filtro: si venimos del wav sincronizado solo
    # hay una pista (0:a); si no, hay que referenciar el indice concreto (0:Index), no [0:a]
    # (que seria la PRIMERA pista y podria no ser la seleccionada).
    $aLabel = if ($Sync -gt 0) { '0:a' } else { "0:$Index" }
    $method = "$($Context.VolumeMethod)".ToLower()
    if ($method -notin @('peak','loudnorm','aacgain')) { $method = 'peak' }

    # Base del comando de codificacion a AAC.
    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)") + $sourceInput

    if ($method -eq 'peak') {
        # PEAK: medir el pico (volumedetect) y llevarlo a 0 dB con el filtro volume.
        $peak = Get-MaxVolume -Context $Context -InputArgs ($sourceInput + $mapPre)
        $gain = 0.0
        if ($null -ne $peak -and $peak -lt 0) { $gain = [math]::Round(-$peak, 1) }
        if ($gain -gt 0) {
            Write-CvInfoStep $Context 'AUDIO' ("Aplicando ganancia +{0} dB" -f $gain)
            $gtxt = $gain.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $ffArgs += @('-filter_complex', ("[{0}]volume={1}dB:precision=fixed[a]" -f $aLabel, $gtxt), '-map','[a]')
        } else {
            if ($Context.Debug) { Write-CvLog 'AUDIO' '[VOL] - [PEAK] - Sin ajuste de volumen' }
            $ffArgs += $mapPre
        }
    }
    elseif ($method -eq 'loudnorm') {
        # LOUDNORM: normalizacion de sonoridad EBU R128 (una pasada). I/TP/LRA desde config.
        $inv  = [System.Globalization.CultureInfo]::InvariantCulture
        $li   = ([double]$Context.LoudnormI).ToString($inv)
        $ltp  = ([double]$Context.LoudnormTP).ToString($inv)
        $llra = ([double]$Context.LoudnormLRA).ToString($inv)
        Write-CvInfoStep $Context 'AUDIO' ("Normalizando sonoridad (I={0}, TP={1}, LRA={2})" -f $li, $ltp, $llra)
        $ffArgs += @('-filter_complex', ("[{0}]loudnorm=I={1}:TP={2}:LRA={3}[a]" -f $aLabel, $li, $ltp, $llra), '-map','[a]')
    }
    else {
        # AACGAIN: se codifica sin ajuste y despues se aplica la ganancia sin perdida.
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[VOL] - [AACGAIN] - La ganancia se aplicara al m4a despues de codificar' }
        $ffArgs += $mapPre
    }

    $ffArgs += @('-c:a','aac','-aac_coder','twoloop','-ac',"$ch",'-ar',"$hz")
    if ($Prof.AudioBitrate) { $ffArgs += @('-b:a',"$($Prof.AudioBitrate)") }
    $ffArgs += $outM4a

    Start-CvStep $Context 'AUDIO' 'Recodificando audio...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    if ($code -ne 0) {
        Stop-CvStep $Context 'AUDIO' $false -FailMsg ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        if (Test-Path -LiteralPath $outM4a)      { Remove-Item -Force -LiteralPath $outM4a -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $tmp.SyncWav) { Remove-Item -Force -LiteralPath $tmp.SyncWav -ErrorAction SilentlyContinue }
        return $false
    }
    Stop-CvStep $Context 'AUDIO' $true

    # AACGAIN: aplicar la ganancia ReplayGain sobre el m4a ya codificado (sin recodificar).
    if ($method -eq 'aacgain' -and (Test-Path -LiteralPath $outM4a)) {
        if (Test-Path $Context.AacGain) {
            Start-CvStep $Context 'AUDIO' 'Aplicando ganancia sin perdida (aacgain)...'
            [void](Invoke-ToolShow -Exe $Context.AacGain -Arguments @('/r','/c','/q', $outM4a) -Context $Context)
            Stop-CvStep $Context 'AUDIO' $true
        } else {
            Write-CvLog 'AUDIO' '[VOL] - [AACGAIN] - [AVISO] - No se encuentra aacgain.exe, se omite el ajuste'
        }
    }

    # limpieza del wav temporal
    if (Test-Path -LiteralPath $tmp.SyncWav) { Remove-Item -Force -LiteralPath $tmp.SyncWav -ErrorAction SilentlyContinue }

    return (Test-Path -LiteralPath $outM4a)
}

Export-ModuleMember -Function *
