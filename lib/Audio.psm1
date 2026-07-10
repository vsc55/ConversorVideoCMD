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
    $extra = @('-ast', ("a:{0}" -f $AudioPos))
    if ($AudioOnly) { $extra += '-nodisp' }
    $modo = if ($AudioOnly) { 'solo audio' } else { 'video + audio' }
    Write-CvLog 'AUDIO' ("[TEST] - Reproduciendo {0} ({1}); se cierra solo o pulsa ESC/Q" -f $Label, $modo) -Indent 3
    Invoke-CvPreview -Context $Context -File $File -ExtraArgs $extra -Label $Label -Start $Start -Seconds $Seconds -Duration $Duration
}

function Format-CvAudioLine {
    <#
        Linea de una pista de audio para los menus de seleccion: indice, idioma, codec, canales,
        BITRATE (via Get-CvAudioBitrate: stream.bit_rate o tag BPS) y titulo. $Mark = '*' marca la
        recomendada/por defecto. El bitrate ayuda a decidir entre pistas del mismo idioma.
    #>
    param([Parameter(Mandatory)]$Stream, [string]$Mark = ' ')
    $lang  = Get-Tag $Stream 'language'
    $title = Get-Tag $Stream 'title'
    $br    = Get-CvAudioBitrate $Stream
    $brTxt = if ($null -ne $br) { '{0}k' -f [math]::Round($br / 1000) } else { '?' }
    $titleTxt = if ($title) { "'$title'" } else { '' }
    ("{0} [{1}] idioma={2} codec={3} canales={4} bitrate={5} {6}" -f $Mark, $Stream.index, $lang, $Stream.codec_name, $Stream.channels, $brTxt, $titleTxt)
}

