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

function Resolve-CvAudioChannels {
    <#
        Canales de salida: el perfil (AudioChannels) manda si los fija (>=1); si no, el global. <1 -> 2.
        'audioChannels' es un MAXIMO: si SourceChannels>=1 y el objetivo supera al origen, se limita al
        del origen (NO upmix). SourceChannels=0 (desconocido) -> no limita. Devuelve {Channels;Target;
        Capped}: Target = objetivo antes del tope, Channels = final, Capped = $true si se limito.
    #>
    param($ProfChannels, [int]$GlobalChannels, [int]$SourceChannels = 0)
    $t = if ($null -ne $ProfChannels -and [int]$ProfChannels -ge 1) { [int]$ProfChannels } else { [int]$GlobalChannels }
    if ($t -lt 1) { $t = 2 }
    $ch = $t; $capped = $false
    if ($SourceChannels -ge 1 -and $ch -gt $SourceChannels) { $ch = $SourceChannels; $capped = $true }
    [pscustomobject]@{
        Channels = $ch
        Target   = $t
        Capped   = $capped
    }
}

function Resolve-CvDownmixMode {
    <# Modo de downmix 5.1->estereo: el del perfil si lo fija (no vacio), si no el global. En minusculas. #>
    param($ProfMode, $GlobalMode)
    if ("$ProfMode" -ne '') { return "$ProfMode".ToLower() }
    return "$GlobalMode".ToLower()
}

function Get-CvDownmixPan {
    <#
        Filtro 'pan' del downmix 5.1->estereo con VOZ REFORZADA, de los coeficientes {Center;Front;
        Surround}. c2=central (dialogos), c0/c1=frontales, c4/c5=surrounds (indices validos para 5.1 y
        5.1(side)); el LFE (c3) se descarta. Formato invariante de locale (punto decimal, para ffmpeg).
    #>
    param([Parameter(Mandatory)]$Coeffs)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $cc = ([double]$Coeffs.Center).ToString($inv)
    $cf = ([double]$Coeffs.Front).ToString($inv)
    $cs = ([double]$Coeffs.Surround).ToString($inv)
    'pan=stereo|c0={0}*c2+{1}*c0+{2}*c4|c1={0}*c2+{1}*c1+{2}*c5' -f $cc, $cf, $cs
}

function Resolve-CvVolumeMethod {
    <#
        Metodo de volumen final: si -Method no es valido (Get-CvVolumeMethods) cae al default de config
        (volume.method). 'aacgain' solo aplica a AAC (ReplayGain sobre .m4a): con otro codec cae a
        'peak' (filtro valido para cualquiera). Devuelve {Method; AacgainDowngraded} (=$true si se
        cambio aacgain->peak por el codec, para avisar en el worker).
    #>
    param([string]$Method, [string]$Codec)
    $m = "$Method".ToLower()
    if ($m -notin (Get-CvVolumeMethods)) { $m = "$((Get-CvConfigDefaults).volume.method)" }
    $downgraded = $false
    if ($m -eq 'aacgain' -and "$Codec".ToLower() -ne 'aac') { $m = 'peak'; $downgraded = $true }
    [pscustomobject]@{ Method = $m; AacgainDowngraded = $downgraded }
}

