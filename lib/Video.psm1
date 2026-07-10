<#
    Video.psm1 - Fase ASK (deteccion de bordes / resize / animacion) y fase RUN (codificacion).
    Espejo de process_video.cmd.
#>

function Find-CropDetect {
    <#
        Escanea un tramo del video con cropdetect y devuelve el recorte mas frecuente
        (formato W:H:X:Y) o $null si no se detecta nada.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$Start = -1, [int]$Duration = -1, [int]$Index = -1
    )
    if ($Start -lt 0)    { $Start = [int]$Context.BorderStart }
    if ($Duration -lt 0) { $Duration = [int]$Context.BorderDur }
    $stop = $Start + $Duration
    Write-CvLog 'VIDEO' ("[BORDE] - [SCAN] - Analizando bordes ({0}s desde el segundo {1})..." -f $Duration, $Start) -Indent 3
    # Si se indica -Index, analizar ESA pista (no la primera): importa con varias pistas de video.
    $mapArg = if ($Index -ge 0) { @('-map', ("0:{0}" -f $Index)) } else { @() }
    $r = Invoke-ToolCapture -Exe $Context.FFmpeg -Arguments (@(
        '-hide_banner','-ss', "$Start", '-to', "$stop", '-i', $File
    ) + $mapArg + @('-vf','cropdetect','-f','null','-')) -Context $Context
    $cropMatches = [regex]::Matches($r.StdErr, 'crop=(\d+:\d+:\d+:\d+)')
    if ($cropMatches.Count -eq 0) { return $null }
    $best = $cropMatches | ForEach-Object { $_.Groups[1].Value } |
            Group-Object | Sort-Object Count -Descending | Select-Object -First 1
    return $best.Name
}

function Find-CropDetectSamples {
    <#
        Escanea bordes en VARIOS puntos repartidos del video y agrupa los recortes por "votos".
        Cada punto escanea $Duration segundos (NO se reparte: N puntos = N escaneos de $Duration),
        desde $Start hasta cerca del final. Devuelve:
          @{ Groups = @( @{Crop; Count} ordenados por votos desc ); Samples }
        Con 1 punto o duracion desconocida, cae al escaneo unico clasico.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$Start = -1, [int]$Duration = -1, [double]$VideoDuration = 0, [int]$Index = -1, [int]$Samples = -1
    )
    if ($Start -lt 0)    { $Start = [int]$Context.BorderStart }
    if ($Duration -lt 0) { $Duration = [int]$Context.BorderDur }
    if ($Samples -lt 1)  { $Samples = [int]$Context.BorderSamples }
    if ($Samples -lt 1)  { $Samples = 1 }
    # Si el video es mas corto que el inicio configurado, llevar el inicio dentro del contenido.
    $Start = Get-CvSafeStart -Start $Start -Duration $VideoDuration -Window 5

    if ($Samples -le 1 -or $VideoDuration -le 0) {
        $c = Find-CropDetect -Context $Context -File $File -Start $Start -Duration $Duration -Index $Index
        $g = if ($c) { @([pscustomobject]@{ Crop = $c; Count = 1 }) } else { @() }
        return [pscustomobject]@{ Groups = $g; Samples = 1 }
    }

    $win = [Math]::Max(5, [int]$Duration)                       # cada punto escanea $Duration (no se reparte)
    $lastStart = [Math]::Max($Start, [int]($VideoDuration - $win - 1))
    $crops = @()
    for ($i = 0; $i -lt $Samples; $i++) {
        $p = [int]($Start + ($lastStart - $Start) * $i / ($Samples - 1))
        $c = Find-CropDetect -Context $Context -File $File -Start $p -Duration $win -Index $Index
        if ($c) { $crops += $c }
    }
    $groups = @($crops | Group-Object | Sort-Object Count -Descending | ForEach-Object {
        [pscustomobject]@{ Crop = $_.Name; Count = $_.Count }
    })
    return [pscustomobject]@{ Groups = $groups; Samples = $Samples }
}

