<#
    MediaInfo.psm1 - Informacion de streams via ffprobe con salida JSON.
    Sustituye a los antiguos AudioGetID.vbs / VideoSizeReal_*.vbs / parseos con findstr.
#>

function Get-Tag {
    <# Lee un tag de un stream de forma segura (ffprobe puede no traer .tags). #>
    param($Stream, [string]$Name)
    if ($null -eq $Stream) { return $null }
    if ($Stream.PSObject.Properties['tags'] -and $Stream.tags -and $Stream.tags.PSObject.Properties[$Name]) {
        return $Stream.tags.$Name
    }
    return $null
}

function Get-MediaInfo {
    <# Devuelve el objeto JSON de ffprobe (streams + format) o $null si falla. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File)
    $r = Invoke-ToolCapture -Exe $Context.FFprobe -Arguments @(
        '-v','quiet','-print_format','json','-show_streams','-show_format', $File
    ) -Context $Context
    if ($r.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($r.StdOut)) { return $null }
    try { return ($r.StdOut | ConvertFrom-Json) } catch { return $null }
}

function Get-VideoStreams {
    <#
        Pistas de video REALES: excluye caratulas/portadas incrustadas (disposition.attached_pic
        y codecs de imagen: mjpeg/png/bmp/gif/webp), que ffprobe lista como codec_type=video.
    #>
    param([Parameter(Mandatory)]$Info)
    @($Info.streams | Where-Object {
        $_.codec_type -eq 'video' -and
        $_.codec_name -notin @('mjpeg','png','bmp','gif','webp') -and
        -not ($_.disposition -and $_.disposition.attached_pic -eq 1)
    })
}

function Get-VideoStream {
    <# Primera pista de video real (excluye caratulas). #>
    param([Parameter(Mandatory)]$Info)
    @(Get-VideoStreams -Info $Info) | Select-Object -First 1
}

function Get-VideoStreamPos {
    <#
        Posicion 0-based de una pista (por su indice absoluto) entre TODAS las de codec_type=video
        (incluye caratulas), para el stream specifier 'v:N' de ffplay (-vst).
    #>
    param([Parameter(Mandatory)]$Info, [int]$Index)
    $all = @($Info.streams | Where-Object { $_.codec_type -eq 'video' })
    for ($i = 0; $i -lt $all.Count; $i++) { if ([int]$all[$i].index -eq $Index) { return $i } }
    return 0
}

function Select-AudioStream {
    <#
        Selecciona la pista de audio siguiendo la misma preferencia que AudioGetID.vbs:
        (spa) > (default) > 5.1 > primera pista.
        Devuelve un objeto con Index, Language, Channels, Is51.
    #>
    param([Parameter(Mandatory)]$Info, [string[]]$PrefLangs = @('spa'))
    $aud = @($Info.streams | Where-Object { $_.codec_type -eq 'audio' })
    if ($aud.Count -eq 0) { return $null }

    $pick = $null
    $spa = @($aud | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $PrefLangs })
    if ($spa.Count -gt 0) {
        $pick = ($spa | Where-Object { $_.channels -ge 6 } | Select-Object -First 1)
        if ($null -eq $pick) { $pick = $spa[0] }
    }
    if ($null -eq $pick) {
        $def = @($aud | Where-Object { $_.disposition -and $_.disposition.default -eq 1 })
        if ($def.Count -gt 0) { $pick = $def[0] }
    }
    if ($null -eq $pick) {
        $s51 = @($aud | Where-Object { $_.channels -ge 6 })
        if ($s51.Count -gt 0) { $pick = $s51[0] }
    }
    if ($null -eq $pick) { $pick = $aud[0] }

    return (ConvertTo-AudioSel $pick)
}

function ConvertTo-AudioSel {
    <# Construye el objeto de seleccion {Index,Language,Channels,Is51} a partir de un stream. #>
    param([Parameter(Mandatory)]$Stream)
    [pscustomobject]@{
        Index    = [int]$Stream.index
        Language = (Get-Tag $Stream 'language')
        Channels = [int]$Stream.channels
        Is51     = ([int]$Stream.channels -ge 6)
    }
}

