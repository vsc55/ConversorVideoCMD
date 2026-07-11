<#
    Subtitle.psm1 - Seleccion de subtitulos por idioma (simetrico con el audio).
    Fase ASK: elige que pistas conservar. El multiplex las mapea con sus metadatos.
#>

function Get-SubtitleStreams {
    param([Parameter(Mandatory)]$Info)
    @($Info.streams | Where-Object { $_.codec_type -eq 'subtitle' })
}

function Test-SubForced {
    <# Detecta si un subtitulo es "forzado" (para dialogo en otro idioma). #>
    param([Parameter(Mandatory)]$Stream)
    if ($Stream.PSObject.Properties['disposition'] -and $Stream.disposition -and $Stream.disposition.forced -eq 1) { return $true }
    $t = Get-Tag $Stream 'title'
    if ($t -and ($t -match 'forzad|forced')) { return $true }
    return $false
}

function Test-SubDefault {
    <# Lee el flag 'default' (pista predefinida) original del subtitulo. #>
    param([Parameter(Mandatory)]$Stream)
    return ($Stream.PSObject.Properties['disposition'] -and $Stream.disposition -and $Stream.disposition.default -eq 1)
}

function ConvertTo-SubSel {
    <#
        Objeto de seleccion de subtitulo para guardar en el job.
        -Default: $true/$false lo fuerza; si se omite ($null) se conserva el flag
        'default' ORIGINAL de la pista (asi un forzado que ya era predefinido lo sigue siendo).
    #>
    param([Parameter(Mandatory)]$Stream, [object]$Default = $null, [object]$Forced = $null)
    $isDefault = if ($null -ne $Default) { [bool]$Default } else { (Test-SubDefault $Stream) }
    $isForced  = if ($null -ne $Forced)  { [bool]$Forced }  else { (Test-SubForced $Stream) }
    [pscustomobject]@{
        Index   = [int]$Stream.index
        Lang    = (Get-Tag $Stream 'language')
        Title   = (Get-Tag $Stream 'title')
        Codec   = $Stream.codec_name
        Forced  = $isForced
        Default = $isDefault
    }
}

function Split-CvSubtitlesByRole {
    <#
        Clasifica los subtitulos (de un idioma) en FORZADOS y COMPLETOS. Primero por flag/titulo
        (Test-SubForced, fiable cuando existe); si NINGUNO esta marcado y hay 2+, se decide por
        TAMAÑO (nº de cues, Get-CvSubtitleCueCount): los notablemente mas pequeños (< 50% del
        maximo) son forzados. Con una sola pista -> completa. Devuelve @{ Forced; Complete }.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Info, [Parameter(Mandatory)]$Subs)
    $pref = @($Subs)
    $flagged = @($pref | Where-Object { Test-SubForced $_ })
    if ($flagged.Count -gt 0) {
        return @{ Forced = $flagged; Complete = @($pref | Where-Object { -not (Test-SubForced $_) }) }
    }
    if ($pref.Count -ge 2) {
        $counts = @{}
        foreach ($s in $pref) { $counts[[int]$s.index] = (Get-CvSubtitleCueCount -Context $Context -File $Info.format.filename -Index ([int]$s.index) -Stream $s) }
        $known = @($counts.Values | Where-Object { $_ -ge 0 })
        if ($known.Count -ge 1) {
            $max = ($known | Measure-Object -Maximum).Maximum
            if ($max -gt 0) {
                $f = @($pref | Where-Object { $counts[[int]$_.index] -ge 0 -and $counts[[int]$_.index] -lt ($max * 0.5) })
                return @{ Forced = $f; Complete = @($pref | Where-Object { $f -notcontains $_ }) }
            }
        }
    }
    return @{ Forced = @(); Complete = $pref }
}

