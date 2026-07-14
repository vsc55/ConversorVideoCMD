<#
    Render.psm1 - Spec de renderizado (job -> decisiones estructuradas).

    Resolve-CvRenderSpec calcula UNA sola vez, a partir del job/perfil/contexto, TODAS las decisiones de
    codificacion (rama de video, pistas de audio con canales/sync/downmix/idioma/titulo/default, subtitulos,
    adjuntos, codecs, salida), sin emitir ningun argumento de ffmpeg ni ejecutar nada (PURA salvo la sonda de
    adjuntos via ffprobe que ya hace Select-Attachments). Los EMISORES (Get-CvOnePassArgs para una pasada;
    a futuro un emisor por etapas) renderizan ESE spec a comandos concretos. Asi la DECISION vive en un sitio
    y solo bifurca la EMISION (3 procesos por etapas vs 1 con filter_complex en una pasada).
#>

function Resolve-CvRenderSpec {
    <#
        Devuelve el spec de render del job. Campos:
          Video      = {Index; SrcPad; Filters[]; Hdr; Anim}   (Filters = crop/scale, SIN tonemap: lo
                       resuelve el emisor segun el modo; la elegibilidad de una pasada excluye HDR).
          Audio      = [{Index; SourceChannels; Is51; Channels; Sync; DownmixPan; Lang; Title; Default; Ar;
                       Bitrate}]  (pista de salida; la DEFAULT va primero, como la ordena el worker).
                       SourceChannels/Is51 = entradas de la decision (las reusa el pipeline por etapas);
                       Ar = samplerate de salida.
          AudioCodec = codec de recodificacion (aac por defecto). AacCoder = coder AAC nativo si aac (si no '').
          Loudnorm   = filtro loudnorm ya montado (metodo de volumen de una pasada; fuente unica).
          Subtitles / Attachments = colecciones a copiar del original (idioma/titulo/disposition ya en el job;
                       filename/mimetype en el adjunto). TestLimit = -t del modo pruebas (0 = sin limite).
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)]$Job, [Parameter(Mandatory)]$Info
    )
    # ----- VIDEO -----
    $vIdx = if ($null -ne $Job.video.index) { [int]$Job.video.index } else { -1 }
    $vSrc = if ($vIdx -ge 0) { "0:$vIdx" } else { '0:v:0' }
    $vFilters = Get-CvVideoFilterChain -Crop "$($Job.video.crop)" -Resize "$($Job.video.resize)" -Tonemap:$false
    $video = [pscustomobject]@{
        Index   = $vIdx
        SrcPad  = $vSrc
        Filters = @($vFilters)
        Hdr     = [bool]$Job.video.hdr
        Anim    = [bool]$Job.video.anim
    }

    # ----- AUDIO (una entrada por pista de salida) -----
    $codec = "$($Prof.AudioCodec)".ToLower(); if (-not $codec) { $codec = 'aac' }
    $hz    = if ($Prof.AudioHz) { $Prof.AudioHz } else { $Context.DefaultAudioHz }
    $arOut = if ($codec -eq 'libopus') { 48000 } else { $hz }   # Opus solo admite 8/12/16/24/48 kHz
    $bitrate = if ($Prof.AudioBitrate -and $codec -ne 'flac') { "$($Prof.AudioBitrate)" } else { '' }
    $audio = @()
    foreach ($t in @(Get-CvJobAudioTracks -Audio $Job.audio)) {
        $idx     = [int]$t.Index
        $aStream = @($Info.streams | Where-Object { [int]$_.index -eq $idx })[0]
        $srcCh   = if ($aStream -and $aStream.channels) { [int]$aStream.channels } else { 0 }
        $plan    = Resolve-CvAudioTrackPlan -Context $Context -Prof $Prof -SourceChannels $srcCh -Is51 ([bool]$t.Is51)
        $audio += [pscustomobject]@{
            Index          = $idx
            SourceChannels = $srcCh
            Is51           = [bool]$t.Is51
            Channels       = $plan.Channels
            Sync           = [double]$t.Sync
            DownmixPan     = $plan.DownmixPan
            Lang           = $(if ($t.Lang) { "$($t.Lang)" } else { 'und' })
            Title          = (Resolve-CvAudioTitle -Keep $Context.AudioKeepTitle -Info $Info -Index $idx)
            Default        = [bool]$t.Default
            Ar             = $arOut
            Bitrate        = $bitrate
        }
    }

    [pscustomobject]@{
        Video       = $video
        Audio       = @($audio)
        AudioCodec  = $codec
        AacCoder    = $(if ($codec -eq 'aac') { $(if ("$($Context.AacCoder)") { "$($Context.AacCoder)" } else { 'twoloop' }) } else { '' })
        Loudnorm    = (Get-CvLoudnormFilter -I $Context.LoudnormI -TP $Context.LoudnormTP -LRA $Context.LoudnormLRA)
        Subtitles   = @($Job.subtitles | Where-Object { $_ })
        Attachments = @(Select-Attachments -Context $Context -Info $Info)
        TestLimit   = [int]$Context.TestLimit
    }
}

Export-ModuleMember -Function *
