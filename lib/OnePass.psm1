<#
    OnePass.psm1 - Ejecucion en UNA sola pasada de ffmpeg (BETA).

    Funde las tres etapas del pipeline clasico (Audio -> Video -> Multiplex, cada una un proceso ffmpeg
    con temporales .m4a/.mka/.mkv) en un UNICO comando ffmpeg con -filter_complex: reencoda el video
    (crop/scale), recodifica y sincroniza el audio (adelay + downmix + loudnorm) y copia subtitulos,
    adjuntos y capitulos del original, escribiendo directamente Convertido\<name>_fix.mkv. Ahorra los
    temporales intermedios y dos arranques de ffmpeg.

    Solo aplica en un subconjunto de casos (Test-CvOnePassEligible); en el resto se usa el pipeline por
    etapas. Activador beta con doble llave: test.betaOnePass (Context.BetaOnePass), off por defecto.
#>

function Test-CvOnePassEligible {
    <#
        Decide si un job puede convertirse en UNA sola pasada. Devuelve {Ok=[bool]; Reason=[string]}
        (Reason = por que NO, para el log). Requisitos:
          - test.betaOnePass activo (doble llave beta).
          - Video y audio se CODIFICAN (ni video.skip ni audio.skip: 'copy' va por etapas).
          - Sincronia por 'adelay' (el modo clasico genera un WAV intermedio -> 2 pasadas).
          - Volumen 'loudnorm' (una pasada); 'peak' (mide antes) y 'aacgain' (aplica despues) obligan
            a una pasada extra por diseno.
          - Sin tone-mapping HDR->SDR (usa un hw device Vulkan/libplacebo que complica el filtergraph).
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Job, [Parameter(Mandatory)]$Prof)
    if (-not $Context.BetaOnePass) { return [pscustomobject]@{ Ok = $false; Reason = 'beta desactivada (test.betaOnePass)' } }
    if ([bool]$Job.video.skip)     { return [pscustomobject]@{ Ok = $false; Reason = 'video en modo copy' } }
    if ([bool]$Job.audio.skip)     { return [pscustomobject]@{ Ok = $false; Reason = 'audio en modo copy' } }
    if (-not $Context.SyncAdelay)  { return [pscustomobject]@{ Ok = $false; Reason = 'sincronia clasica (WAV), no adelay' } }
    $codec = "$($Prof.AudioCodec)".ToLower(); if (-not $codec) { $codec = 'aac' }
    $vm = Resolve-CvVolumeMethod -Method $Context.VolumeMethod -Codec $codec
    if ($vm.Method -ne 'loudnorm') { return [pscustomobject]@{ Ok = $false; Reason = ("volumen '{0}' (requiere loudnorm)" -f $vm.Method) } }
    if ([bool]$Job.video.hdr -and ("$($Context.TonemapHdr)".ToLower() -ne 'off')) { return [pscustomobject]@{ Ok = $false; Reason = 'tone-mapping HDR->SDR (requiere hw device)' } }
    return [pscustomobject]@{ Ok = $true; Reason = '' }
}