function Show-SubtitlePreview {
    <#
        Reproduce el video CON un subtitulo concreto superpuesto (ffplay -sst s:N), para distinguir
        entre varios subtitulos (p. ej. normal vs SDH) antes de elegir. Por defecto desde el principio
        y sin limite (preview.start/seconds).
        -SubPos: posicion 0-based entre las pistas de subtitulo.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$SubPos, [string]$Label = 'SUBTITULO', [int]$Start = -1, [int]$Seconds = -1, [double]$Duration = 0
    )
    Write-CvLog 'SUB' ("[TEST] - Reproduciendo con {0}; se cierra solo o pulsa ESC/Q" -f $Label) -Indent 3
    Invoke-CvPreview -Context $Context -File $File -ExtraArgs @('-sst', ("s:{0}" -f $SubPos)) -Label $Label -Start $Start -Seconds $Seconds -Duration $Duration
}

function Show-SubtitleContent {
    <#
        Extrae una pista de subtitulo de texto a un .srt temporal y lo abre con el programa
        asociado de Windows (o Notepad). Las pistas de imagen (PGS/VobSub) no se pueden ver
        como texto: se avisa y no se extrae.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File, [Parameter(Mandatory)]$Stream)
    $idx   = [int]$Stream.index
    $codec = "$($Stream.codec_name)".ToLower()
    $textCodecs = @('subrip','srt','ass','ssa','mov_text','webvtt','text','eia_608','subviewer')
    if ($codec -notin $textCodecs) {
        Write-Host ("   La pista {0} es de imagen ({1}); no se puede ver como texto." -f $idx, $codec) -ForegroundColor Yellow
        return
    }
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cv_sub_{0}_{1}.srt" -f ([System.IO.Path]::GetFileNameWithoutExtension($File)), $idx)
    if (Test-Path -LiteralPath $tmp) { Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue }
    [void](Invoke-ToolCapture -Exe $Context.FFmpeg -Arguments @('-hide_banner','-loglevel','error','-y','-i',$File,'-map',"0:$idx",'-c:s','srt',$tmp) -Context $Context)
    if (Test-Path -LiteralPath $tmp) {
        Write-CvLog 'SUB' ("[TEST] - Abriendo subtitulo {0} en el editor de texto..." -f $idx) -Indent 3
        try { Start-Process -FilePath $tmp } catch { try { Start-Process -FilePath 'notepad.exe' -ArgumentList $tmp } catch {} }
    } else {
        Write-Host ("   No se pudo extraer la pista {0}." -f $idx) -ForegroundColor Yellow
    }
}

function Select-SubtitlesKeep {
    <#
        Fallback cuando hay subtitulos pero NINGUNO en el idioma preferido: muestra todos
        (idioma, codec, nº de cues) y deja elegir CUALES conservar (uno o varios). Se puede
        reproducir el video con un subtitulo ('P N', con segundo de inicio opcional) antes de
        elegir. Devuelve los SubSel elegidos (conservando idioma y disposition original),
        forzados primero. ENTER (vacio) = no conservar ninguno.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Info, [Parameter(Mandatory)]$Subs)
    $streams = @($Subs)
    $file = $Info.format.filename
    $dur  = Get-MediaDuration $Info
    $cues = @{}
    foreach ($s in $streams) { $cues[[int]$s.index] = (Get-CvSubtitleCueCount -Context $Context -File $file -Index ([int]$s.index) -Stream $s) }
    $to = Get-CvPromptTimeout $Context 'subtitle'   # auto-aceptar por inactividad (0 = off; al expirar = ninguno)

    while ($true) {
        $lines = @()
        foreach ($s in $streams) {
            $t = Get-Tag $s 'title'; $tt = ''; if ($t) { $tt = "'$t'" }
            $c = $cues[[int]$s.index]; $ctxt = if ($c -ge 0) { "$c cues" } else { '? cues' }
            $lines += ("[{0}] idioma={1} codec={2} ({3}) {4}" -f $s.index, (Get-Tag $s 'language'), $s.codec_name, $ctxt, $tt)
        }
        Show-Menu -Title 'SUBTITULOS (ninguno del idioma preferido) - elige cuales conservar:' -Lines ($lines + @('', "Indices separados por espacio (ej '3 5') / 'P N'=reproducir / 'V N'=ver texto / T=todos / ENTER=ninguno")) -Indent 3
        $a = (Read-CvMenuLine '   [SUB] - Opcion' $to).Trim()
        if ($a -eq '') { Write-Host ''; return @() }
        # 'V N' = ver el contenido del subtitulo N (extrae a .srt y abre con el editor asociado).
        $mView = [regex]::Match($a, '^[Vv]\s*(\d+)$')
        if ($mView.Success) {
            $vi = [int]$mView.Groups[1].Value
            $m = $streams | Where-Object { [int]$_.index -eq $vi } | Select-Object -First 1
            if ($m) { Show-SubtitleContent -Context $Context -File $file -Stream $m }
            else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }
        $play = ConvertFrom-CvPlayCommand $a
        if ($play) {
            $m = $streams | Where-Object { [int]$_.index -eq $play.Index } | Select-Object -First 1
            if ($m) { Show-SubtitlePreview -Context $Context -File $file -SubPos (Get-SubtitleStreamPos -Info $Info -Index $play.Index) -Label ("SUBTITULO {0}" -f $play.Index) -Start $play.Start -Duration $dur }
            else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }
        if ($a -match '^[Tt]$') { $chosen = $streams }
        else {
            $idx = @($a -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
            $chosen = @($streams | Where-Object { $idx -contains [int]$_.index })
            if ($chosen.Count -eq 0) { Write-Host '   Indices no validos.' -ForegroundColor Yellow; continue }
        }
        Write-Host ''
        $sel = @($chosen | ForEach-Object { ConvertTo-SubSel $_ })   # conserva forced/default originales
        return @(@($sel | Where-Object { $_.Forced }) + @($sel | Where-Object { -not $_.Forced }))
    }
}