function Show-Preview {
    <#
        Reproduce un tramo con FFplay para revisar visualmente. Si se pasa -Crop,
        aplica el filtro de recorte. Ventana con autoexit tras unos segundos.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [string]$Crop = '', [int]$Seconds = -1, [int]$VideoPos = -1, [double]$Duration = 0
    )
    $title = 'ORIGINAL'
    $extra = @()
    # Si se indica -VideoPos, reproducir ESA pista de video (posicion entre las de video).
    if ($VideoPos -ge 0) { $extra += @('-vst', ("v:{0}" -f $VideoPos)) }
    if ($Crop) { $extra += @('-vf', "crop=$Crop"); $title = "RECORTADO $Crop" }
    Write-CvLog 'VIDEO' ("[BORDE] - [TEST] - Reproduciendo: {0}  (se cierra solo o pulsa ESC)" -f $title)
    Invoke-CvPreview -Context $Context -File $File -ExtraArgs $extra -Label $title -Seconds $Seconds -Duration $Duration
}

function Show-VideoPreview {
    <#
        Reproduce un tramo de una pista de VIDEO concreta con FFplay para revisarla.
        -VideoPos: posicion 0-based entre las pistas de video (se selecciona con '-vst v:N').
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [int]$VideoPos, [string]$Label = 'VIDEO', [int]$Seconds = -1, [int]$Start = -1, [double]$Duration = 0
    )
    Write-CvLog 'VIDEO' ("[TEST] - Reproduciendo {0}; se cierra solo o pulsa ESC/Q" -f $Label) -Indent 3
    Invoke-CvPreview -Context $Context -File $File -ExtraArgs @('-vst', ("v:{0}" -f $VideoPos)) -Label $Label -Start $Start -Seconds $Seconds -Duration $Duration
}

function Select-VideoInteractive {
    <#
        Menu para elegir pista de video cuando hay 2+ pistas reales. Permite REPRODUCIR cada
        una ('P N') para confirmar cual es antes de elegirla. Devuelve el stream elegido.
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)]$Info, [Parameter(Mandatory)]$VideoStreams, [int]$DefaultIndex
    )
    $streams = @($VideoStreams)
    $vdur    = Get-MediaDuration $Info
    $chosen  = $null
    while ($null -eq $chosen) {
        $lines = @()
        foreach ($s in $streams) {
            $lang  = Get-Tag $s 'language'; $title = Get-Tag $s 'title'
            $mark  = ' '; if ([int]$s.index -eq $DefaultIndex) { $mark = '*' }
            $titleTxt = ''; if ($title) { $titleTxt = "'$title'" }
            $lines += ("{0} [{1}] {2}x{3} codec={4} idioma={5} {6}" -f $mark, $s.index, $s.width, $s.height, $s.codec_name, $lang, $titleTxt)
        }
        Show-Menu -Title 'SELECCIONAR PISTA DE VIDEO [* = por defecto]:' -Lines $lines -Indent 3
        $a = (Read-Host ("   [VIDEO] - Indice / 'P N'=reproducir (opc. seg inicio: 'P N 300') [{0}]" -f $DefaultIndex)).Trim()
        if ($a -eq '') { $a = "$DefaultIndex" }

        $play = ConvertFrom-CvPlayCommand $a
        if ($play) {
            $match = $streams | Where-Object { [int]$_.index -eq $play.Index } | Select-Object -First 1
            if ($match) { Show-VideoPreview -Context $Context -File $File -VideoPos (Get-VideoStreamPos -Info $Info -Index $play.Index) -Label ("PISTA {0}" -f $play.Index) -Start $play.Start -Duration $vdur }
            else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
            continue
        }

        $n = 0
        if ([int]::TryParse($a, [ref]$n)) {
            $match = $streams | Where-Object { [int]$_.index -eq $n } | Select-Object -First 1
            if ($match) {
                $ok = (Read-Host ("   Usar la pista {0}? (ENTER=si / N=volver a la lista)" -f $n)).Trim()
                if ($ok -match '^[Nn]$') { continue }
                $chosen = $match; continue
            }
        }
        Write-Host '   Indice no valido.' -ForegroundColor Yellow
    }
    Write-Host ''
    return $chosen
}

