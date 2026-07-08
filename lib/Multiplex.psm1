<#
    Multiplex.psm1 - Union final de las pistas en un MKV.
    Espejo de process_multiplex.cmd. Mejora: copia los subtitulos del original si existen.
#>

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
        $Subtitles = @()
    )
    $name  = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $out   = Get-OutputPath $Context $name
    $tmp   = Get-CvTempPaths -Context $Context -Name $name
    $vTmp  = $tmp.Video
    $aTmp  = $tmp.Audio

    # Fuente de video: recodificado si existe, si no el original (caso copy).
    $videoSrc = if (Test-Path -LiteralPath $vTmp) { $vTmp } else { $File }
    # Fuente de audio: m4a recodificado si existe, si no el original (caso copy).
    $useAudioFile = (Test-Path -LiteralPath $aTmp)

    # Subtitulos seleccionados en la fase preparar (filtramos posibles nulos del JSON).
    $subs    = @($Subtitles | Where-Object { $_ })
    $hasSubs = $subs.Count -gt 0
    # Adjuntos del original a conservar (fuentes/caratulas segun config; por defecto ninguno).
    $keepAtt = @(Select-Attachments -Context $Context -Info $Info)

    # El original ($File) hace falta como input si aporta subtitulos y/o adjuntos.
    $needOrig = $hasSubs -or ($keepAtt.Count -gt 0)

    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)")
    $ffArgs += @('-i',$videoSrc)                      # input 0 = video
    if ($useAudioFile) { $ffArgs += @('-i',$aTmp) }   # input 1 = audio (m4a)
    if ($needOrig)     { $ffArgs += @('-i',$File) }   # input N = original (subtitulos y/o adjuntos)
    $origInput = if ($useAudioFile) { 2 } else { 1 }

    # Limpiar TODOS los metadatos heredados de una sola vez: '-map_metadata -1' global tambien
    # vacia los tags de cada pista (ENCODER/_STATISTICS obsoletos que se copian al recodificar el
    # video, VENDOR_ID/HANDLER_NAME que anade el contenedor .m4a). '-fflags +bitexact' evita
    # ademas que ffmpeg escriba su propia etiqueta ENCODER global. Despues re-fijamos solo lo
    # que queremos (titulo/idioma/disposition).
    $ffArgs += @('-map_metadata','-1','-fflags','+bitexact')
    $ffArgs += @('-metadata','title=')

    # mapeo video: titulo en blanco, idioma indefinido
    $ffArgs += @('-map','0:v:0','-metadata:s:v','title=','-metadata:s:v','language=und')
    if ($useAudioFile) {
        # audio recodificado (m4a): titulo en blanco, idioma preferido
        $ffArgs += @('-map','1:a:0','-metadata:s:a','title=','-metadata:s:a','language=spa')
    } else {
        # audio copy: conservar los metadatos originales de la pista (idioma, titulo, stats)
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
    $ffArgs += @('-f','matroska',$out)

    Write-CvLog 'MULTIPLEX' 'Uniendo pistas...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    if ($code -ne 0) {
        Write-CvLog 'MULTIPLEX' ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        # Borrar la salida parcial para no darla por buena ni bloquear el reintento.
        if (Test-Path -LiteralPath $out) { Remove-Item -Force -LiteralPath $out -ErrorAction SilentlyContinue }
        return $false
    }

    if ((Test-Path -LiteralPath $out) -and ((Get-Item -LiteralPath $out).Length -gt 0)) {
        $mb = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)
        Write-CvLog 'MULTIPLEX' ("[OK] - {0}  ({1} MB)" -f (Split-Path $out -Leaf), $mb)
        # Limpiar las etiquetas DURATION que anade el muxer de Matroska (mkvpropedit).
        Remove-CvMkvTags -Context $Context -File $out
        return $true
    }
    return $false
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
    Write-CvLog 'MULTIPLEX' '[TAGS] - Limpiando etiquetas con mkvpropedit...'
    $r = Invoke-ToolCapture -Exe $mpe -Arguments @($File, '--tags', 'all:') -Context $Context
    if ($r.ExitCode -eq 0) { Write-CvLog 'MULTIPLEX' '[TAGS] - [OK] - Etiquetas eliminadas' }
    else { Write-CvLog 'MULTIPLEX' ("[AVISO] - mkvpropedit devolvio codigo {0}; las etiquetas pueden seguir" -f $r.ExitCode) }
}

Export-ModuleMember -Function *