function Get-CvOnePassArgs {
    <#
        Construye (PURO: sin ejecutar ni loguear) el array de argumentos ffmpeg de la ejecucion unica.
        Un solo '-i' (el original) y un '-filter_complex' con la rama de video (crop -> scale) y una
        rama por pista de audio (adelay + downmix + loudnorm). Mapea el video/audio filtrados + los
        subtitulos/adjuntos/capitulos copiados del original, limpia los metadatos heredados
        ('-map_metadata -1 -fflags +bitexact') y re-fija idioma/titulo/disposition por pista. Es el
        espejo, fundido, de Invoke-VideoRun + Invoke-AudioRun + Invoke-Multiplex.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)][string]$File, [Parameter(Mandatory)]$Info,
        [Parameter(Mandatory)]$Job, [Parameter(Mandatory)][string]$Out
    )
    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    # ----- rama de VIDEO (crop -> scale; sin tonemap: la elegibilidad excluye HDR) -----
    $vIdx = if ($null -ne $Job.video.index) { [int]$Job.video.index } else { -1 }
    $vSrc = if ($vIdx -ge 0) { "0:$vIdx" } else { '0:v:0' }
    $vf   = Get-CvVideoFilterChain -Crop "$($Job.video.crop)" -Resize "$($Job.video.resize)" -Tonemap:$false
    $fc   = @()
    if ($vf.Count -gt 0) {
        $fc  += ("[{0}]{1}[v]" -f $vSrc, ($vf -join ','))
        $vmap = '[v]'
    } else {
        $vmap = $vSrc
    }

    # ----- ramas de AUDIO (una por pista) -----
    $codec = "$($Prof.AudioCodec)".ToLower(); if (-not $codec) { $codec = 'aac' }
    $hz    = if ($Prof.AudioHz) { $Prof.AudioHz } else { $Context.DefaultAudioHz }
    $arOut = if ($codec -eq 'libopus') { 48000 } else { $hz }   # Opus solo admite 8/12/16/24/48 kHz
    $li    = ([double]$Context.LoudnormI).ToString($inv)
    $ltp   = ([double]$Context.LoudnormTP).ToString($inv)
    $llra  = ([double]$Context.LoudnormLRA).ToString($inv)
    $dmMode = Resolve-CvDownmixMode $Prof.DownmixMode $Context.DownmixMode
    $coeffs = if ($null -ne $Prof.DownmixCoeffs) { $Prof.DownmixCoeffs } else { $Context.DownmixCoeffs }

    $aTracks = @(Get-CvJobAudioTracks -Audio $Job.audio)
    $aMaps   = @()   # -map + metadata + disposition por pista de salida
    $aCodec  = @()   # -ac:a:N / -ar:a:N / -b:a:N por pista (cada una con sus canales de origen)
    for ($ti = 0; $ti -lt $aTracks.Count; $ti++) {
        $t   = $aTracks[$ti]
        $idx = [int]$t.Index
        $aStream = @($Info.streams | Where-Object { [int]$_.index -eq $idx })[0]
        $srcCh   = if ($aStream -and $aStream.channels) { [int]$aStream.channels } else { 0 }
        # Canales de salida (MAXIMO, sin upmix): igual que Invoke-AudioRun.
        $chInfo  = Resolve-CvAudioChannels -ProfChannels $Prof.AudioChannels -GlobalChannels $Context.AudioChannels -SourceChannels $srcCh
        $ch = $chInfo.Channels
        # Downmix 5.1 -> estereo con voz reforzada (BETA, doble llave): solo si ch=2 + origen 5.1 +
        # downmixMode='dialogue' + test.betaDownmix. Si no, el downmix estandar lo hace '-ac:a:N'.
        $wantDialogue = ($ch -eq 2) -and [bool]$t.Is51 -and ($dmMode -eq 'dialogue')
        $downmix      = $wantDialogue -and $Context.BetaDownmix

        # Rama del filtro: sincronia (adelay) + downmix (pan) + volumen (loudnorm). loudnorm SIEMPRE
        # (la elegibilidad lo exige), asi que la rama nunca queda vacia.
        $parts = @()
        if ([double]$t.Sync -gt 0) { $parts += (Get-CvAdelayFilter ([double]$t.Sync)) }
        if ($downmix)              { $parts += (Get-CvDownmixPan -Coeffs $coeffs) }
        $parts += ('loudnorm=I={0}:TP={1}:LRA={2}' -f $li, $ltp, $llra)
        $fc += ("[0:{0}]{1}[a{2}]" -f $idx, ($parts -join ','), $ti)

        $aMaps += @('-map', ("[a{0}]" -f $ti))
        $aMaps += @(('-metadata:s:a:{0}' -f $ti), ("language={0}" -f $(if ($t.Lang) { $t.Lang } else { 'und' })))
        $aMaps += @(('-metadata:s:a:{0}' -f $ti), ("title={0}" -f (Resolve-CvAudioTitle -Keep $Context.AudioKeepTitle -Info $Info -Index $idx)))
        $aMaps += @(('-disposition:a:{0}' -f $ti), $(if ([bool]$t.Default) { 'default' } else { '0' }))

        # Opciones de codec POR PISTA (-ac:a:N etc.): cada pista puede tener distintos canales de origen.
        $aCodec += @(('-ac:a:{0}' -f $ti), "$ch", ('-ar:a:{0}' -f $ti), "$arOut")
        if ($Prof.AudioBitrate -and $codec -ne 'flac') { $aCodec += @(('-b:a:{0}' -f $ti), "$($Prof.AudioBitrate)") }
    }

    # ----- SUBTITULOS / ADJUNTOS (copiados del original, input 0) -----
    $subs    = @($Job.subtitles | Where-Object { $_ })
    $hasSubs = $subs.Count -gt 0
    $keepAtt = @(Select-Attachments -Context $Context -Info $Info)

    # ----- ensamblar el comando -----
    $ff  = @('-hide_banner','-y','-threads',"$($Context.Threads)",'-i',$File)
    $ff += @('-filter_complex', ($fc -join ';'))
    # Limpiar TODOS los metadatos heredados (global + por pista) y fijar los capitulos del original
    # (input 0). '+bitexact' evita que ffmpeg escriba su propia etiqueta ENCODER global.
    $ff += @('-map_metadata','-1','-fflags','+bitexact','-map_chapters','0','-metadata','title=')
    # video
    $ff += @('-map',$vmap,'-metadata:s:v','title=','-metadata:s:v','language=und')
    # audio (mapas + metadatos por pista)
    $ff += $aMaps
    # subtitulos (idioma + titulo Forzados/'' + disposition forced/default)
    if ($hasSubs) {
        $oi = 0
        foreach ($s in $subs) {
            $ff += @('-map', ("0:{0}?" -f [int]$s.Index))
            $ff += @(('-metadata:s:s:{0}' -f $oi), ("language={0}" -f $(if ($s.Lang) { $s.Lang } else { 'und' })))
            $ff += @(('-metadata:s:s:{0}' -f $oi), ("title={0}" -f $(if ($s.Forced) { 'Forzados' } else { '' })))
            $disp = @(); if ($s.Default) { $disp += 'default' }; if ($s.Forced) { $disp += 'forced' }
            $ff += @(('-disposition:s:{0}' -f $oi), $(if ($disp.Count -gt 0) { $disp -join '+' } else { '0' }))
            $oi++
        }
    }
    # adjuntos (Matroska EXIGE 'filename'; el -map_metadata -1 lo borra, se re-fija)
    $aj = 0
    foreach ($a in $keepAtt) {
        $ff += @('-map', ("0:{0}?" -f [int]$a.index))
        $fn = "$(Get-Tag $a 'filename')"; $mt = "$(Get-Tag $a 'mimetype')"
        if ($fn) { $ff += @(('-metadata:s:t:{0}' -f $aj), ("filename={0}" -f $fn)) }
        if ($mt) { $ff += @(('-metadata:s:t:{0}' -f $aj), ("mimetype={0}" -f $mt)) }
        $aj++
    }
    # codecs: video (Get-VideoArgs) + audio (codec global; -ac/-ar/-b:a por pista) + copy subs/adjuntos.
    $ff += (Get-VideoArgs -Context $Context -Prof $Prof -Anim ([bool]$Job.video.anim))
    $ff += @('-c:a',$codec)
    if ($codec -eq 'aac') { $ff += @('-aac_coder', $(if ("$($Context.AacCoder)") { "$($Context.AacCoder)" } else { 'twoloop' })) }   # coder AAC nativo (config)
    $ff += $aCodec
    if ($hasSubs)             { $ff += @('-c:s','copy') }
    if ($keepAtt.Count -gt 0) { $ff += @('-c:t','copy') }
    # Modo pruebas: acotar la salida a los primeros TestLimit segundos.
    if ($Context.TestLimit -gt 0) { $ff += @('-t',"$($Context.TestLimit)") }
    $ff += @('-f','matroska',$Out)
    return ,$ff
}