function Get-AudioStreams {
    <# Devuelve todas las pistas de audio del contenedor. #>
    param([Parameter(Mandatory)]$Info)
    @($Info.streams | Where-Object { $_.codec_type -eq 'audio' })
}

function Get-VideoSize {
    <# "AnchoxAlto" del stream de video. #>
    param([Parameter(Mandatory)]$VideoStream)
    "{0}x{1}" -f [int]$VideoStream.width, [int]$VideoStream.height
}

function Get-DurationText {
    <# Duracion formateada H:MM:SS a partir de format.duration (segundos). #>
    param([Parameter(Mandatory)]$Info)
    $sec = $null
    if ($Info.PSObject.Properties['format'] -and $Info.format.PSObject.Properties['duration']) {
        $sec = ConvertTo-InvDouble $Info.format.duration
    }
    if ($null -eq $sec) { return '?' }
    $ts = [TimeSpan]::FromSeconds([math]::Floor($sec))
    return ('{0}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds)
}

function Write-ConversionSummary {
    <# Muestra un resumen enmarcado al terminar la conversion de un archivo. #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$Info,
        [Parameter(Mandatory)][string]$Output,
        [TimeSpan]$Elapsed = [TimeSpan]::Zero
    )
    $name = [System.IO.Path]::GetFileName($File)

    $origBytes = (Get-Item -LiteralPath $File).Length
    $outBytes  = 0
    if (Test-Path -LiteralPath $Output) { $outBytes = (Get-Item -LiteralPath $Output).Length }
    $origMB = [math]::Round($origBytes / 1MB, 1)
    $outMB  = [math]::Round($outBytes  / 1MB, 1)
    $ahorro = if ($origBytes -gt 0) { [math]::Round(100 * (1 - ($outBytes / $origBytes)), 1) } else { 0 }

    $vs      = Get-VideoStream -Info $Info
    $origRes = if ($vs) { Get-VideoSize -VideoStream $vs } else { '?' }
    $origVc  = if ($vs) { $vs.codec_name } else { '?' }

    $oInfo = Get-MediaInfo -Context $Context -File $Output
    $ov = $null; $oa = $null
    if ($oInfo) {
        $ov = Get-VideoStream -Info $oInfo
        $oa = @($oInfo.streams | Where-Object { $_.codec_type -eq 'audio' })[0]
    }
    $outRes = if ($ov) { Get-VideoSize -VideoStream $ov } else { '?' }
    $outVc  = if ($ov) { $ov.codec_name } else { '?' }
    $outAc  = if ($oa) { $oa.codec_name } else { '?' }
    $outAch = if ($oa) { "$($oa.channels)ch" } else { '?' }
    $outAbr = ''
    if ($oa -and $oa.PSObject.Properties['bit_rate'] -and $oa.bit_rate) {
        $outAbr = " {0}k" -f [math]::Round(([double]$oa.bit_rate) / 1000)
    }

    $lines = @(
        ("Archivo : {0}" -f $name),
        ("Duracion: {0}     Tiempo de proceso: {1:hh\:mm\:ss}" -f (Get-DurationText $Info), $Elapsed),
        '',
        ("Tamano  : {0} MB  ->  {1} MB   (ahorro {2}%)" -f $origMB, $outMB, $ahorro),
        ("Video   : {0} {1}  ->  {2} {3}" -f $origVc, $origRes, $outVc, $outRes),
        ("Audio   : {0} {1}{2}" -f $outAc, $outAch, $outAbr)
    )
    # Sin encuadrar: los cuadros recortan las lineas largas (p.ej. el nombre del archivo).
    $dash = '-' * 64
    $eq   = '=' * 64
    Write-Host ''
    Write-Host $dash
    Write-Host 'RESUMEN DE LA CONVERSION'
    Write-Host $dash
    $lines | ForEach-Object { Write-Host $_ }
    Write-Host $eq
    Write-Host ''
}

Export-ModuleMember -Function *
