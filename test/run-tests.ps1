<#
    run-tests.ps1 - Bateria de tests de los comandos del conversor.

    Ejecuta el PIPELINE REAL (el script Convert.ps1, fase worker desatendida) sobre las
    fixtures de test\ con un PERFIL TEST, en un area de trabajo AISLADA (carpetas temporales
    via la seccion 'paths' de config.json, restaurada al terminar), y verifica cada salida
    con ffprobe: codec de video recodificado, pistas de audio/subtitulos correctas,
    subtitulo forzado que conserva 'default', y ausencia de etiquetas basura.

    No es interactivo: los .job.json se generan por adelantado (con la seleccion real de
    audio via Select-AudioStream y de subtitulos via ConvertTo-SubSel), de modo que
    Convert.ps1 entra directo como worker y codifica sin preguntar.

    Uso:
      powershell -ExecutionPolicy Bypass -File test\run-tests.ps1                 # GPU (hevc_nvenc)
      powershell -ExecutionPolicy Bypass -File test\run-tests.ps1 -Encoder libx265 # CPU (portable)
      powershell -ExecutionPolicy Bypass -File test\run-tests.ps1 -Keep            # no borra el area temporal
#>
[CmdletBinding()]
param(
    [ValidateSet('hevc_nvenc','h264_nvenc','libx265','libx264','copy')]
    [string]$Encoder = 'hevc_nvenc',
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = Split-Path -Parent $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
foreach ($m in @('Log','Config','Context','Console','Exec','Job','Tools','MediaInfo','Profile','Video','Audio','Subtitle','Multiplex')) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

$cfgPath = Join-Path $Root 'config.json'
$bakPath = "$cfgPath.testbak"

# --- Auto-reparacion: si un run anterior murio a mitad, restaurar el config antes de nada. ---
if (Test-Path -LiteralPath $bakPath) {
    Write-Host 'AVISO: restaurando config.json de un run anterior interrumpido.' -ForegroundColor Yellow
    Copy-Item -LiteralPath $bakPath -Destination $cfgPath -Force
    Remove-Item -LiteralPath $bakPath -Force
}

# --- Perfil test segun el encoder elegido ---
function New-TestProfile([string]$enc) {
    switch ($enc) {
        'hevc_nvenc' { New-CvProfile -Name 'test' -VideoEncoder 'hevc_nvenc' -VideoProfile 'main10' -VideoLevel '5' -Qmin 1 -Qmax 23 -AudioEncoder 'aac_coder' -AudioBitrate '128k' }
        'h264_nvenc' { New-CvProfile -Name 'test' -VideoEncoder 'h264_nvenc' -VideoLevel '5' -Qmin 1 -Qmax 23 -AudioEncoder 'aac_coder' -AudioBitrate '128k' }
        'libx265'    { New-CvProfile -Name 'test' -VideoEncoder 'libx265' -Crf 30 -AudioEncoder 'aac_coder' -AudioBitrate '128k' }
        'libx264'    { New-CvProfile -Name 'test' -VideoEncoder 'libx264' -Crf 30 -AudioEncoder 'aac_coder' -AudioBitrate '128k' }
        'copy'       { New-CvProfile -Name 'test' -VideoEncoder 'copy' -AudioEncoder 'copy' }
    }
}
$expectedVCodec = @{ hevc_nvenc='hevc'; libx265='hevc'; h264_nvenc='h264'; libx264='h264'; copy=$null }[$Encoder]

# --- Fixtures y lo que se espera de cada salida ---
#   subCount     : nº de subtitulos esperados en la salida
#   forcedDefault: si el (unico) subtitulo debe salir forced=1 default=1
#   audioMin     : nº minimo de pistas de audio esperadas
#   resize       : (opcional) escalado a aplicar en el job (p.ej. '1280:-1')
#   width        : (opcional) ancho esperado en la salida cuando hay resize
$expect = [ordered]@{
    # Muestras base (variedad de entrada): recodifican video, 1 audio, 0 subtitulos.
    'video-1080p-basico.mp4'                 = @{ subCount=0; forcedDefault=$false; audioMin=1; note='base 1080p h264' }
    'video-1080p-60fps-audio51-und.mp4'      = @{ subCount=0; forcedDefault=$false; audioMin=1; note='60 fps + audio 5.1' }
    'video-4k-2160p-resize.mp4'              = @{ subCount=0; forcedDefault=$false; audioMin=1; resize='1280:-1'; width=1280; note='RESIZE 4K -> 1280 de ancho' }
    'entrada-codec-h265.mp4'                 = @{ subCount=0; forcedDefault=$false; audioMin=1; note='entrada HEVC' }
    'entrada-codec-vp9.mp4'                  = @{ subCount=0; forcedDefault=$false; audioMin=1; note='entrada VP9' }
    'entrada-contenedor-avi-720p.avi'        = @{ subCount=0; forcedDefault=$false; audioMin=1; note='contenedor AVI' }
    'entrada-contenedor-mp4-1080p.mp4'       = @{ subCount=0; forcedDefault=$false; audioMin=1; note='contenedor MP4' }
    # Fixtures multipista (seleccion de audio/subtitulos).
    'subs-forzado-predefinido.mkv'           = @{ subCount=1; forcedDefault=$true;  audioMin=1; note='forzado+predefinido conserva default' }
    'audio-y-subs-multiidioma.mkv'           = @{ subCount=2; forcedDefault=$false; audioMin=1; note='elige spa; completo+forzado' }
    'subs-varios-completos-espanol-menu.mkv' = @{ subCount=2; forcedDefault=$false; audioMin=1; note='completo[0]+forzado (menu omitido)' }
    'audio-espanol-estereo-y-51.mkv'         = @{ subCount=0; forcedDefault=$false; audioMin=1; note='audio spa 5.1 seleccionado' }
    'audio-sin-espanol-fallback.mkv'         = @{ subCount=0; forcedDefault=$false; audioMin=1; note='sin spa -> audio default' }
    'subs-sin-espanol-descartar.mkv'         = @{ subCount=0; forcedDefault=$false; audioMin=1; note='subs no preferidos -> ninguno' }
    'pistas-orden-aleatorio.mkv'             = @{ subCount=1; forcedDefault=$true;  audioMin=1; note='orden sub/audio/video/audio/sub' }
}

$fixtures = @($expect.Keys | Where-Object { Test-Path -LiteralPath (Join-Path $PSScriptRoot $_) })
if ($fixtures.Count -eq 0) {
    Write-Host 'No hay fixtures en test\. Genera con test\generate-fixtures.ps1' -ForegroundColor Red
    exit 1
}

$work = Join-Path $env:TEMP ('cv-test-' + [guid]::NewGuid().ToString('N'))
$results = @()

Write-Host ''
Write-Host ('=== BATERIA DE TESTS (encoder={0}) ===' -f $Encoder) -ForegroundColor Cyan
Write-Host ('Area de trabajo temporal: {0}' -f $work)

Copy-Item -LiteralPath $cfgPath -Destination $bakPath -Force   # backup para restaurar
try {
    # --- Config temporal: paths -> area temporal, comportamiento contenido ---
    # Se parte del config FUSIONADO (defaults + overrides) para tener todas las secciones
    # aunque config.json sea minimo (solo overrides).
    $cfg = Get-CvConfig -Root $Root
    $cfg['paths']['original']   = (Join-Path $work 'Original')
    $cfg['paths']['proceso']    = (Join-Path $work 'Proceso')
    $cfg['paths']['convertido'] = (Join-Path $work 'Convertido')
    $cfg['paths']['logs']       = (Join-Path $work 'logs')
    $cfg['behavior']['separateWindow']  = $false   # codificar inline (no ventanas aparte)
    $cfg['behavior']['lockCloseButton'] = $false   # no tocar el boton X de la ventana
    $cfg['behavior']['log']             = $false   # sin transcript
    Save-CvConfigFile -Path $cfgPath -Config $cfg

    $ctx  = New-CvContext -Root $Root   # ya apunta al area temporal y crea las carpetas
    $prof = New-TestProfile $Encoder

    # --- Preparar: copiar fixtures + escribir sus .job.json (seleccion real, sin menus) ---
    Write-Host ''
    Write-Host '--- Preparando jobs ---'
    foreach ($fx in $fixtures) {
        $src  = Join-Path $PSScriptRoot $fx
        $name = [System.IO.Path]::GetFileNameWithoutExtension($fx)
        $exp  = $expect[$fx]
        Copy-Item -LiteralPath $src -Destination (Join-Path $ctx.Original $fx) -Force
        $info = Get-MediaInfo -Context $ctx -File $src

        # Audio: seleccion real (spa > default > 5.1 > primera). Guardamos idioma/is51 para el informe.
        $aSel = Select-AudioStream -Info $info -PrefLangs $ctx.AudioLangs
        $aSkip = ($prof.AudioEncoder -eq 'copy') -or ($null -eq $aSel)
        $aIdx  = if ($aSel) { $aSel.Index } else { 0 }

        # Subtitulos: misma logica que Select-Subtitles pero sin menu (completo[0] + forzados),
        # usando las funciones reales (ConvertTo-SubSel conserva el 'default' original del forzado).
        $subSel = @()
        $subs = @(Get-SubtitleStreams -Info $info)
        $pref = @($subs | Where-Object { Test-CvLanguage (Get-Tag $_ 'language') $ctx.SubLangs })
        $full = @($pref | Where-Object { -not (Test-SubForced $_) })
        $forc = @($pref | Where-Object { Test-SubForced $_ })
        if ($full.Count -ge 1) { $subSel += (ConvertTo-SubSel $full[0] -Default $true) }
        foreach ($fs in $forc) { $subSel += (ConvertTo-SubSel $fs) }

        $vSkip = ($prof.VideoEncoder -eq 'copy')
        $job = [ordered]@{
            file           = (Join-Path $ctx.Original $fx)
            profile        = $prof
            ffmpegVersion  = $ctx.FFmpegVersion
            aacgainVersion = $ctx.AacGainVersion
            video          = @{ skip = $vSkip; crop = ''; resize = [string]$exp['resize']; anim = $false }
            audio          = @{ skip = $aSkip; index = $aIdx; is51 = [bool]($aSel -and $aSel.Is51); sync = 0 }
            subtitles      = @($subSel)
        }
        Write-CvJob -Context $ctx -Name $name -Job $job
        Write-Host ('  job: {0}   audio->idx {1} ({2}{3})   subs->{4}' -f `
            $fx, $aIdx, $(if($aSel){$aSel.Language}else{'-'}), $(if($aSel -and $aSel.Is51){' 5.1'}else{''}), $subSel.Count)
    }

    # --- Ejecutar el Convert.ps1 REAL (entra como worker porque todo tiene job) ---
    Write-Host ''
    Write-Host '--- Ejecutando Convert.ps1 (worker) ---' -ForegroundColor Cyan
    $bg = $host.UI.RawUI.BackgroundColor; $fg = $host.UI.RawUI.ForegroundColor
    # ffmpeg/Convert.ps1 escriben progreso a stderr; con ErrorActionPreference=Stop eso se
    # volveria un error terminante en el padre, asi que aislamos la llamada al proceso hijo.
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    # Mostrar solo las lineas de log del conversor (no el volcado de progreso de ffmpeg).
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Convert.ps1') 2>&1 |
        ForEach-Object {
            $t = "$_"
            if ($t -match '\[(WORKER|GLOBAL|AUDIO|VIDEO|MULTIPLEX|SUB)\]' -or $t -match 'Error|ERROR') {
                Write-Host ('   | ' + $t)
            }
        }
    $ErrorActionPreference = $old
    try { $host.UI.RawUI.BackgroundColor = $bg; $host.UI.RawUI.ForegroundColor = $fg } catch {}

    # --- Verificar cada salida ---
    Write-Host ''
    Write-Host '--- Verificando salidas ---' -ForegroundColor Cyan
    foreach ($fx in $fixtures) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($fx)
        $out  = Get-OutputPath $ctx $name
        $exp  = $expect[$fx]
        $errs = @()

        if (-not (Test-Path -LiteralPath $out)) {
            $results += [pscustomobject]@{ Fixture=$fx; Estado='FAIL'; Detalle='no se genero la salida' }
            continue
        }
        $oi = Get-MediaInfo -Context $ctx -File $out
        $vs = @($oi.streams | Where-Object { $_.codec_type -eq 'video' })
        $as = @($oi.streams | Where-Object { $_.codec_type -eq 'audio' })
        $ss = @($oi.streams | Where-Object { $_.codec_type -eq 'subtitle' })

        # 1) video recodificado al codec esperado (salvo copy)
        if ($expectedVCodec) {
            if ($vs.Count -lt 1)                        { $errs += 'sin pista de video' }
            elseif ($vs[0].codec_name -ne $expectedVCodec) { $errs += ("video={0}!={1}" -f $vs[0].codec_name, $expectedVCodec) }
        }
        # 1b) resize aplicado: el ancho de salida debe coincidir (no aplica en modo copy)
        if ($exp['width'] -and $Encoder -ne 'copy') {
            if ($vs.Count -lt 1 -or [int]$vs[0].width -ne [int]$exp['width']) {
                $errs += ("ancho={0}!={1}" -f $(if ($vs.Count) { $vs[0].width } else { '-' }), $exp['width'])
            }
        }
        # 2) recuentos de audio / subtitulos
        if ($as.Count -lt $exp.audioMin) { $errs += ("audio={0}<{1}" -f $as.Count, $exp.audioMin) }
        if ($ss.Count -ne $exp.subCount) { $errs += ("subs={0}!={1}" -f $ss.Count, $exp.subCount) }
        # 3) subtitulo forzado que conserva default (bug #1)
        if ($exp.forcedDefault -and $ss.Count -ge 1) {
            $d = $ss[0].disposition
            if (-not ($d.forced -eq 1 -and $d.default -eq 1)) { $errs += ("sub forced/default={0}/{1}!=1/1" -f $d.forced, $d.default) }
        }
        # 4) sin NINGUNA etiqueta (bug #2 + limpieza mkvpropedit): solo se permite language/title.
        #    Incluye la ausencia del DURATION por pista que quita mkvpropedit --tags all:.
        foreach ($s in $oi.streams) {
            if ($s.PSObject.Properties['tags'] -and $s.tags) {
                $dirty = @($s.tags.PSObject.Properties.Name | Where-Object { $_ -notin @('language','title') })
                if ($dirty.Count -gt 0) { $errs += ("tags[{0}]={1}" -f $s.codec_type, ($dirty -join ',')) }
            }
        }

        if ($errs.Count -eq 0) {
            $res = if ($vs.Count) { "{0} {1}x{2}" -f $vs[0].codec_name, $vs[0].width, $vs[0].height } else { '-' }
            $results += [pscustomobject]@{ Fixture=$fx; Estado='PASS'; Detalle=("v={0} a={1} s={2}  {3}" -f $res, $as.Count, $ss.Count, $exp.note) }
        } else {
            $results += [pscustomobject]@{ Fixture=$fx; Estado='FAIL'; Detalle=($errs -join '; ') }
        }
    }
}
finally {
    # Restaurar SIEMPRE el config.json original.
    if (Test-Path -LiteralPath $bakPath) {
        Copy-Item -LiteralPath $bakPath -Destination $cfgPath -Force
        Remove-Item -LiteralPath $bakPath -Force
    }
    if (-not $Keep -and (Test-Path -LiteralPath $work)) {
        Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
    } elseif ($Keep) {
        Write-Host ("`nArea temporal conservada en: {0}" -f $work) -ForegroundColor Yellow
    }
}

# --- Informe ---
Write-Host ''
Write-Host '================= RESULTADO =================' -ForegroundColor Cyan
foreach ($r in $results) {
    $col = if ($r.Estado -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ('  [{0}] {1}' -f $r.Estado, $r.Fixture) -ForegroundColor $col
    Write-Host ('         {0}' -f $r.Detalle) -ForegroundColor DarkGray
}
$pass = @($results | Where-Object { $_.Estado -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.Estado -eq 'FAIL' }).Count
Write-Host ''
Write-Host ('  TOTAL: {0} PASS / {1} FAIL' -f $pass, $fail) -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
exit $(if ($fail -eq 0) { 0 } else { 1 })