function Invoke-CvOnePass {
    <#
        Ejecuta la conversion en UNA sola pasada y escribe directamente Convertido\<name>_fix.mkv.
        Devuelve $true si crea la salida. Muestra progreso en vivo (como Invoke-VideoRun) y, al terminar,
        limpia las etiquetas DURATION con mkvpropedit (Remove-CvMkvTags). Fail-hard: si ffmpeg falla,
        borra la salida parcial y devuelve $false (el worker reintenta segun su politica).
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)][string]$File, [Parameter(Mandatory)]$Info, [Parameter(Mandatory)]$Job,
        [double]$Duration = 0
    )
    $name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $out  = Get-OutputPath $Context $name
    $ff   = Get-CvOnePassArgs -Context $Context -Prof $Prof -File $File -Info $Info -Job $Job -Out $out

    # Total del progreso: duracion (+ el mayor silencio de sincronia, que alarga la pista), acotado a -t.
    $aTracks = @(Get-CvJobAudioTracks -Audio $Job.audio)
    $maxSync = 0.0
    foreach ($t in $aTracks) { if ([double]$t.Sync -gt $maxSync) { $maxSync = [double]$t.Sync } }
    $total = [double]$Duration + $maxSync
    if ($Context.TestLimit -gt 0) { $total = [math]::Min($total, [double]$Context.TestLimit) }

    $global:CvLastToolError = $null   # el modo progreso lo rellena; se vuelca al log si ffmpeg falla
    if ($Context.Progress -and -not $Context.Debug -and $total -gt 0) {
        $code = Invoke-ToolProgress -Exe $Context.FFmpeg -Arguments $ff -Context $Context -Label 'Una sola pasada (video+audio)...' -TotalSeconds $total -ShowQ
    } else {
        Start-CvStep $Context 'UNA-PASADA' 'Codificando en una sola pasada...'
        $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ff -Context $Context
    }
    $ok = (($code -eq 0) -and (Test-Path -LiteralPath $out) -and ((Get-Item -LiteralPath $out).Length -gt 0))
    if (-not $ok) {
        Stop-CvStep $Context 'UNA-PASADA' $false -FailMsg ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        Show-CvToolError -Context $Context -Category 'UNA-PASADA' -Name $name -Tool 'ffmpeg-onepass'
        if (Test-Path -LiteralPath $out) { Remove-Item -Force -LiteralPath $out -ErrorAction SilentlyContinue }
        return $false
    }
    $mb = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)
    Stop-CvStep $Context 'UNA-PASADA' $true -OkMsg ("[OK] - {0}  ({1} MB)" -f (Split-Path $out -Leaf), $mb)
    # Limpiar las etiquetas DURATION que anade el muxer de Matroska (igual que el multiplex clasico).
    Remove-CvMkvTags -Context $Context -File $out
    return $true
}

Export-ModuleMember -Function *