function Select-AudioInteractive {
    <#
        Menu para elegir pista de audio cuando hay ambiguedad (2+ del idioma preferido).
        Permite REPRODUCIR cada una ('P N' = video+audio, 'A N' = solo audio, con segundo de
        inicio opcional) para distinguirlas antes de elegir. Devuelve el objeto de seleccion.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$AudioStreams, [int]$DefaultIndex, [double]$Duration = 0
    )
    $streams = @($AudioStreams)
    # Posicion 0-based de cada pista de audio (para '-ast a:N' en la reproduccion).
    $posByIndex = @{}
    for ($i = 0; $i -lt $streams.Count; $i++) { $posByIndex[[int]$streams[$i].index] = $i }

    $lines = @()
    foreach ($s in $streams) {
        $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
        $lines += (Format-CvAudioLine -Stream $s -Mark $mark)
    }
    Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (mismo idioma) [* = por defecto = mejor calidad]:' -Lines $lines -Indent 3
    while ($true) {
        $a = (Read-Host ("   [AUDIO] - Indice / 'P N'=video+audio / 'A N'=solo audio (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }

        # Reproducir para revisar: 'P N' (video+audio) o 'A N' (solo audio); 3er numero opcional.
        $play = ConvertFrom-CvPlayCommand $a -AllowAudioOnly
        if ($play) {
            if ($posByIndex.ContainsKey($play.Index)) {
                Show-AudioPreview -Context $Context -File $File -AudioPos $posByIndex[$play.Index] -Label ("PISTA {0}" -f $play.Index) -AudioOnly:$play.AudioOnly -Start $play.Start -Duration $Duration
            } else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }

        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $match = $streams | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
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
            $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
            $lines += (Format-CvAudioLine -Stream $s -Mark $mark)
        }
        Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (ningun idioma preferido) [* = descarte]:' -Lines $lines -Indent 3
        $a = (Read-Host ("   [AUDIO] - Indice / 'P N'=video+audio / 'A N'=solo audio (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }

        # Reproducir para revisar: 'P N' (video+audio) o 'A N' (solo audio); 3er numero = segundo
        # de inicio opcional (para buscar dialogo cuando el punto por defecto no tiene voces).
        $play = ConvertFrom-CvPlayCommand $a -AllowAudioOnly
        if ($play) {
            if ($posByIndex.ContainsKey($play.Index)) {
                Show-AudioPreview -Context $Context -File $File -AudioPos $posByIndex[$play.Index] -Label ("PISTA {0}" -f $play.Index) -AudioOnly:$play.AudioOnly -Start $play.Start -Duration $Duration
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

    $sel  = Select-AudioStream -Info $Info -PrefLangs $Context.AudioLangs
    $adur = Get-MediaDuration $Info
    $prefTracks = @($aud | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.AudioLangs })
    if ($prefTracks.Count -gt 1) {
        # Ambiguedad: 2+ pistas en el idioma preferido, preguntar cual usar (con reproduccion).
        $sel = Select-AudioInteractive -Context $Context -File $Info.format.filename -AudioStreams $aud -DefaultIndex $sel.Index -Duration $adur
        $res.Manual = $true   # se eligio pista de audio a mano (varias del idioma preferido)
    }
    elseif ($prefTracks.Count -eq 0) {
        # No hay NINGUNA pista en el idioma preferido: elegir a mano (con reproduccion para
        # confirmar) y decidir que idioma asignar (el tag puede ser una errata).
        Write-CvLog 'AUDIO' ("[AVISO] - No hay pista de audio en el idioma preferido ({0}); elige una manualmente." -f ($Context.AudioLangs -join '/')) -Indent 3
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
    # Codec de salida al recodificar (perfil; 'aac' por defecto y para compatibilidad con jobs antiguos).
    # AAC va en .m4a (compatible con aacgain); el resto en .mka (Matroska) que admite cualquier codec.
    $codec  = "$($Prof.AudioCodec)".ToLower(); if (-not $codec) { $codec = 'aac' }
    $outM4a = if ($codec -eq 'aac') { $tmp.Audio } else { $tmp.AudioMka }
    # Limpiar CUALQUIER temporal de audio previo (m4a y mka) para no dejar el que no toca.
    foreach ($old in @($tmp.Audio, $tmp.AudioMka)) {
        if (Test-Path -LiteralPath $old) { Remove-Item -Force -LiteralPath $old -ErrorAction SilentlyContinue }
    }

    $hz = if ($Prof.AudioHz) { $Prof.AudioHz } else { $Context.DefaultAudioHz }
    # Canales de salida del audio recodificado (config encode.audioChannels; 2 = estereo).
    $ch     = [int]$Context.AudioChannels; if ($ch -lt 1) { $ch = 2 }
    $layout = Get-CvChannelLayout $ch

    # Fuente + sincronia:
    #  - CLASICO (por defecto): se genera un WAV (silencio + pista) y luego se codifica ese WAV.
    #  - BETA (test.syncAdelay): el retardo se aplica con el filtro 'adelay' en la MISMA pasada de
    #    codificacion (encadenado con el volumen), sin WAV intermedio.
    $sourceInput = $null   # args de -i para medir y para codificar
    $mapPre      = @()     # -map (+ -vn/-sn...) cuando NO hay filtro
    $aLabel      = ''      # etiqueta de la pista de audio en el filtro
    $syncFilter  = ''      # filtro de retardo (solo modo adelay beta)
    $fromWav     = $false  # $true = la fuente es el WAV ya recortado (clasico con sincronia)

    if ($Sync -gt 0 -and $Context.SyncAdelay) {
        # BETA: retardo en una pasada con adelay (ms), sin WAV.
        Write-CvInfoStep $Context 'AUDIO' ("Sincronia [beta adelay]: retardo de {0}s en una pasada" -f $Sync)
        $sourceInput = @('-i',$File)
        $mapPre      = @('-map',"0:$Index",'-vn','-sn','-map_chapters','-1')
        $aLabel      = "0:$Index"
        $syncFilter  = 'adelay={0}:all=1' -f [int][math]::Round($Sync * 1000)
    }
    elseif ($Sync -gt 0) {
        # CLASICO: WAV = silencio + pista, en el layout de salida; el índice concreto (0:Index),
        # no 0:a (que seria la PRIMERA pista y podria no ser la seleccionada).
        $wav = $tmp.SyncWav
        if (Test-Path -LiteralPath $wav) { Remove-Item -Force -LiteralPath $wav -ErrorAction SilentlyContinue }
        $fc = ("[0:{0}]aformat=channel_layouts={3}[a2];aevalsrc=0:d={1}:sample_rate={2}:channel_layout={3}[sil];[sil][a2]concat=n=2:v=0:a=1[out]" -f $Index, $Sync, $hz, $layout)
        Start-CvStep $Context 'AUDIO' ("Generando silencio de {0}s + pista..." -f $Sync)
        $wavArgs = @('-hide_banner','-y','-i',$File,'-filter_complex',$fc,'-map','[out]')
        if ($Context.TestLimit -gt 0) { $wavArgs += @('-t',"$($Context.TestLimit)") }  # modo pruebas
        $wavArgs += $wav
        Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $wavArgs -Context $Context | Out-Null
        $syncOk = (Test-Path -LiteralPath $wav)
        Stop-CvStep $Context 'AUDIO' $syncOk -FailMsg '[ERR] - No se pudo generar el audio sincronizado'
        if (-not $syncOk) { return $false }
        $sourceInput = @('-i',$wav)
        $mapPre      = @('-map','0:a')
        $aLabel      = '0:a'
        $fromWav     = $true
    }
    else {
        $sourceInput = @('-i',$File)
        $mapPre      = @('-map',"0:$Index",'-vn','-sn','-map_chapters','-1')
        $aLabel      = "0:$Index"
    }

    $method = "$($Context.VolumeMethod)".ToLower()
    if ($method -notin @('peak','loudnorm','aacgain')) { $method = 'peak' }
    # aacgain aplica ReplayGain sobre el .m4a ya codificado; solo funciona con AAC (MP4). Si el codec
    # de salida no es AAC, se usa 'peak' (filtro, valido para cualquier codec) en su lugar.
    if ($method -eq 'aacgain' -and $codec -ne 'aac') {
        Write-CvInfoStep $Context 'AUDIO' ("Volumen: aacgain no aplica a {0}; se usa 'peak'" -f $codec)
        $method = 'peak'
    }

    # Base del comando de codificacion a AAC.
    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)") + $sourceInput

    # Filtro principal de VOLUMEN (se encadenara con $syncFilter en una sola cadena de filtros).
    $mainFilter = ''
    if ($method -eq 'peak') {
        # PEAK: medir el pico (volumedetect) y subirlo hasta el objetivo volume.peakTarget
        # (0 dBFS por defecto; -1 deja margen contra el clipping inter-sample del AAC).
        # Solo se AMPLIFICA (gain > 0): si el pico ya supera el objetivo no se atenua.
        $target = [double]$Context.PeakTarget
        # En modo pruebas medimos solo el tramo que se codifica (-t). Si la fuente es el WAV ya
        # viene recortado, asi que el -t solo se añade cuando la fuente es el archivo original.
        $measureArgs = $sourceInput + $mapPre
        if ($Context.TestLimit -gt 0 -and -not $fromWav) { $measureArgs += @('-t',"$($Context.TestLimit)") }
        # Medir el pico recorre TODO el audio (volumedetect): puede tardar. Paso con ✓ para que
        # no parezca colgado entre "Resolucion" y "Aplicando ganancia".
        Start-CvStep $Context 'AUDIO' 'Analizando volumen...'
        $peak = Get-MaxVolume -Context $Context -InputArgs $measureArgs
        $peakTxt = if ($null -ne $peak) { '(pico {0} dB)' -f $peak } else { '(pico desconocido)' }
        Stop-CvStep $Context 'AUDIO' $true -Extra $peakTxt -OkMsg ("[OK] - Volumen analizado {0}" -f $peakTxt)
        $gain = 0.0
        if ($null -ne $peak -and $peak -lt $target) { $gain = [math]::Round($target - $peak, 1) }
        if ($gain -gt 0) {
            Write-CvInfoStep $Context 'AUDIO' ("Aplicando ganancia +{0} dB" -f $gain)
            $gtxt = $gain.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            $mainFilter = 'volume={0}dB:precision=fixed' -f $gtxt
        } elseif ($Context.Debug) { Write-CvLog 'AUDIO' '[VOL] - [PEAK] - Sin ajuste de volumen' }
    }
    elseif ($method -eq 'loudnorm') {
        # LOUDNORM: normalizacion de sonoridad EBU R128 (una pasada). I/TP/LRA desde config.
        $inv  = [System.Globalization.CultureInfo]::InvariantCulture
        $li   = ([double]$Context.LoudnormI).ToString($inv)
        $ltp  = ([double]$Context.LoudnormTP).ToString($inv)
        $llra = ([double]$Context.LoudnormLRA).ToString($inv)
        Write-CvInfoStep $Context 'AUDIO' ("Normalizando sonoridad (I={0}, TP={1}, LRA={2})" -f $li, $ltp, $llra)
        $mainFilter = 'loudnorm=I={0}:TP={1}:LRA={2}' -f $li, $ltp, $llra
    }
    else {
        # AACGAIN: se codifica sin ajuste y despues se aplica la ganancia sin perdida.
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[VOL] - [AACGAIN] - La ganancia se aplicara al m4a despues de codificar' }
    }

    # Cadena de filtros = sincronia (adelay, beta) + volumen; si no hay ninguno, mapeo directo.
    $chainParts = @()
    if ($syncFilter) { $chainParts += $syncFilter }
    if ($mainFilter) { $chainParts += $mainFilter }
    if ($chainParts.Count -gt 0) {
        $ffArgs += @('-filter_complex', ("[{0}]{1}[a]" -f $aLabel, ($chainParts -join ',')), '-map','[a]')
    } else {
        $ffArgs += $mapPre
    }

    # Codec de salida. '-aac_coder twoloop' es exclusivo del AAC nativo (coder de mayor calidad).
    # Opus solo admite 8/12/16/24/48 kHz -> se fuerza 48 kHz (44,1 kHz falla). FLAC es sin perdida
    # (el bitrate no aplica). El resto usa el samplerate del perfil y el bitrate como los demas.
    $arOut = if ($codec -eq 'libopus') { 48000 } else { $hz }
    $ffArgs += @('-c:a',$codec)
    if ($codec -eq 'aac') { $ffArgs += @('-aac_coder','twoloop') }
    $ffArgs += @('-ac',"$ch",'-ar',"$arOut")
    if ($Prof.AudioBitrate -and $codec -ne 'flac') { $ffArgs += @('-b:a',"$($Prof.AudioBitrate)") }
    # Modo pruebas: acotar la salida (si la fuente es el WAV clasico, ya viene recortado).
    if ($Context.TestLimit -gt 0 -and -not $fromWav) { $ffArgs += @('-t',"$($Context.TestLimit)") }
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
