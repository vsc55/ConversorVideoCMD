<#
    Multiplex.psm1 - Union final de las pistas en un MKV.
    Espejo de process_multiplex.cmd. Mejora: copia los subtitulos del original si existen.
#>

function Resolve-CvMuxInputIndex {
    <#
        Indices de input del multiplex. El input 0 es el video; los N audios recodificados van como
        inputs 1..N; el ORIGINAL (subs/adjuntos/capitulos/audio copy) va al final. Devuelve {Orig;Chap}:
        Orig = indice del original (1 + N audios temporales); Chap = fuente de capitulos (el original si
        el video se recodifico, o el input 0 en modo copy, donde el propio video ya es el original).
    #>
    param([int]$TempAudioCount, [bool]$IsEncode)
    $orig = 1 + $TempAudioCount
    [pscustomobject]@{ Orig = $orig; Chap = $(if ($IsEncode) { $orig } else { 0 }) }
}

function Invoke-Multiplex {
    <#
        Une video (temporal recodificado o el original si es copy) + audio (m4a) en Convertido\<name>_fix.mkv.
        Devuelve $true si crea la salida.
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$Info,
        [bool]$VideoSkipped = $false,
        [bool]$AudioSkipped = $false,
        $Subtitles = @(),
        # Pistas de audio a incluir (multipista): [{Source='temp'|'copy'; File; Index; Lang; Title; Default}].
        # La DEFAULT va PRIMERO (asi las ordena el worker). Vacio + AudioSkipped -> copy clasico de 0:a:0.
        $AudioTracks = @(),
        [int]$VideoIndex = -1
    )
    $name  = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $out   = Get-OutputPath $Context $name
    $tmp   = Get-CvTempPaths -Context $Context -Name $name
    $vTmp  = $tmp.Video

    # Fuente de video: recodificado si existe, si no el original (caso copy).
    $videoSrc = if (Test-Path -LiteralPath $vTmp) { $vTmp } else { $File }

    # Pistas de audio: recodificadas (temporal por pista) vs copia (indice del original).
    $audioT    = @($AudioTracks | Where-Object { $_ })
    $tempAudio = @($audioT | Where-Object { "$($_.Source)" -eq 'temp' -and (Test-Path -LiteralPath "$($_.File)") })
    $copyAudio = @($audioT | Where-Object { "$($_.Source)" -eq 'copy' })
    # copy CLASICO (sin lista de pistas): AudioSkipped y ninguna pista -> se copia 0:a:0 del original.
    $legacyCopy = (($audioT.Count -eq 0) -and $AudioSkipped)

    # Subtitulos seleccionados en la fase preparar (filtramos posibles nulos del JSON).
    $subs    = @($Subtitles | Where-Object { $_ })
    $hasSubs = $subs.Count -gt 0
    # Adjuntos del original a conservar (fuentes/caratulas segun config; por defecto ninguno).
    $keepAtt = @(Select-Attachments -Context $Context -Info $Info)

    # El original ($File) hace falta como input si aporta subtitulos/adjuntos, si el video se recodifico
    # (el intermedio se creo con -map_chapters -1, asi que los CAPITULOS se toman del original), o si hay
    # audio en modo COPIA (se toma del original) o el copy clasico 0:a:0. En copy el video ya es el
    # original (input 0). Los audios recodificados van como inputs 1..M (uno por pista).
    $isEncode = (Test-Path -LiteralPath $vTmp)
    $needCopyAudio = ($copyAudio.Count -gt 0) -or $legacyCopy
    $needOrig = $hasSubs -or ($keepAtt.Count -gt 0) -or $isEncode -or $needCopyAudio

    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)")
    $ffArgs += @('-i',$videoSrc)                                    # input 0 = video
    foreach ($a in $tempAudio) { $ffArgs += @('-i', "$($a.File)") } # inputs 1..M = audios recodificados
    if ($needOrig) { $ffArgs += @('-i',$File) }                     # input N = original (subs/adjuntos/capitulos/audio copy)
    # Indices de input (original / fuente de capitulos): Resolve-CvMuxInputIndex.
    $mi = Resolve-CvMuxInputIndex -TempAudioCount $tempAudio.Count -IsEncode $isEncode
    $origInput = $mi.Orig
    $chapInput = $mi.Chap

    # Limpiar TODOS los metadatos heredados de una sola vez: '-map_metadata -1' global tambien
    # vacia los tags de cada pista (ENCODER/_STATISTICS obsoletos que se copian al recodificar el
    # video, VENDOR_ID/HANDLER_NAME que anade el contenedor .m4a). '-fflags +bitexact' evita
    # ademas que ffmpeg escriba su propia etiqueta ENCODER global. Despues re-fijamos solo lo
    # que queremos (titulo/idioma/disposition). '-map_chapters' conserva los capitulos del original
    # (el -map_metadata -1 no los borra, pero fijamos la fuente explicitamente).
    $ffArgs += @('-map_metadata','-1','-fflags','+bitexact','-map_chapters',"$chapInput")
    $ffArgs += @('-metadata','title=')

    # mapeo video: titulo en blanco, idioma indefinido.
    #  - Encode: $videoSrc es el intermedio recodificado (1 sola pista) -> '0:v:0'.
    #  - Copy:   $videoSrc es el original -> mapear la pista elegida por su indice absoluto
    #            ('0:<VideoIndex>'), no '0:v:0' (que podria ser una caratula o la pista equivocada).
    $vmap = if ((Test-Path -LiteralPath $vTmp) -or ($VideoIndex -lt 0)) { '0:v:0' } else { "0:$VideoIndex" }
    $ffArgs += @('-map',$vmap,'-metadata:s:v','title=','-metadata:s:v','language=und')

    # ----- AUDIO (multipista) -----
    # La lista ya viene con la DEFAULT primero (la ordena el worker). Se mapea cada pista, se fija el
    # idioma y la disposition (default segun el flag). El TITULO lo resuelve Resolve-CvAudioTitle:
    # por defecto en BLANCO; si encode.audioKeepTitle=$true, el del ORIGEN (por indice de la pista;
    # util para distinguir varias del mismo idioma).
    $ao = 0
    if ($tempAudio.Count -gt 0) {
        # Audios recodificados: cada uno es el input ($ao+1), pista a:0 de ese input.
        foreach ($a in $tempAudio) {
            $ffArgs += @('-map', ("{0}:a:0" -f ($ao + 1)))
            $ffArgs += @(('-metadata:s:a:{0}' -f $ao), ("language={0}" -f $(if ($a.Lang) { $a.Lang } else { 'und' })))
            $ffArgs += @(('-metadata:s:a:{0}' -f $ao), ("title={0}" -f (Resolve-CvAudioTitle -Keep $Context.AudioKeepTitle -Info $Info -Index ([int]$a.Index))))
            $ffArgs += @(('-disposition:a:{0}' -f $ao), $(if ($a.Default) { 'default' } else { '0' }))
            $ao++
        }
    }
    elseif ($copyAudio.Count -gt 0) {
        # Audios en COPIA: por indice absoluto del original (input $origInput), sin recodificar.
        foreach ($a in $copyAudio) {
            $ffArgs += @('-map', ("{0}:{1}?" -f $origInput, [int]$a.Index))
            $ffArgs += @(('-metadata:s:a:{0}' -f $ao), ("language={0}" -f $(if ($a.Lang) { $a.Lang } else { 'und' })))
            $ffArgs += @(('-metadata:s:a:{0}' -f $ao), ("title={0}" -f (Resolve-CvAudioTitle -Keep $Context.AudioKeepTitle -Info $Info -Index ([int]$a.Index))))
            $ffArgs += @(('-disposition:a:{0}' -f $ao), $(if ($a.Default) { 'default' } else { '0' }))
            $ao++
        }
    }
    else {
        # copy CLASICO (monopista): primera pista de audio del original, conservando sus metadatos.
        $ffArgs += @('-map','0:a:0','-map_metadata:s:a:0','0:s:a:0')
    }

    # mapeo subtitulos seleccionados (con idioma y flags forced/default)
    if ($hasSubs) {
        $subInput = $origInput
        $oi = 0
        foreach ($s in $subs) {
            $ffArgs += @('-map', ("{0}:{1}?" -f $subInput, [int]$s.Index))
            $lang = if ($s.Lang) { $s.Lang } else { 'und' }
            $ffArgs += @(('-metadata:s:s:{0}' -f $oi), ("language={0}" -f $lang))
            # Titulo de la pista: 'Forzados' si es forzada, en blanco si es completa.
            $title = if ($s.Forced) { 'Forzados' } else { '' }
            $ffArgs += @(('-metadata:s:s:{0}' -f $oi), ("title={0}" -f $title))
            $disp = @()
            if ($s.Default) { $disp += 'default' }
            if ($s.Forced)  { $disp += 'forced' }
            $dstr = if ($disp.Count -gt 0) { ($disp -join '+') } else { '0' }
            $ffArgs += @(('-disposition:s:{0}' -f $oi), $dstr)
            $oi++
        }
    }

    # mapeo de adjuntos elegidos (por indice en el original). El '-map_metadata -1' borra su
    # 'filename'/'mimetype', y el muxer de Matroska EXIGE 'filename', asi que se re-fijan.
    $aj = 0
    foreach ($a in $keepAtt) {
        $ffArgs += @('-map', ("{0}:{1}?" -f $origInput, [int]$a.index))
        $fn = "$(Get-Tag $a 'filename')"
        $mt = "$(Get-Tag $a 'mimetype')"
        if ($fn) { $ffArgs += @(('-metadata:s:t:{0}' -f $aj), ("filename={0}" -f $fn)) }
        if ($mt) { $ffArgs += @(('-metadata:s:t:{0}' -f $aj), ("mimetype={0}" -f $mt)) }
        $aj++
    }

    $ffArgs += @('-c:v','copy','-c:a','copy')
    if ($hasSubs)             { $ffArgs += @('-c:s','copy') }
    if ($keepAtt.Count -gt 0) { $ffArgs += @('-c:t','copy') }
    # Modo pruebas: acotar la salida final. Imprescindible en perfil copy (el video se copia del
    # original a longitud COMPLETA, mientras el audio recodificado ya viene a TestLimit); tambien
    # recorta subtitulos/capitulos al mismo tramo. En encode el video ya es corto (-t es inocuo).
    if ($Context.TestLimit -gt 0) { $ffArgs += @('-t',"$($Context.TestLimit)") }
    $ffArgs += @('-f','matroska',$out)

    Start-CvStep $Context 'MULTIPLEX' 'Uniendo pistas...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    $ok = (($code -eq 0) -and (Test-Path -LiteralPath $out) -and ((Get-Item -LiteralPath $out).Length -gt 0))
    $mbTxt = if ($ok) { ("({0} MB)" -f [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)) } else { '' }
    Stop-CvStep $Context 'MULTIPLEX' $ok -Extra $mbTxt -OkMsg ("[OK] - {0}  {1}" -f (Split-Path $out -Leaf), $mbTxt) -FailMsg ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
    if (-not $ok) {
        # Borrar la salida parcial para no darla por buena ni bloquear el reintento.
        if (Test-Path -LiteralPath $out) { Remove-Item -Force -LiteralPath $out -ErrorAction SilentlyContinue }
        return $false
    }
    # Limpiar las etiquetas DURATION que anade el muxer de Matroska (mkvpropedit).
    Remove-CvMkvTags -Context $Context -File $out
    return $true
}

