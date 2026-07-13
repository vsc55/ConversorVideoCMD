<#
    FixSyncSub.ps1 - Corrige y sincroniza subtitulos .srt (asistente interactivo).

    Es una herramienta aparte del conversor (no se mete en Convert.ps1), pero comparte su config y sus
    piezas: arranca con Start-CvSession (mismo config.json y argumento -Config), reutiliza los menus de
    lib\Console.psm1 y toda la logica de .srt vive en lib\Subtitle.psm1 (funciones *-CvSrt*), asi que
    queda disponible tambien para futuras funciones del conversor.

    Hace, en este orden (todo opcional):
      1. Detecta la codificacion de entrada y la normaliza a UTF-8.
      2. Correcciones de texto: OCR (l->I en mayusculas), espaciado tras los signos invertidos, y
         sustituciones manuales (buscar=reemplazar) para nombres propios.
      3. Sincronizacion (modelo lineal t' = A*t + B): offset, lineal por 2 cues, por tramos, o por extremos.

    Uso:  .\FixSyncSub.ps1 [-Config <ruta>] [ruta.srt]      (o arrastra un .srt sobre FixSyncSub.cmd)
          Sin ruta: lista los .srt de la carpeta Original\ (segun el config) para elegir.
#>
param([string]$Path = '', [string]$Config = '')

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
$modules = @(
    'Log'
    'Config'
    'Context'
    'Console'
    'Exec'
    'Job'
    'Tools'
    'MediaInfo'
    'Profile'
    'Video'
    'Audio'
    'Subtitle'
    'SubtitleSRT'
    'Attachment'
    'Multiplex'
)
foreach ($m in $modules) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

# Arranque comun (mismo config/-Config, apariencia, cabecera y log que Convert.ps1 / setup.ps1).
$sess = Start-CvSession -Root $Root -Config $Config -TitleSuffix ' - FixSyncSub' -Subtitle 'FixSyncSub' -LogPrefix 'FixSyncSub'
$ctx  = $sess.Context

# ---------- seleccion del .srt ----------
function Select-SrtFile {
    param($Context)
    $dir = "$($Context.Original)"
    if (-not (Test-Path -LiteralPath $dir)) { return (Read-CvLine -Prompt '  Ruta del .srt').Trim('"') }
    $subs = @(Get-CvFiles -Dir $dir -Filters '*.srt' -Recurse -Exact)
    if ($subs.Count -eq 0) {
        Write-CvLog 'SUB' ("[AVISO] - No hay .srt en {0}" -f $dir) -Indent 3
        return (Read-CvLine -Prompt '  Ruta del .srt').Trim('"')
    }
    $rels = $subs | ForEach-Object { $_.FullName.Substring($dir.Length).TrimStart('\') }
    $sel = Select-FromList -Title ("Subtitulos (.srt) en {0}" -f $dir) -Options $rels -NoneLabel 'otra ruta (escribir)'
    if ([string]::IsNullOrEmpty($sel)) { return (Read-CvLine -Prompt '  Ruta del .srt').Trim('"') }
    Join-Path $dir $sel
}

# ---------- lectura de una ancla (numero de cue + tiempo real) ----------
function Read-SrtAnchor {
    param([string[]]$Blocks, [string]$Label, [ref]$Srt, [ref]$Real)
    $n = [int](Read-CvLine -Prompt ("    {0}: numero de cue" -f $Label)).Trim()
    $cur = Get-CvSrtCueStart -Blocks $Blocks -Num $n
    if ($null -eq $cur) { throw "No encuentro la cue $n" }
    Write-CvLog 'SUB' ("cue {0} esta ahora en {1}" -f $n, (ConvertTo-CvSrtStamp $cur)) -Indent 5
    $rt = ConvertTo-CvSrtSeconds (Read-CvLine -Prompt '      tiempo REAL en el video (h:mm:ss.mmm)').Trim()
    if ($null -eq $rt) { throw 'tiempo no valido' }
    $Srt.Value = $cur; $Real.Value = $rt
}

# ============================================================
# 1) Entrada
if (-not $Path) { $Path = Select-SrtFile -Context $ctx }
$Path = "$Path".Trim('"').Trim()
if (-not (Test-Path -LiteralPath $Path)) { Write-CvLog 'SUB' ("[ERROR] - No existe: {0}" -f $Path) -Indent 3; exit 1 }
$Path = (Resolve-Path -LiteralPath $Path).Path

$text  = Read-CvSrtText -Path $Path
$blocks = @(Get-CvSrtBlocks $text)
Write-CvLog 'SUB' ("[INFO] - {0}  ({1} cues)" -f (Split-Path -Leaf $Path), $blocks.Count) -Indent 3

# 2) Correcciones de texto
if (Read-YesNo '  Corregir OCR (l->I en mayusculas) y espaciado (signos invertidos)?' $true) {
    $r1 = Repair-CvSrtOcr $text
    $r2 = Repair-CvSrtSpacing $r1.Text
    $text = $r2.Text
    Write-CvLog 'SUB' ("OCR corregidos: {0}   espaciados: {1}" -f $r1.Changed.Count, $r2.Count) -Indent 5
    $r1.Changed | Select-Object -Unique | ForEach-Object { Write-CvLog 'SUB' "$_" -Indent 7 }
    if (Read-YesNo '  Anadir sustituciones manuales (buscar=reemplazar)?' $false) {
        while ($true) {
            $r = (Read-CvLine -Prompt '    buscar=reemplazar (vacio para terminar)').Trim()
            if ($r -eq '') { break }
            $i = $r.IndexOf('=')
            if ($i -lt 1) { Write-CvLog 'SUB' '[AVISO] - formato invalido (usa buscar=reemplazar)' -Indent 5; continue }
            $find = $r.Substring(0, $i); $repl = $r.Substring($i + 1)
            $c = ([regex]::Matches($text, [regex]::Escape($find))).Count
            $text = $text.Replace($find, $repl)
            Write-CvLog 'SUB' ("'{0}' -> '{1}'  ({2} veces)" -f $find, $repl, $c) -Indent 5
        }
    }
    $blocks = @(Get-CvSrtBlocks $text)
}

# 3) Sincronizacion
$syncOpts = @(
    @{ Value = 'no';       Text = 'no sincronizar' }
    @{ Value = 'offset';   Text = 'offset constante (adelanta/retrasa todo por igual)' }
    @{ Value = 'lineal';   Text = 'lineal por 2 cues (escala + desplazamiento)' }
    @{ Value = 'tramos';   Text = 'por tramos (deja intactas las cues anteriores a N)' }
    @{ Value = 'extremos'; Text = 'por extremos (primer y ultimo subtitulo)' }
)
$mode = Select-FromList -Title 'Sincronizacion' -Options $syncOpts -DefaultValue 'no' -NoNone

$A = 1.0; $B = 0.0; $fromCue = 1; $doSync = $true
switch ($mode) {
    'offset' {
        $off = ConvertTo-CvSrtSeconds (Read-CvLine -Prompt '    Offset en segundos (+ retrasa, - adelanta), o vacio para darlo por cue').Trim()
        if ($null -eq $off) { $s1 = 0.0; $r1 = 0.0; Read-SrtAnchor $blocks 'Referencia' ([ref]$s1) ([ref]$r1); $off = $r1 - $s1 }
        $A = 1.0; $B = $off
        Write-CvLog 'SUB' ("offset = {0:N3}s" -f $B) -Indent 5
    }
    'lineal' {
        $s1 = 0.0; $r1 = 0.0; $s2 = 0.0; $r2 = 0.0
        Read-SrtAnchor $blocks 'Punto 1' ([ref]$s1) ([ref]$r1)
        Read-SrtAnchor $blocks 'Punto 2' ([ref]$s2) ([ref]$r2)
        $fit = Get-CvSrtLinearFit $s1 $r1 $s2 $r2
        if ($null -eq $fit) { throw 'los dos puntos no pueden ser la misma cue' }
        $A = $fit.A; $B = $fit.B
        Write-CvLog 'SUB' ("A={0:N6}  B={1:N3}s" -f $A, $B) -Indent 5
    }
    'tramos' {
        $fromCue = [int](Read-CvLine -Prompt '    Aplicar DESDE el cue numero (las anteriores no se tocan)').Trim()
        $s1 = 0.0; $r1 = 0.0; $s2 = 0.0; $r2 = 0.0
        Read-SrtAnchor $blocks 'Punto 1 (>= ese cue)' ([ref]$s1) ([ref]$r1)
        Read-SrtAnchor $blocks 'Punto 2 (>= ese cue)' ([ref]$s2) ([ref]$r2)
        $fit = Get-CvSrtLinearFit $s1 $r1 $s2 $r2
        if ($null -eq $fit) { throw 'los dos puntos no pueden ser la misma cue' }
        $A = $fit.A; $B = $fit.B
        Write-CvLog 'SUB' ("desde cue {0}:  A={1:N6}  B={2:N3}s" -f $fromCue, $A, $B) -Indent 5
    }
    'extremos' {
        # Por extremos: primer subtitulo A AJUSTAR (ENTER = el 1o, o empiezas en otro si el principio
        # ya esta bien) y el ULTIMO. Las cues anteriores al de inicio quedan intactas.
        $startAns = (Read-CvLine -Prompt '    Desde que subtitulo ajustar? (numero, ENTER = el primero)').Trim()
        if ($startAns -eq '') { $first = $blocks[0] }
        else {
            $sc = [int]$startAns
            $first = $blocks | Where-Object { (Get-CvSrtBlockNum $_) -eq $sc } | Select-Object -First 1
            if (-not $first) { throw "No encuentro la cue $sc" }
        }
        $last = $blocks[-1]
        $fromCue = Get-CvSrtBlockNum $first
        $lastNum = Get-CvSrtBlockNum $last
        $srtF = Get-CvSrtCueStart -Blocks $blocks -Num $fromCue
        $srtL = Get-CvSrtCueStart -Blocks $blocks -Num $lastNum
        Write-CvLog 'SUB' ("PRIMER subtitulo a ajustar (cue {0}) esta en {1}" -f $fromCue, (ConvertTo-CvSrtStamp $srtF)) -Indent 5
        $realF = ConvertTo-CvSrtSeconds (Read-CvLine -Prompt '      tiempo REAL de esa cue (h:mm:ss.mmm)').Trim()
        Write-CvLog 'SUB' ("ULTIMO subtitulo (cue {0}) esta en {1}" -f $lastNum, (ConvertTo-CvSrtStamp $srtL)) -Indent 5
        $realL = ConvertTo-CvSrtSeconds (Read-CvLine -Prompt '      tiempo REAL del ULTIMO subtitulo (h:mm:ss.mmm)').Trim()
        if ($null -eq $realF -or $null -eq $realL) { throw 'tiempo no valido' }
        $fit = Get-CvSrtLinearFit $srtF $realF $srtL $realL
        if ($null -eq $fit) { throw 'las dos referencias no pueden coincidir' }
        $A = $fit.A; $B = $fit.B
        if ($fromCue -gt 1) { Write-CvLog 'SUB' ("cues 1..{0} sin tocar" -f ($fromCue - 1)) -Indent 5 }
        Write-CvLog 'SUB' ("desde cue {0}:  A={1:N6}  B={2:N3}s" -f $fromCue, $A, $B) -Indent 5
    }
    default { $doSync = $false }
}
if ($doSync) { $text = Invoke-CvSrtResync -Text $text -A $A -B $B -FromCue $fromCue }

# 4) Salida
$dir  = Split-Path -Parent $Path
$base = [IO.Path]::GetFileNameWithoutExtension($Path)
$defOut = Join-Path $dir ("{0}.es.srt" -f $base)
$outPath = (Read-CvLine -Prompt ("  Guardar en [{0}]" -f $defOut)).Trim()
if ($outPath -eq '') { $outPath = $defOut } else { $outPath = $outPath.Trim('"') }
$withBom = Read-YesNo '  Escribir con BOM (UTF-8)?' $false
Write-CvSrtText -Text $text -Path $outPath -Bom $withBom

Write-Host ''
Write-CvLog 'SUB' ("[OK] - {0}" -f $outPath) -Indent 3