function Get-CvAdelayFilter {
    <# Filtro de retardo de la sincronia en una pasada: 'adelay=<ms>:all=1' (ms enteros redondeados). #>
    param([double]$Sync)
    'adelay={0}:all=1' -f [int][math]::Round($Sync * 1000)
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
        Reproduce una pista de audio concreta con FFplay para revisarla (por defecto desde el
        principio y sin limite; inicio/duracion configurables en preview.start/seconds).
        -AudioPos: posicion 0-based entre las pistas de AUDIO (se selecciona con '-ast a:N').
        -AudioOnly: sin ventana de video ('-nodisp'); si no, muestra el video con esa pista.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$AudioPos, [string]$Label = 'AUDIO', [switch]$AudioOnly, [int]$Start = -1, [int]$Seconds = -1, [double]$Duration = 0
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
    $to = Get-CvPromptTimeout $Context 'audio'   # auto-aceptar por inactividad (0 = off)

    $lines = @()
    foreach ($s in $streams) {
        $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
        $lines += (Format-CvAudioLine -Stream $s -Mark $mark)
    }
    Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (mismo idioma) [* = por defecto = mejor calidad]:' -Lines $lines -Indent 3
    while ($true) {
        $a = (Read-CvMenuLine ("   [AUDIO] - Indice / 'P N'=video+audio / 'A N'=solo audio (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex) $to).Trim()
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

function Select-AudioMulti {
    <#
        [BETA multipista] Cuando hay 2+ pistas del idioma preferido: lista SOLO esas, deja
        REPRODUCIR cada una ('P N'=video+audio, 'A N'=solo audio) y elige en UN prompt CUALES
        conservar y CUAL predeterminada. La default se marca con '*' (ej '*3 5' = conservar 3 y 5,
        default = 3). Sin '*', la default es la preseleccionada si esta en el set, si no la 1a
        conservada. ENTER = solo la preseleccionada. T = todas. Devuelve la lista de selecciones
        {Index,Language,Channels,Is51,Default}, con la DEFAULT PRIMERO y el resto en orden de listado.
        -AllStreams = todas las de audio (para la posicion 0-based de la reproduccion); -PrefStreams =
        las del idioma preferido (las que se listan/eligen).
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$AllStreams, [Parameter(Mandatory)]$PrefStreams,
        [int]$DefaultIndex, [double]$Duration = 0
    )
    $all  = @($AllStreams)
    $pref = @($PrefStreams)
    # Posicion 0-based de cada pista de audio entre TODAS (para '-ast a:N' en la reproduccion).
    $posByIndex = @{}
    for ($i = 0; $i -lt $all.Count; $i++) { $posByIndex[[int]$all[$i].index] = $i }
    $prefIdx = @($pref | ForEach-Object { [int]$_.index })
    $to = Get-CvPromptTimeout $Context 'audio'   # auto-aceptar por inactividad (0 = off)

    while ($true) {
        $lines = @()
        foreach ($s in $pref) {
            $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
            $lines += (Format-CvAudioLine -Stream $s -Mark $mark)
        }
        # Ejemplos alineados por columnas con PadRight (no con espacios a mano, que no cuadran).
        $cw = 47   # ancho de la columna del texto antes de 'ej:' (deja hueco tras el texto mas largo)
        $hint = @(
            '',
            "Elige QUE pistas conservar y CUAL sera la predeterminada (el resto se descarta):",
            ("  {0}ej: {1}-> conserva la 1 y la 3"                 -f '- Indices a conservar separados por espacio.'.PadRight($cw), '1 3'.PadRight(6)),
            ("  {0}ej: {1}-> conserva la 1 y la 3, predeterminada = 3" -f '- Marca la PREDETERMINADA con *.'.PadRight($cw), '*3 1'.PadRight(6)),
            "  - [ENTER] = solo la preseleccionada (*)   -   T = todas   -   'P N'/'A N' = previsualizar (video / solo audio)"
        )
        Show-Menu -Title "CONSERVAR PISTAS DE AUDIO (idioma preferido) [beta]   [* = predeterminada]:" -Lines ($lines + $hint) -Indent 3
        $a = (Read-CvMenuLine ("   [AUDIO] - Pistas a conservar (* = predeterminada) [{0}]" -f ('*{0}' -f $DefaultIndex)) $to).Trim()

        # Reproducir para revisar.
        $play = ConvertFrom-CvPlayCommand $a -AllowAudioOnly
        if ($play) {
            if ($posByIndex.ContainsKey($play.Index)) {
                Show-AudioPreview -Context $Context -File $File -AudioPos $posByIndex[$play.Index] -Label ("PISTA {0}" -f $play.Index) -AudioOnly:$play.AudioOnly -Start $play.Start -Duration $Duration
            } else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }

        # ENTER = solo la preseleccionada; T = todas.
        $keep = @(); $defIdx = $DefaultIndex
        if ($a -eq '') {
            $keep = @($DefaultIndex)
        }
        elseif ($a -match '^[Tt]$') {
            $keep = @($prefIdx)
        }
        else {
            # Tokens: '*N' marca la default; 'N' conserva. Solo indices del idioma preferido.
            $markDef = $null; $bad = $false
            foreach ($tok in @($a -split '[,\s]+' | Where-Object { $_ -ne '' })) {
                $m = [regex]::Match($tok, '^(\*?)(\d+)$')
                if (-not $m.Success) { $bad = $true; break }
                $n = [int]$m.Groups[2].Value
                if ($prefIdx -notcontains $n) { $bad = $true; break }
                if ($m.Groups[1].Value -eq '*') { $markDef = $n }
                if ($keep -notcontains $n) { $keep += $n }
            }
            if ($bad -or $keep.Count -eq 0) { Write-Host '   Indices no validos (usa solo los del idioma preferido).' -ForegroundColor Yellow; continue }
            if ($null -ne $markDef) { $defIdx = $markDef }
        }
        # La default debe estar en el set: si no se marco o no esta, cae a la preseleccionada (si se
        # conserva) o a la 1a conservada.
        if ($keep -notcontains $defIdx) { $defIdx = if ($keep -contains $DefaultIndex) { $DefaultIndex } else { $keep[0] } }

        Write-Host ''
        # Construir selecciones: DEFAULT primero, resto en orden de listado del idioma preferido.
        $ordered = @($defIdx) + @($keep | Where-Object { $_ -ne $defIdx })
        $result = @()
        foreach ($idx in $ordered) {
            $s = $pref | Where-Object { [int]$_.index -eq $idx } | Select-Object -First 1
            $sel = ConvertTo-AudioSel $s
            $result += [pscustomobject]@{
                Index    = $sel.Index
                Language = $sel.Language
                Channels = $sel.Channels
                Is51     = $sel.Is51
                Default  = ($idx -eq $defIdx)
            }
        }
        return $result
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
    $to = Get-CvPromptTimeout $Context 'audio'   # auto-aceptar por inactividad (0 = off)

    # ---- 1) Elegir pista (con opcion de reproducir para confirmar) ----
    $chosen = $null
    while ($null -eq $chosen) {
        $lines = @()
        foreach ($s in $streams) {
            $mark = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
            $lines += (Format-CvAudioLine -Stream $s -Mark $mark)
        }
        Show-Menu -Title 'SELECCIONAR PISTA DE AUDIO (ningun idioma preferido) [* = descarte]:' -Lines $lines -Indent 3
        $a = (Read-CvMenuLine ("   [AUDIO] - Indice / 'P N'=video+audio / 'A N'=solo audio (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex) $to).Trim()
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
            $ok = (Read-CvMenuLine ("   Usar la pista {0}? (ENTER=si / N=volver a la lista)" -f $n) $to).Trim()
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
            $r = (Read-CvMenuLine ("   [AUDIO] - Idioma a asignar: [ENTER]='{0}' / [O]tro codigo / [U]nd" -f $trackLang) $to).Trim()
        } else {
            $r = (Read-CvMenuLine '   [AUDIO] - La pista no trae idioma: [O]tro codigo / [ENTER]=und' $to).Trim()
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
    return [pscustomobject]@{
        Index    = $sel.Index
        Language = $lang
        Channels = $sel.Channels
        Is51     = $sel.Is51
    }
}

function Invoke-AudioAsk {
    <#
        Devuelve @{ Skip; Tracks=[{Index,Is51,Sync,Lang,Default}]; Manual }. La pista DEFAULT va PRIMERO
        en Tracks. Monopista (por defecto): Tracks tiene 1 elemento. Multipista [BETA] (encode.multiAudio
        + test.betaMultiAudio, y 2+ pistas del idioma preferido): se eligen varias y cual default.
        En copy (Skip=$true) las Tracks NO se recodifican: el multiplex las copia (o, si Tracks esta
        vacio, cae al comportamiento clasico 0:a:0).
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof, [Parameter(Mandatory)]$Info)
    $res    = [ordered]@{
        Skip   = $false
        Tracks = @()
        Manual = $false
    }
    $isCopy = ($Prof.AudioEncoder -eq 'copy')
    $file   = $Info.format.filename
    $adur   = Get-MediaDuration $Info

    $aud = @(Get-AudioStreams -Info $Info)
    if ($aud.Count -eq 0) {
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[SKIP] - No se ha detectado pista de audio' }
        $res.Skip = $true
        return [pscustomobject]$res
    }

    $prefTracks  = @($aud | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $Context.AudioLangs })
    # Multipista [BETA]: doble llave (MultiAudio + BetaMultiAudio) y 2+ pistas del idioma preferido.
    $doMulti = ($Context.MultiAudio -and $Context.BetaMultiAudio -and $prefTracks.Count -ge 2)

    # copy SIN multipista -> comportamiento clasico: no se elige nada; el multiplex copia 0:a:0.
    if ($isCopy -and -not $doMulti) {
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[SKIP] - Se copiara la pista de audio original' }
        $res.Skip = $true
        return [pscustomobject]$res
    }

    # ---- Seleccion de pista(s) ----
    $sels = @()   # lista de {Index,Language,Channels,Is51,Default}
    if ($doMulti) {
        # MULTIPISTA (beta): conservar varias del idioma preferido + elegir la predeterminada.
        $preDef = Select-CvDefaultAudio $prefTracks
        Write-CvLog 'AUDIO' ("[BETA] - {0} pistas en el idioma preferido; elige cuales conservar y la predeterminada." -f $prefTracks.Count) -Indent 3
        $sels = @(Select-AudioMulti -Context $Context -File $file -AllStreams $aud -PrefStreams $prefTracks -DefaultIndex ([int]$preDef.index) -Duration $adur)
        $res.Manual = $true
    }
    else {
        # MONOPISTA (como siempre): mejor pista, con menu si hay ambiguedad / fallback si no hay idioma.
        $sel = Select-AudioStream -Info $Info -PrefLangs $Context.AudioLangs
        if ($prefTracks.Count -gt 1) {
            $sel = Select-AudioInteractive -Context $Context -File $file -AudioStreams $aud -DefaultIndex $sel.Index -Duration $adur
            $res.Manual = $true   # varias del idioma preferido
        }
        elseif ($prefTracks.Count -eq 0) {
            Write-CvLog 'AUDIO' ("[AVISO] - No hay pista de audio en el idioma preferido ({0}); elige una manualmente." -f ($Context.AudioLangs -join '/')) -Indent 3
            $sel = Select-AudioFallback -Context $Context -File $file -AudioStreams $aud -DefaultIndex $sel.Index -Duration $adur
            $res.Manual = $true   # no habia idioma preferido
        }
        $lang = if ($sel.Language) { "$($sel.Language)" } else { 'und' }
        $sels = @([pscustomobject]@{
            Index    = $sel.Index
            Language = $lang
            Channels = $sel.Channels
            Is51     = $sel.Is51
            Default  = $true
        })
    }

    # copy CON multipista: se copian las pistas elegidas (no se recodifican).
    if ($isCopy) {
        $res.Skip = $true
        if ($Context.Debug) { Write-CvLog 'AUDIO' '[SKIP] - Se copiaran las pistas de audio elegidas (perfil copy)' }
    }

    # ---- Sincronia audio/video POR PISTA (solo si se recodifica; en copy no aplica) ----
    $tracks = @()
    foreach ($s in $sels) {
        $lang = if ($s.Language) { "$($s.Language)" } else { 'und' }
        $sync = 0.0
        if (-not $isCopy) {
            $delay = Get-AudioInitDelay -Context $Context -File $file -Index $s.Index
            if ($delay -gt 0) {
                # Indentado bajo la linea del archivo para agrupar la pregunta con su archivo.
                $lbl = if ($sels.Count -gt 1) { (" (pista {0}, {1})" -f $s.Index, $lang) } else { '' }
                Write-CvLog 'AUDIO' ("[SYNC] - El audio empieza {0}s mas tarde que el video{1}" -f $delay, $lbl) -Indent 3
                $ans = (Read-CvLine -Prompt ("   [AUDIO] - [SYNC] - Silencio a anadir al inicio en seg [{0}] (ENTER=usar / 0=ninguno)" -f $delay) -TimeoutSec (Get-CvPromptTimeout $Context 'sync')).Trim()
                $res.Manual = $true   # se pregunto por el silencio de sincronia
                if ($ans -eq '') { $sync = $delay }
                else { $v = ConvertTo-InvDouble $ans; if ($null -ne $v) { $sync = $v } }
                Write-Host ''
            } elseif ($Context.Debug) {
                Write-CvLog 'AUDIO' ("[SYNC] - Audio y video inician a la vez [OK] (pista {0})" -f $s.Index)
            }
        }
        $tracks += [pscustomobject]@{
            Index   = [int]$s.Index
            Is51    = [bool]$s.Is51
            Sync    = [double]$sync
            Lang    = $lang
            Default = [bool]$s.Default
        }
        if ($Context.Debug) { Write-CvLog 'AUDIO' ("[INFO] - Pista {0} (idioma={1}, canales={2}, default={3})" -f $s.Index, $lang, $s.Channels, $s.Default) }
    }
    $res.Tracks = @($tracks)
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
    <#
        Extrae/recodifica UNA pista de audio a un temporal (AAC -> .m4a; resto -> .mka), con sincronia y
        normalizacion de volumen. -Pos = posicion 0-based de la pista en la salida (para la multipista:
        cada pista va a <name>_aN.*); pos 0 = predeterminada. Devuelve la RUTA del temporal generado, o
        $null si falla.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)][string]$File, [double]$Sync = 0, [int]$Index = 0, [bool]$Is51 = $false,
        # Duracion del audio en segundos (para el % y ETA del progreso). 0 = desconocida (sin %/ETA).
        [double]$Duration = 0,
        # Canales de la pista de ORIGEN (para no hacer upmix: audioChannels es un MAXIMO). 0 = desconocido.
        [int]$SourceChannels = 0,
        # Posicion 0-based de la pista en la salida (multipista): define el temporal <name>_aN.*.
        [int]$Pos = 0
    )
    $name   = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $atmp   = Get-CvAudioTempPath -Context $Context -Name $name -Pos $Pos
    # Codec de salida al recodificar (perfil; 'aac' por defecto y para compatibilidad con jobs antiguos).
    # AAC va en .m4a (compatible con aacgain); el resto en .mka (Matroska) que admite cualquier codec.
    $codec  = "$($Prof.AudioCodec)".ToLower(); if (-not $codec) { $codec = 'aac' }
    $outM4a = if ($codec -eq 'aac') { $atmp.M4a } else { $atmp.Mka }
    # Limpiar CUALQUIER temporal de audio previo de ESTA pos (m4a y mka) para no dejar el que no toca.
    foreach ($old in @($atmp.M4a, $atmp.Mka)) {
        if (Test-Path -LiteralPath $old) { Remove-Item -Force -LiteralPath $old -ErrorAction SilentlyContinue }
    }

    $hz = if ($Prof.AudioHz) { $Prof.AudioHz } else { $Context.DefaultAudioHz }
    # Canales de salida (perfil->global, MAXIMO sin upmix): Resolve-CvAudioChannels. Avisa si limita.
    $chInfo = Resolve-CvAudioChannels -ProfChannels $Prof.AudioChannels -GlobalChannels $Context.AudioChannels -SourceChannels $SourceChannels
    if ($chInfo.Capped) { Write-CvInfoStep $Context 'AUDIO' ("El origen tiene {0} canales; no se hace upmix a {1} (se conservan {0})" -f $SourceChannels, $chInfo.Target) }
    $ch     = $chInfo.Channels
    $layout = Get-CvChannelLayout $ch
    # Modo de downmix y coeficientes: el perfil manda si los fija; si no, el global (encode.downmixMode /
    # encode.downmixCoeffs). El activador beta (BetaDownmix) es SIEMPRE global (test.betaDownmix).
    $dmMode = Resolve-CvDownmixMode $Prof.DownmixMode $Context.DownmixMode
    $coeffs = if ($null -ne $Prof.DownmixCoeffs) { $Prof.DownmixCoeffs } else { $Context.DownmixCoeffs }

    # Downmix con VOZ REFORZADA (BETA): solo al bajar 5.1 -> estereo (ch=2) con downmix 'dialogue'.
    # pan por INDICES (vale para 5.1 y 5.1(side)): sube el central (c2 = dialogos) y baja los
    # surrounds (c4/c5); descarta el LFE (c3). Coeficientes clip-safe (suman 1.0), asi el pico del
    # downmix nunca supera el de origen y la normalizacion 'peak' (medida en el origen) sigue valida.
    # BETA: los coeficientes son provisionales, a la espera de validarlos/ajustarlos con mas material.
    # Doble llave mientras sea beta: el modo 'dialogue' solo refuerza la voz si test.betaDownmix ($true).
    $wantDialogue = ($ch -eq 2) -and $Is51 -and ($dmMode -eq 'dialogue')
    $downmix = $wantDialogue -and $Context.BetaDownmix
    $panDown = ''
    if ($downmix) {
        # Coeficientes (perfil o global encode.downmixCoeffs). $coeffs SIEMPRE viene completo: lo
        # rellena la capa de carga (Context.DownmixCoeffs / ConvertTo-CvDownmixCoeffs del perfil, con
        # sus defaults desde Get-CvDefaultDownmixCoeffs), asi que aqui NO se re-aplican defaults.
        $panDown = Get-CvDownmixPan -Coeffs $coeffs
    }
    # Indicar SIEMPRE el downmix 5.1 -> estereo y con que modo: voz reforzada (beta activo), o estandar
    # de ffmpeg (aformat, que atenua el central). Si se pidio 'dialogue' pero el beta esta desactivado,
    # avisar de que sigue en estandar hasta activar test.betaDownmix. Asi se ve en el worker que se hizo.
    if ($ch -eq 2 -and $Is51) {
        if ($downmix)          { Write-CvInfoStep $Context 'AUDIO' 'Downmix 5.1 -> estereo [beta] con voz reforzada (central +, surrounds -)' }
        elseif ($wantDialogue) { Write-CvInfoStep $Context 'AUDIO' 'Downmix 5.1 -> estereo (estandar; activa test.betaDownmix para la voz reforzada [beta])' }
        else                   { Write-CvInfoStep $Context 'AUDIO' 'Downmix 5.1 -> estereo (estandar de ffmpeg; downmixMode=dialogue + test.betaDownmix para reforzar la voz)' }
    }

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
        $syncFilter  = Get-CvAdelayFilter $Sync
    }
    elseif ($Sync -gt 0) {
        # CLASICO: WAV = silencio + pista, en el layout de salida; el índice concreto (0:Index),
        # no 0:a (que seria la PRIMERA pista y podria no ser la seleccionada).
        $wav = $atmp.SyncWav
        if (Test-Path -LiteralPath $wav) { Remove-Item -Force -LiteralPath $wav -ErrorAction SilentlyContinue }
        # La pista (a2) se lleva al layout de salida con aformat; si hay downmix con voz reforzada,
        # el propio pan hace el downmix a estereo (sustituye al aformat). El silencio se genera ya en
        # el layout de salida y se concatena delante.
        $a2f = if ($downmix) { $panDown } else { "aformat=channel_layouts=$layout" }
        # OJO: el silencio 'd=' debe ir con PUNTO decimal (InvariantCulture); "$Sync" en locale ES daria
        # "0,5" y ffmpeg parte el filtro por la coma (aevalsrc=0:d=0,5 -> error). Bug real de locale.
        $syncSec = ([double]$Sync).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        $fc = ("[0:{0}]{1}[a2];aevalsrc=0:d={2}:sample_rate={3}:channel_layout={4}[sil];[sil][a2]concat=n=2:v=0:a=1[out]" -f $Index, $a2f, $syncSec, $hz, $layout)
        Start-CvStep $Context 'AUDIO' ("Generando silencio de {0}s + pista..." -f $Sync)
        $wavArgs = @('-hide_banner','-y','-i',$File,'-filter_complex',$fc,'-map','[out]')
        if ($Context.TestLimit -gt 0) { $wavArgs += @('-t',"$($Context.TestLimit)") }  # modo pruebas
        $wavArgs += $wav
        Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $wavArgs -Context $Context | Out-Null
        $syncOk = (Test-Path -LiteralPath $wav)
        Stop-CvStep $Context 'AUDIO' $syncOk -FailMsg '[ERR] - No se pudo generar el audio sincronizado'
        if (-not $syncOk) { return $null }
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

    # Metodo de volumen (invalido->default; aacgain->peak si el codec no es AAC): Resolve-CvVolumeMethod.
    $vm     = Resolve-CvVolumeMethod -Method $Context.VolumeMethod -Codec $codec
    $method = $vm.Method
    if ($vm.AacgainDowngraded) { Write-CvInfoStep $Context 'AUDIO' ("Volumen: aacgain no aplica a {0}; se usa 'peak'" -f $codec) }

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

    # Cadena de filtros = sincronia (adelay, beta) + downmix voz + volumen; si no hay ninguno, mapeo
    # directo. El downmix pan va DESPUES de la sincronia y ANTES del volumen. Si la fuente es el WAV
    # clasico, el downmix ya se hizo al generarlo, asi que aqui no se repite.
    $chainParts = @()
    if ($syncFilter) { $chainParts += $syncFilter }
    if ($downmix -and -not $fromWav) { $chainParts += $panDown }
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

    # Progreso inline (% + ETA) si esta activo y sabemos la duracion; si no, ventana aparte + ✓.
    # Total aprox. = duracion (+ el silencio de sincronia, que alarga la salida), acotado a TestLimit.
    $progTotal = [double]$Duration
    if ($Sync -gt 0) { $progTotal += [double]$Sync }
    if ($Context.TestLimit -gt 0) { $progTotal = [math]::Min($progTotal, [double]$Context.TestLimit) }
    $global:CvLastToolError = $null   # el modo progreso lo rellena; se vuelca al log si ffmpeg falla
    if ($Context.Progress -and -not $Context.Debug -and $progTotal -gt 0) {
        $code = Invoke-ToolProgress -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context -Label 'Recodificando audio...' -TotalSeconds $progTotal
    } else {
        Start-CvStep $Context 'AUDIO' 'Recodificando audio...'
        $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    }
    if ($code -ne 0) {
        Stop-CvStep $Context 'AUDIO' $false -FailMsg ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        Show-CvToolError -Context $Context -Category 'AUDIO' -Name $name -Tool 'ffmpeg-audio'
        if (Test-Path -LiteralPath $outM4a)       { Remove-Item -Force -LiteralPath $outM4a -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $atmp.SyncWav) { Remove-Item -Force -LiteralPath $atmp.SyncWav -ErrorAction SilentlyContinue }
        return $null
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
    if (Test-Path -LiteralPath $atmp.SyncWav) { Remove-Item -Force -LiteralPath $atmp.SyncWav -ErrorAction SilentlyContinue }

    if (Test-Path -LiteralPath $outM4a) { return $outM4a }
    return $null
}

Export-ModuleMember -Function *