function Invoke-VideoAsk {
    <#
        Hace las preguntas/detecciones de video y devuelve un objeto:
        @{ Skip; Crop; Resize; Anim }
        $ForceBorder fuerza la deteccion (regla del prefijo '_').
    #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)]$Info,
        [bool]$ForceBorder = $false
    )
    $res = [ordered]@{ Skip = $false; Index = -1; Crop = ''; Resize = ''; Anim = $false; Manual = $false }

    # ---- Seleccion de pista de video ----
    # Se elige SIEMPRE (aunque sea copy) para congelar el indice y usarlo tanto al copiar como
    # al codificar/multiplexar; asi nunca se cuela una caratula ni una pista equivocada.
    $vids = @(Get-VideoStreams -Info $Info)
    if ($vids.Count -eq 0) {
        if ($Context.Debug) { Write-CvLog 'VIDEO' '[SKIP] - No se ha detectado pista de video' }
        $res.Skip = $true
        return [pscustomobject]$res
    }
    $vstream = $vids[0]
    if ($vids.Count -gt 1) {
        # 2+ pistas de video reales: avisar y preguntar cual usar (con reproduccion para confirmar).
        Write-CvLog 'VIDEO' ("[AVISO] - Se han detectado {0} pistas de video; elige cual usar manualmente." -f $vids.Count) -Indent 3
        $vstream = Select-VideoInteractive -Context $Context -File $Info.format.filename -Info $Info -VideoStreams $vids -DefaultIndex ([int]$vids[0].index)
        $res.Manual = $true   # hubo seleccion manual de pista de video
    }
    $res.Index = [int]$vstream.index
    $vpos      = Get-VideoStreamPos -Info $Info -Index $res.Index

    if ($Prof.VideoEncoder -eq 'copy') {
        if ($Context.Debug) { Write-CvLog 'VIDEO' '[SKIP] - Se copiara la pista de video' }
        $res.Skip = $true
        return [pscustomobject]$res
    }

    # ---- Deteccion de bordes ----
    $detect = [bool]$Prof.DetectBorder
    if ($ForceBorder) {
        $detect = $true
        Write-CvLog 'VIDEO' '[BORDE] - Prefijo _ : se fuerza la deteccion de bordes' -Indent 3
    }
    if ($detect) {
        $res.Manual = $true   # la deteccion de bordes hace preguntas interactivas
        # Duracion del video (para repartir los puntos de escaneo entre inicio y final).
        $vdur  = Get-MediaDuration $Info
        $start = [int]$Context.BorderStart
        $dur   = [int]$Context.BorderDur
        $done  = $false

        while (-not $done) {
            # Escaneo en varios puntos (border.samples); agrupa recortes por votos.
            $groups = @((Find-CropDetectSamples -Context $Context -File $Info.format.filename -Start $start -Duration $dur -VideoDuration $vdur -Index $res.Index).Groups)

            if ($groups.Count -eq 0) {
                Write-CvLog 'VIDEO' '[BORDE] - No se detectaron bordes en este tramo' -Indent 3
                $a = (Read-Host '   [VIDEO] [BORDE] - [R] reintentar con otro tramo / [ENTER] continuar sin recorte').Trim()
                if ($a -match '^[Rr]') {
                    $start = Read-IntOrDefault '   Segundo de inicio del scan' $start
                    $dur   = Read-IntOrDefault '   Duracion total del scan (seg)' $dur
                    continue
                }
                $res.Crop = ''; $done = $true; continue
            }

            # ¿Hay ganador claro por votos? Los grupos vienen ordenados por votos desc. El mas
            # votado se acepta AUTOMATICAMENTE si (a) alcanza el % 'border.autoAcceptPct' de los
            # puntos que detectaron borde Y (b) supera al 2o por al menos 'autoAcceptMinMargin'
            # votos. El % descarta atipicos (escena oscura, creditos con otro encuadre); el margen
            # evita auto-aceptar con evidencia debil cuando hay pocas muestras (2/3=67% pero 1 de
            # margen -> pregunta). Si no se cumplen ambas, se muestra el menu para elegir a mano.
            $tot    = ($groups | Measure-Object -Property Count -Sum).Sum
            $topPct = if ($tot -gt 0) { [int][math]::Round(100 * $groups[0].Count / $tot) } else { 0 }
            $margin = $groups[0].Count - $(if ($groups.Count -ge 2) { $groups[1].Count } else { 0 })
            $autoWin = ($groups.Count -eq 1) -or (($topPct -ge $Context.BorderAutoAcceptPct) -and ($margin -ge $Context.BorderAutoAcceptMargin))

            if ($autoWin) {
                if ($groups.Count -eq 1) {
                    $extra = if ($groups[0].Count -gt 1) { " (coincide en $($groups[0].Count) puntos)" } else { '' }
                    Write-CvLog 'VIDEO' ("[BORDE] - Recorte detectado: {0}{1}" -f $groups[0].Crop, $extra) -Indent 3
                } else {
                    $disc = (@($groups | Select-Object -Skip 1 | ForEach-Object { "{0} ({1})" -f $_.Crop, $_.Count }) -join ', ')
                    Write-CvLog 'VIDEO' ("[BORDE] - Recorte por mayoria: {0} ({1}/{2} puntos, {3}%, +{4}); descartado(s): {5}" -f $groups[0].Crop, $groups[0].Count, $tot, $topPct, $margin, $disc) -Indent 3
                }
            } else {
                $lst = ($groups | ForEach-Object { "{0} ({1})" -f $_.Crop, $_.Count }) -join ' / '
                Write-CvLog 'VIDEO' ("[AVISO] - Bordes sin mayoria fiable ({0}%/margen +{1}; min {2}%/+{3}): {4}" -f $topPct, $margin, $Context.BorderAutoAcceptPct, $Context.BorderAutoAcceptMargin, $lst) -Indent 3
            }

            # Seleccion/preview sobre los recortes YA detectados (no re-escanea salvo re-detectar).
            $reScan = $false
            while (-not $done -and -not $reScan) {
                $crop = $null
                if ($autoWin) {
                    $crop = $groups[0].Crop
                } else {
                    $lines = @()
                    for ($gi = 0; $gi -lt $groups.Count; $gi++) { $lines += ("{0}. {1}  ({2} voto(s))" -f ($gi + 1), $groups[$gi].Crop, $groups[$gi].Count) }
                    Show-Menu -Title 'RECORTES DETECTADOS (elige cual probar) [por votos]:' -Lines ($lines + @('', 'M. Valor manual', 'R. Reescanear (otro tramo)', '0. Sin recorte')) -Indent 3
                    $sel = (Read-Host '   [VIDEO] [BORDE] - Opcion').Trim()
                    if ($sel -match '^0$') { $res.Crop = ''; $done = $true; continue }
                    if ($sel -match '^[Rr]$') {
                        $start = Read-IntOrDefault '   Segundo de inicio del scan' $start
                        $dur   = Read-IntOrDefault '   Duracion total del scan (seg)' $dur
                        $reScan = $true; continue
                    }
                    if ($sel -match '^[Mm]$') { $crop = '__MANUAL__' }
                    else {
                        $gi = 0
                        if ([int]::TryParse($sel, [ref]$gi) -and $gi -ge 1 -and $gi -le $groups.Count) { $crop = $groups[$gi - 1].Crop }
                        else { Write-Host '   Opcion no valida.' -ForegroundColor Yellow; continue }
                    }
                }

                # Opcion "M" del menu de varios: pedir valor manual, previsualizar y confirmar.
                if ($crop -eq '__MANUAL__') {
                    $manual = (Read-Host '   Nuevo recorte en formato W:H:X:Y').Trim()
                    if ($manual -eq '') { continue }
                    Show-Preview -Context $Context -File $Info.format.filename -Crop $manual -VideoPos $vpos -Duration $vdur
                    $ok = (Read-Host ("   Usar {0}? (ENTER=si / N=volver)" -f $manual)).Trim()
                    if ($ok -match '^[Nn]$') { continue }
                    $res.Crop = $manual; $done = $true; continue
                }

                # Preview del candidato (original + recorte) y confirmacion.
                Show-Preview -Context $Context -File $Info.format.filename -VideoPos $vpos -Duration $vdur
                Show-Preview -Context $Context -File $Info.format.filename -Crop $crop -VideoPos $vpos -Duration $vdur
                $volver = if ($autoWin) { 'volver a detectar' } else { 'volver al menu' }
                $a = (Read-Host ("   [VIDEO] [BORDE] - [ENTER/S] usar / [N] {0} / [M] manual / [0] sin recorte" -f $volver)).Trim()
                if ($a -eq '' -or $a -match '^[SsYy]$') { $res.Crop = $crop; $done = $true }
                elseif ($a -match '^0$') { $res.Crop = ''; $done = $true }
                elseif ($a -match '^[Mm]$') {
                    $manual = (Read-Host ("   Nuevo recorte en formato W:H:X:Y [{0}]" -f $crop)).Trim()
                    if ($manual -eq '') { $manual = $crop }
                    Show-Preview -Context $Context -File $Info.format.filename -Crop $manual -VideoPos $vpos -Duration $vdur
                    $ok = (Read-Host ("   Usar {0}? (ENTER=si / N=volver)" -f $manual)).Trim()
                    if ($ok -match '^[Nn]$') { continue }
                    $res.Crop = $manual; $done = $true
                }
                else {
                    # [N]: si hubo auto-aceptacion, re-escanear (otro tramo); con menu, volver al menu.
                    if ($autoWin) {
                        $start = Read-IntOrDefault '   Segundo de inicio del scan' $start
                        $dur   = Read-IntOrDefault '   Duracion total del scan (seg)' $dur
                        $reScan = $true
                    }
                }
            }
        }
        Write-Host ''
    }

    # ---- Resize (se puede combinar con recorte: se aplica crop y luego scale) ----
    if ($Prof.ChangeSize) {
        $res.Resize = $Prof.ChangeSize
        if ($Context.Debug) {
            if ($res.Crop -ne '') {
                Write-CvLog 'VIDEO' ("[RESIZE] - Se aplicara recorte {0} y luego escalado {1}" -f $res.Crop, $res.Resize)
            } else {
                Write-CvLog 'VIDEO' ("[RESIZE] - Escalado a {0}" -f $res.Resize)
            }
        }
    }

    # ---- Animacion (solo libx264/libx265) ----
    if ($Prof.VideoEncoder -in @('libx264','libx265')) {
        $a = (Read-Host '   [VIDEO] - Es un video de animacion? (s/N)').Trim()
        $res.Anim = ($a -match '^[SsYy]')
        $res.Manual = $true   # se pregunto por animacion (intervencion manual)
        Write-Host ''
    }

    return [pscustomobject]$res
}