function Remove-CvMkvTags {
    <#
        Elimina TODAS las etiquetas del MKV con mkvpropedit (MKVToolNix), sin recodificar y
        conservando Cues/duracion/dispositions. Quita los tags 'DURATION' por pista que el
        muxer de ffmpeg escribe al cerrar el fichero (ffmpeg no tiene flag para omitirlos).
        Se controla con config 'postprocess.stripTags' y la ruta 'postprocess.mkvpropedit'.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File)
    if (-not $Context.StripTags) { return }
    $mpe = "$($Context.MkvPropEdit)"
    # Si no es un override manual y falta, descargar mkvtoolnix (y su extractor 7zr) la 1a vez.
    if ((-not (Test-Path -LiteralPath $mpe)) -and [string]::IsNullOrWhiteSpace("$($Context.MkvPropEditOverride)")) {
        $app = Get-CvAppDescriptor -Context $Context -Name 'mkvtoolnix'
        if ($app) { [void](Confirm-CvTool -Context $Context -Name 'mkvtoolnix' -Version "$($app.selected)") }
    }
    if ([string]::IsNullOrWhiteSpace($mpe) -or -not (Test-Path -LiteralPath $mpe)) {
        Write-CvLog 'MULTIPLEX' '[AVISO] - mkvpropedit no disponible: quedan las etiquetas DURATION'
        return
    }
    Start-CvStep $Context 'MULTIPLEX' 'Limpiando etiquetas con mkvpropedit...'
    $r = Invoke-ToolCapture -Exe $mpe -Arguments @($File, '--tags', 'all:') -Context $Context
    Stop-CvStep $Context 'MULTIPLEX' ($r.ExitCode -eq 0) -OkMsg '[TAGS] - [OK] - Etiquetas eliminadas' -FailMsg ("[AVISO] - mkvpropedit devolvio codigo {0}; las etiquetas pueden seguir" -f $r.ExitCode)
}

Export-ModuleMember -Function *
