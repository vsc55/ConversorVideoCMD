<#
    generate-fixtures.ps1 - Version Windows/PowerShell de generate-fixtures.sh.
    Regenera las fixtures multipista (*.mkv) de test\ a partir de la muestra base
    video-1080p-basico.mp4 (fuente: samplelib.com) + pistas sinteticas.
    Documentacion (que prueba cada fixture, fuentes/licencias): docs\pruebas.md
    Uso:  powershell -ExecutionPolicy Bypass -File test\generate-fixtures.ps1
    Requiere ffmpeg (usa el de tools\ si existe, si no el del PATH).
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$FF = Join-Path $root 'tools\ffmpeg\7.1.1\x64\ffmpeg.exe'
if (-not (Test-Path -LiteralPath $FF)) {
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($cmd) { $FF = $cmd.Source } else { throw 'No se encuentra ffmpeg (ni en tools\ ni en el PATH).' }
}
$base = Join-Path $root 'test\video-1080p-basico.mp4'
if (-not (Test-Path -LiteralPath $base)) { throw "Falta $base (descargar de samplelib.com)." }

$tmp = Join-Path $env:TEMP ('cv-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # --- Subtitulos SRT sinteticos ---
    $forced = "1`r`n00:00:01,000 --> 00:00:03,000`r`n[texto forzado]`r`n`r`n2`r`n00:00:04,000 --> 00:00:05,000`r`n[texto forzado]`r`n"
    $full   = "1`r`n00:00:00,500 --> 00:00:02,500`r`nDialogo completo linea 1.`r`n`r`n2`r`n00:00:03,000 --> 00:00:05,000`r`nDialogo completo linea 2.`r`n"
    $full2  = "1`r`n00:00:00,500 --> 00:00:02,500`r`n[door creaks] Full SDH.`r`n`r`n2`r`n00:00:03,000 --> 00:00:05,000`r`n[music] Full SDH.`r`n"
    $sForced = Join-Path $tmp 'forced.srt'; $sFull = Join-Path $tmp 'full.srt'; $sFull2 = Join-Path $tmp 'full2.srt'
    Set-Content -LiteralPath $sForced -Value $forced -Encoding Ascii -NoNewline
    Set-Content -LiteralPath $sFull   -Value $full   -Encoding Ascii -NoNewline
    Set-Content -LiteralPath $sFull2  -Value $full2  -Encoding Ascii -NoNewline

    function New-Fixture {
        param([string[]]$FfArgs, [Parameter(Mandatory)][string]$Out)
        # ffmpeg escribe su progreso a stderr; con ErrorActionPreference=Stop eso se
        # convertiria en un error terminante, asi que aislamos la llamada nativa.
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & $FF -hide_banner -y @FfArgs 2>&1 | Out-Null
        $code = $LASTEXITCODE
        $ErrorActionPreference = $old
        if ($code -ne 0 -or -not (Test-Path -LiteralPath $Out)) { throw "Fallo generando $Out (ffmpeg=$code)" }
        Write-Host ('  OK  {0}' -f (Split-Path $Out -Leaf)) -ForegroundColor Green
    }

    # subtitulo forzado + predefinido (regresion del flag default)
    $o = 'test\subs-forzado-predefinido.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-i',$sForced,'-i',$sFull2,
        '-map','0:v:0','-map','0:a:0','-map','1:0','-map','2:0','-c:v','copy','-c:a','copy','-c:s','srt',
        '-metadata:s:a:0','language=spa','-metadata:s:a:0','title=European',
        '-metadata:s:s:0','language=spa','-metadata:s:s:0','title=European (Forced)','-disposition:s:0','default+forced',
        '-metadata:s:s:1','language=eng','-metadata:s:s:1','title=SDH','-disposition:s:1','0',
        '-f','matroska',$o)

    # audio spa/eng/fra + subs spa-full/spa-forced/eng/fra-forced
    $o = 'test\audio-y-subs-multiidioma.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-i',$sFull,'-i',$sForced,'-i',$sFull2,'-i',$sForced,
        '-map','0:v:0','-map','0:a:0','-map','0:a:0','-map','0:a:0','-map','1:0','-map','2:0','-map','3:0','-map','4:0',
        '-c:v','copy','-c:a','copy','-c:s','srt',
        '-metadata:s:a:0','language=spa','-metadata:s:a:0','title=Castellano','-disposition:a:0','default',
        '-metadata:s:a:1','language=eng','-metadata:s:a:1','title=English','-disposition:a:1','0',
        '-metadata:s:a:2','language=fra','-metadata:s:a:2','title=Francais','-disposition:a:2','0',
        '-metadata:s:s:0','language=spa','-metadata:s:s:0','title=Castellano','-disposition:s:0','default',
        '-metadata:s:s:1','language=spa','-metadata:s:s:1','title=Castellano (Forzados)','-disposition:s:1','forced',
        '-metadata:s:s:2','language=eng','-metadata:s:s:2','title=English','-disposition:s:2','0',
        '-metadata:s:s:3','language=fra','-metadata:s:s:3','title=Francais (Forces)','-disposition:s:3','forced',
        '-f','matroska',$o)

    # 2 completos spa + forzado spa + eng (menu de subtitulo)
    $o = 'test\subs-varios-completos-espanol-menu.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-i',$sFull,'-i',$sFull2,'-i',$sForced,'-i',$sFull2,
        '-map','0:v:0','-map','0:a:0','-map','1:0','-map','2:0','-map','3:0','-map','4:0','-c:v','copy','-c:a','copy','-c:s','srt',
        '-metadata:s:a:0','language=spa',
        '-metadata:s:s:0','language=spa','-metadata:s:s:0','title=Castellano','-disposition:s:0','default',
        '-metadata:s:s:1','language=spa','-metadata:s:s:1','title=Castellano (SDH)',
        '-metadata:s:s:2','language=spa','-metadata:s:s:2','title=Castellano (Forzados)','-disposition:s:2','forced',
        '-metadata:s:s:3','language=eng','-metadata:s:s:3','title=English',
        '-f','matroska',$o)

    # audio spa 2.0 + spa 5.1 + eng (preferencia 5.1 / menu audio)
    $o = 'test\audio-espanol-estereo-y-51.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-f','lavfi','-t','6','-i','anullsrc=channel_layout=5.1:sample_rate=48000',
        '-map','0:v:0','-map','0:a:0','-map','1:0','-map','0:a:0','-shortest','-c:v','copy','-c:a','aac','-b:a','128k',
        '-metadata:s:a:0','language=spa','-metadata:s:a:0','title=Castellano 2.0',
        '-metadata:s:a:1','language=spa','-metadata:s:a:1','title=Castellano 5.1',
        '-metadata:s:a:2','language=eng','-metadata:s:a:2','title=English',
        '-f','matroska',$o)

    # audio eng(default) + fra, sin spa (fallback al default)
    $o = 'test\audio-sin-espanol-fallback.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,
        '-map','0:v:0','-map','0:a:0','-map','0:a:0','-c:v','copy','-c:a','copy',
        '-metadata:s:a:0','language=eng','-metadata:s:a:0','title=English','-disposition:a:0','default',
        '-metadata:s:a:1','language=fra','-metadata:s:a:1','title=Francais','-disposition:a:1','0',
        '-f','matroska',$o)

    # audio spa + subs eng + fra (subs no preferidos -> ninguno)
    $o = 'test\subs-sin-espanol-descartar.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-i',$sFull,'-i',$sFull2,
        '-map','0:v:0','-map','0:a:0','-map','1:0','-map','2:0','-c:v','copy','-c:a','copy','-c:s','srt',
        '-metadata:s:a:0','language=spa',
        '-metadata:s:s:0','language=eng','-metadata:s:s:0','title=English',
        '-metadata:s:s:1','language=fra','-metadata:s:s:1','title=Francais',
        '-f','matroska',$o)

    # orden fisico de pistas: sub, audio, video, audio, sub
    $o = 'test\pistas-orden-aleatorio.mkv'
    New-Fixture -Out $o -FfArgs @(
        '-i',$base,'-i',$sForced,'-i',$sFull2,
        '-map','1:0','-map','0:a:0','-map','0:v:0','-map','0:a:0','-map','2:0','-c:v','copy','-c:a','copy','-c:s','srt',
        '-metadata:s:s:0','language=spa','-metadata:s:s:0','title=Castellano (Forzados)','-disposition:s:0','default+forced',
        '-metadata:s:a:0','language=spa','-metadata:s:a:0','title=Castellano','-disposition:a:0','default',
        '-metadata:s:a:1','language=eng','-metadata:s:a:1','title=English',
        '-metadata:s:s:1','language=eng','-metadata:s:s:1','title=English',
        '-f','matroska',$o)

    Write-Host 'Fixtures regeneradas en test\' -ForegroundColor Cyan
}
finally {
    Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
}