function Get-VideoArgs {
    <# Construye el array de argumentos ffmpeg de la parte de codec/opciones de video. #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Prof, [bool]$Anim = $false)
    $a = @()
    $enc = $Prof.VideoEncoder
    $qmin = $Prof.Qmin; $qmax = $Prof.Qmax
    $constqp = ($null -ne $qmin -and $null -ne $qmax -and "$qmin" -eq "$qmax")
    # -r solo si encode.forceFps (por defecto). Si no, se conserva el fps de origen (sin -r).
    $fpsArg = if ($Context.ForceFps) { @('-r',"$($Context.Fps)") } else { @() }
    # 2-pass de NVENC (-multipass); solo encoders NVENC. El perfil ('Multipass') tiene prioridad;
    # si el perfil no lo fija ('' ), se usa el global 'encode.multipass' (Context.Multipass).
    $mp = if ("$($Prof.Multipass)" -ne '') { "$($Prof.Multipass)".ToLower() } else { "$($Context.Multipass)" }
    $mpArg = if ($mp -in @('qres','fullres')) { @('-multipass',$mp) } else { @() }

    switch ($enc) {
        'hevc_nvenc' {
            $a += @('-c:v','hevc_nvenc','-tier','high')
            if ($Prof.VideoProfile -eq 'main10') { $a += @('-pix_fmt','p010le') } else { $a += @('-pix_fmt','yuv420p') }
            $a += @('-preset','slow')
            if ($Prof.VideoProfile) { $a += @('-profile:v',$Prof.VideoProfile) }
            if ($Prof.VideoLevel)   { $a += @('-level:v',"$($Prof.VideoLevel)") }
            if ($constqp) { $a += @('-rc','constqp','-qp',"$qmax") }
            else {
                if ($null -ne $qmin) { $a += @('-qmin',"$qmin") }
                if ($null -ne $qmax) { $a += @('-qmax',"$qmax") }
            }
            # NOTA: NVENC no admite -refs (muchas GPUs fallan con "No capable devices found").
            $a += @('-rc-lookahead:v','32') + $mpArg + $fpsArg + @('-movflags','+faststart')
        }
        'h264_nvenc' {
            $a += @('-c:v','h264_nvenc','-pix_fmt','yuv420p','-preset','slow')
            if ($constqp) { $a += @('-rc','constqp','-qp',"$qmax") }
            else {
                if ($null -ne $qmin) { $a += @('-qmin',"$qmin") }
                if ($null -ne $qmax) { $a += @('-qmax',"$qmax") }
            }
            $a += @('-rc-lookahead:v','32') + $mpArg + $fpsArg + @('-movflags','+faststart')
        }
        'libx264' {
            $a += @('-c:v','libx264','-pix_fmt','yuv420p')
            if ($null -ne $Prof.Crf) { $a += @('-crf',"$($Prof.Crf)") }
            $a += @('-preset','slow')
            if ($Anim) { $a += @('-tune','animation') }
            $a += @('-refs','4') + $fpsArg + @('-movflags','+faststart')
        }
        'libx265' {
            $a += @('-c:v','libx265','-pix_fmt','yuv420p')
            if ($null -ne $Prof.Crf) { $a += @('-crf',"$($Prof.Crf)") }
            $a += @('-preset','slow')
            if ($Prof.VideoProfile) { $a += @('-profile:v',$Prof.VideoProfile) }
            if ($Prof.VideoLevel)   { $a += @('-level:v',"$($Prof.VideoLevel)") }
            if ($Anim) { $a += @('-tune','animation') }
            $a += @('-refs','4') + $fpsArg + @('-movflags','+faststart')
        }
    }
    return ,$a
}

