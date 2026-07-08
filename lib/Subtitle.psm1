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
    param([Parameter(Mandatory)]$Stream, [object]$Default = $null)
    $isDefault = if ($null -ne $Default) { [bool]$Default } else { (Test-SubDefault $Stream) }
    [pscustomobject]@{
        Index   = [int]$Stream.index
        Lang    = (Get-Tag $Stream 'language')
        Title   = (Get-Tag $Stream 'title')
        Codec   = $Stream.codec_name
        Forced  = (Test-SubForced $Stream)
        Default = $isDefault
    }
}

function Show-SubtitlePreview {
    <#
        Reproduce un tramo del video CON un subtitulo concreto superpuesto (ffplay -sst s:N),
        para distinguir entre varios subtitulos (p. ej. normal vs SDH) antes de elegir.
        -SubPos: posicion 0-based entre las pistas de subtitulo.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$SubPos, [string]$Label = 'SUBTITULO', [int]$Seconds = -1, [int]$Start = -1, [double]$Duration = 0
    )
    $start = if ($Start -ge 0) { $Start } else { [int]$Context.PreviewStart }
    $start = Get-CvSafeStart -Start $start -Duration $Duration -Window 1
    if ($Seconds -lt 0) { $Seconds = [int]$Context.PreviewSeconds }
    $ffArgs = @('-hide_banner','-loglevel','error','-ss', "$start", '-t', "$Seconds", '-autoexit', '-sst', ("s:{0}" -f $SubPos))
    $ffArgs += @('-window_title', $Label, $File)
    Write-CvLog 'SUB' ("[TEST] - Reproduciendo con {0}; se cierra solo o pulsa ESC/Q" -f $Label) -Indent 3
    Invoke-ToolShow -Exe $Context.FFplay -Arguments $ffArgs -Context $Context -Preview | Out-Null
}

function Select-SubtitleInteractive {
    <#
        Menu para elegir el subtitulo principal cuando hay varios completos del mismo idioma.
        Permite REPRODUCIR el video con cada subtitulo ('P N', con segundo de inicio opcional)
        para distinguirlos (p. ej. normal vs SDH) antes de elegir.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$Info, [Parameter(Mandatory)]$Subs, [int]$DefaultIndex, [double]$Duration = 0
    )
    $lines = @()
    foreach ($s in $Subs) {
        $t = Get-Tag $s 'title'; $tt = ''; if ($t) { $tt = "'$t'" }
        $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
        $lines += ("{0} [{1}] idioma={2} codec={3} {4}" -f $mark, $s.index, (Get-Tag $s 'language'), $s.codec_name, $tt)
    }
    Show-Menu -Title 'SELECCIONAR SUBTITULO PRINCIPAL (mismo idioma) [* = por defecto]:' -Lines $lines -Indent 3
    while ($true) {
        $a = (Read-Host ("   [SUB] - Indice / 'P N'=ver con ese subtitulo (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }

        # Reproducir el video con el subtitulo N superpuesto; 3er numero = segundo de inicio.
        $mPlay = [regex]::Match($a, '^[Pp]\s*(\d+)(?:\s+(\d+))?$')
        if ($mPlay.Success) {
            $pi = [int]$mPlay.Groups[1].Value
            $st = if ($mPlay.Groups[2].Success) { [int]$mPlay.Groups[2].Value } else { -1 }
            $m = $Subs | Where-Object { [int]$_.index -eq $pi } | Select-Object -First 1
            if ($m) { Show-SubtitlePreview -Context $Context -File $File -SubPos (Get-SubtitleStreamPos -Info $Info -Index $pi) -Label ("SUBTITULO {0}" -f $pi) -Start $st -Duration $Duration }
            else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }

        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $m = $Subs | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            if ($m) { Write-Host ''; return $m }
        }
        Write-Host '   Indice no valido.' -ForegroundColor Yellow
    }
}

function Select-Subtitles {
    <#
        Devuelve la lista de subtitulos a conservar (por idioma preferido).
        - Forzados del idioma: se conservan todos.
        - Completos del idioma: 1 -> automatico; 2+ -> menu.
        - Si no hay subtitulos en el idioma: no se incluye ninguno.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Info, [ref]$Manual = $null)

    $subs = @(Get-SubtitleStreams -Info $Info)
    if ($subs.Count -eq 0) { if ($Context.Debug) { Write-CvLog 'SUB' '[INFO] - El archivo no tiene subtitulos' }; return @() }

    $pref = @($subs | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.SubLangs })
    if ($pref.Count -eq 0) {
        if ($Context.Debug) { Write-CvLog 'SUB' ("[INFO] - No hay subtitulos en el idioma preferido ({0} pistas de otros idiomas); no se incluyen" -f $subs.Count) }
        return @()
    }

    $forced = @($pref | Where-Object { Test-SubForced $_ })
    $full   = @($pref | Where-Object { -not (Test-SubForced $_) })

    $result = @()
    if ($full.Count -eq 1) {
        $result += (ConvertTo-SubSel $full[0] -Default $true)
    } elseif ($full.Count -gt 1) {
        if ($null -ne $Manual) { $Manual.Value = $true }   # se abre menu -> intervencion manual
        $chosen = Select-SubtitleInteractive -Context $Context -File $Info.format.filename -Info $Info -Subs $full -DefaultIndex ([int]$full[0].index) -Duration (Get-MediaDuration $Info)
        $result += (ConvertTo-SubSel $chosen -Default $true)
    }
    foreach ($fs in $forced) { $result += (ConvertTo-SubSel $fs) }

    if ($Context.Debug) {
        foreach ($r in $result) {
            $extra = ''
            if ($r.Forced)  { $extra += ' [forzados]' }
            if ($r.Default) { $extra += ' [principal]' }
            Write-CvLog 'SUB' ("[INFO] - Pista {0} ({1}, {2}){3}" -f $r.Index, $r.Lang, $r.Codec, $extra)
        }
    }
    return $result
}

Export-ModuleMember -Function *
