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

function ConvertTo-SubSel {
    <# Objeto de seleccion de subtitulo para guardar en el job. #>
    param([Parameter(Mandatory)]$Stream, [bool]$Default = $false)
    [pscustomobject]@{
        Index   = [int]$Stream.index
        Lang    = (Get-Tag $Stream 'language')
        Title   = (Get-Tag $Stream 'title')
        Codec   = $Stream.codec_name
        Forced  = (Test-SubForced $Stream)
        Default = $Default
    }
}

function Select-SubtitleInteractive {
    <# Menu para elegir el subtitulo principal cuando hay varios completos del mismo idioma. #>
    param([Parameter(Mandatory)]$Subs, [int]$DefaultIndex)
    $lines = @()
    foreach ($s in $Subs) {
        $t = Get-Tag $s 'title'; $tt = ''; if ($t) { $tt = "'$t'" }
        $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
        $lines += ("{0} [{1}] idioma={2} codec={3} {4}" -f $mark, $s.index, (Get-Tag $s 'language'), $s.codec_name, $tt)
    }
    Show-Menu -Title 'SELECCIONAR SUBTITULO PRINCIPAL (mismo idioma) [* = por defecto]:' -Lines $lines
    while ($true) {
        $a = (Read-Host ("[SUB] - Indice de pista [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }
        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $m = $Subs | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            if ($m) { return $m }
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
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Info)

    $subs = @(Get-SubtitleStreams -Info $Info)
    if ($subs.Count -eq 0) { Write-CvLog 'SUB' '[INFO] - El archivo no tiene subtitulos'; return @() }

    $pref = @($subs | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.SubLangs })
    if ($pref.Count -eq 0) {
        Write-CvLog 'SUB' ("[INFO] - No hay subtitulos en el idioma preferido ({0} pistas de otros idiomas); no se incluyen" -f $subs.Count)
        return @()
    }

    $forced = @($pref | Where-Object { Test-SubForced $_ })
    $full   = @($pref | Where-Object { -not (Test-SubForced $_) })

    $result = @()
    if ($full.Count -eq 1) {
        $result += (ConvertTo-SubSel $full[0] -Default $true)
    } elseif ($full.Count -gt 1) {
        $chosen = Select-SubtitleInteractive -Subs $full -DefaultIndex ([int]$full[0].index)
        $result += (ConvertTo-SubSel $chosen -Default $true)
    }
    foreach ($fs in $forced) { $result += (ConvertTo-SubSel $fs) }

    foreach ($r in $result) {
        $extra = ''
        if ($r.Forced)  { $extra += ' [forzados]' }
        if ($r.Default) { $extra += ' [principal]' }
        Write-CvLog 'SUB' ("[INFO] - Pista {0} ({1}, {2}){3}" -f $r.Index, $r.Lang, $r.Codec, $extra)
    }
    return $result
}

Export-ModuleMember -Function *
