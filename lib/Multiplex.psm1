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
    $vTmp  = Join-Path $Context.Proceso ("{0}.mkv" -f $name)
    $aTmp  = Join-Path $Context.Proceso ("{0}.m4a" -f $name)

    # Fuente de video: recodificado si existe, si no el original (caso copy).
    $videoSrc = if (Test-Path -LiteralPath $vTmp) { $vTmp } else { $File }
    # Fuente de audio: m4a recodificado si existe, si no el original (caso copy).
    $useAudioFile = (Test-Path -LiteralPath $aTmp)

    # Subtitulos seleccionados en la fase preparar (filtramos posibles nulos del JSON).
    $subs    = @($Subtitles | Where-Object { $_ })
    $hasSubs = $subs.Count -gt 0

    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)")
    $ffArgs += @('-i',$videoSrc)                      # input 0 = video
    if ($useAudioFile) { $ffArgs += @('-i',$aTmp) }   # input 1 = audio (m4a)
    if ($hasSubs)      { $ffArgs += @('-i',$File) }   # input N = subtitulos del original

    # metadatos base
    $ffArgs += @('-metadata','title=', '-metadata:s:v','title=', '-metadata:s:v','language=und')

    # mapeo video/audio
    $ffArgs += @('-map','0:v:0')
    if ($useAudioFile) {
        $ffArgs += @('-map','1:a:0','-metadata:s:a','title=','-metadata:s:a','language=spa')
    } else {
        # audio copy: coger el audio del propio video/original de input 0
        $ffArgs += @('-map','0:a:0')
    }

    # mapeo subtitulos seleccionados (con idioma y flags forced/default)
    if ($hasSubs) {
        $subInput = if ($useAudioFile) { 2 } else { 1 }
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

    $ffArgs += @('-c:v','copy','-c:a','copy')
    if ($hasSubs) { $ffArgs += @('-c:s','copy') }
    $ffArgs += @('-f','matroska',$out)

    Write-CvLog 'MULTIPLEX' 'Uniendo pistas...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    if ($code -ne 0) { Write-CvLog 'MULTIPLEX' ("[ERR] - ffmpeg devolvio codigo {0}" -f $code) }

    if (Test-Path -LiteralPath $out) {
        $mb = [math]::Round((Get-Item -LiteralPath $out).Length / 1MB, 1)
        Write-CvLog 'MULTIPLEX' ("[OK] - {0}  ({1} MB)" -f (Split-Path $out -Leaf), $mb)
        return $true
    }
    return $false
}

Export-ModuleMember -Function *