function Select-Subtitles {
    <#
        Subtitulos a conservar. En el idioma preferido se clasifican en FORZADOS y COMPLETOS
        (por flag/titulo o, si no, por tamaño; ver Split-CvSubtitlesByRole) y se conservan TODOS,
        SIN menu: los forzados con disposition default+forced (titulo "Forzados" lo pone el
        multiplex), los completos sin flags ni titulo. Orden: forzados antes que completos.
        Si hay subtitulos pero NINGUNO del idioma preferido, se PREGUNTA cuales conservar.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Info, [ref]$Manual = $null)

    $subs = @(Get-SubtitleStreams -Info $Info)
    if ($subs.Count -eq 0) { if ($Context.Debug) { Write-CvLog 'SUB' '[INFO] - El archivo no tiene subtitulos' }; return @() }

    $pref = @($subs | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.SubLangs })
    if ($pref.Count -eq 0) {
        Write-CvLog 'SUB' ("[AVISO] - Ningun subtitulo en el idioma preferido ({0}); elige cuales conservar." -f ($Context.SubLangs | Select-Object -First 1)) -Indent 3
        if ($null -ne $Manual) { $Manual.Value = $true }
        return (Select-SubtitlesKeep -Context $Context -Info $Info -Subs $subs)
    }

    $roles    = Split-CvSubtitlesByRole -Context $Context -Info $Info -Subs $pref
    $forced   = @($roles.Forced)
    $complete = @($roles.Complete)
    if ($complete.Count -gt 1) {
        Write-CvLog 'SUB' ("[AVISO] - {0} subtitulos completos en el idioma preferido; se conservan todos (ninguno marcado como principal)." -f $complete.Count) -Indent 3
    }

    # Forzados primero (default+forced); luego completos (sin default ni forced).
    $result = @()
    foreach ($s in $forced)   { $result += (ConvertTo-SubSel $s -Forced $true  -Default $true) }
    foreach ($s in $complete) { $result += (ConvertTo-SubSel $s -Forced $false -Default $false) }

    if ($Context.Debug) {
        foreach ($r in $result) {
            $rol = if ($r.Forced) { 'forzado' } else { 'completo' }
            Write-CvLog 'SUB' ("[INFO] - Pista {0} ({1}, {2}) - {3}" -f $r.Index, $r.Lang, $r.Codec, $rol)
        }
    }
    return $result
}

Export-ModuleMember -Function *