function Invoke-VideoRun {
    <# Codifica el video usando la config del job. Devuelve $true si crea la salida temporal. #>
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Prof,
        [Parameter(Mandatory)][string]$File,
        [string]$Crop = '', [string]$Resize = '', [bool]$Anim = $false, [int]$Index = -1
    )
    $name = [System.IO.Path]::GetFileNameWithoutExtension($File)
    $outTmp = (Get-CvTempPaths -Context $Context -Name $name).Video
    if (Test-Path -LiteralPath $outTmp) { Remove-Item -Force -LiteralPath $outTmp -ErrorAction SilentlyContinue }

    # filtro de video
    $vf = @()
    if ($Crop)   { $vf += "crop=$Crop" }
    if ($Resize) { $vf += "scale=$Resize" }

    $ffArgs = @('-hide_banner','-y','-threads',"$($Context.Threads)",'-i',$File,'-an','-sn','-map_chapters','-1')
    $ffArgs += @('-metadata','title=', '-metadata:s:v','title=', '-metadata:s:v','language=und')
    if ($vf.Count -gt 0) { $ffArgs += @('-vf', ($vf -join ',')) }
    $ffArgs += (Get-VideoArgs -Context $Context -Prof $Prof -Anim $Anim)
    # Mapear explicitamente la PISTA DE VIDEO elegida por su indice absoluto ('0:<Index>'),
    # no el primer stream (0:0) ni '0:v:0' (que incluiria una caratula si va antes). Con -Index
    # congelado en el job, la deteccion y la codificacion usan SIEMPRE la misma pista. Sin -Index
    # (jobs antiguos) se cae a '0:v:0' como antes.
    $vmap = if ($Index -ge 0) { "0:$Index" } else { '0:v:0' }
    # Modo pruebas: limitar la salida a los primeros TestLimit segundos (-t como opcion de salida).
    if ($Context.TestLimit -gt 0) { $ffArgs += @('-t',"$($Context.TestLimit)") }
    $ffArgs += @('-map',$vmap,'-f','matroska',$outTmp)

    Start-CvStep $Context 'VIDEO' 'Procesando Video...'
    $code = Invoke-ToolShow -Exe $Context.FFmpeg -Arguments $ffArgs -Context $Context
    if ($code -ne 0) {
        Stop-CvStep $Context 'VIDEO' $false -FailMsg ("[ERR] - ffmpeg devolvio codigo {0}" -f $code)
        if (Test-Path -LiteralPath $outTmp) { Remove-Item -Force -LiteralPath $outTmp -ErrorAction SilentlyContinue }
        return $false
    }
    $vOk = ((Test-Path -LiteralPath $outTmp) -and ((Get-Item -LiteralPath $outTmp).Length -gt 0))
    Stop-CvStep $Context 'VIDEO' $vOk -FailMsg '[ERR] - la salida de video quedo vacia'
    return $vOk
}

Export-ModuleMember -Function *
