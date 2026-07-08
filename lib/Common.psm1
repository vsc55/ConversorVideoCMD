<#
    Common.psm1 - Contexto, rutas, herramientas, jobs y bloqueo.
    Compatible con PowerShell 5.1.
#>

function Merge-CvConfig {
    <#
        Fusiona (en sitio) $Override (objeto de JSON) sobre $Default (ordered hashtable),
        recorriendo secciones anidadas. Los escalares y arrays se reemplazan; las
        subsecciones (objetos) se fusionan recursivamente para no perder claves ausentes.
    #>
    param($Default, $Override)
    if ($null -eq $Override) { return }
    # Sobreescribir/fusionar las claves existentes.
    foreach ($key in @($Default.Keys)) {
        if ($Override.PSObject.Properties[$key] -and $null -ne $Override.$key) {
            $dv = $Default[$key]
            $ov = $Override.$key
            if ($dv -is [System.Collections.IDictionary] -and $ov -is [System.Management.Automation.PSCustomObject]) {
                Merge-CvConfig -Default $dv -Override $ov
            } else {
                $Default[$key] = $ov
            }
        }
    }
    # Anadir claves nuevas que solo estan en el override (ej: versiones de ffmpeg extra).
    foreach ($prop in $Override.PSObject.Properties) {
        if (-not $Default.Contains($prop.Name) -and $null -ne $prop.Value) {
            $Default[$prop.Name] = $prop.Value
        }
    }
}

function Get-CvConfig {
    <#
        Carga config.json (si existe) sobre los valores por defecto, por secciones.
        Cualquier clave ausente en el json usa el valor por defecto (fusion profunda).
    #>
    param([Parameter(Mandatory)][string]$Root)
    $langs = @('spa','es','esp','es-es','es_es','castellano','spanish')
    $cfg = [ordered]@{
        downloads = [ordered]@{
            ffmpeg = [ordered]@{
                selected     = '8.1.2'
                type         = 'zip'
                url          = 'https://github.com/GyanD/codexffmpeg/releases/download/{version}/ffmpeg-{version}-full_build.zip'
                binPath      = 'ffmpeg-{version}-full_build/bin'
                files        = @('ffmpeg.exe','ffprobe.exe','ffplay.exe')
                dest         = 'tools\x64'
                versionExe   = 'ffmpeg.exe'
                versionArgs  = @('-version')
                versionRegex = 'ffmpeg version (\d+\.\d+(?:\.\d+)?)'
                versions = [ordered]@{
                    '8.1.2' = 'b8cdefab5f50590a076c27c2b56b0294a0e6154faded28ba1ba05ebc4f801f57'
                    '5.1.2' = '1f4056c147694228fddaeb925083338e35d952e4b65e3bd3c5a0a2c13c7800d6'
                }
            }
            aacgain = [ordered]@{
                selected     = '2.0.0'
                type         = 'file'
                url          = 'https://github.com/dgilman/aacgain/releases/download/{version}/aacgain-{version}-windows-amd64.exe'
                files        = @('aacgain.exe')
                dest         = 'tools'
                versionExe   = 'aacgain.exe'
                versionArgs  = @('/v')
                versionRegex = '[Vv]ersion (\d+\.\d+(?:\.\d+)?)'
                versions     = [ordered]@{
                    '2.0.0' = 'd960cedbd274881badd3dd914475ca23bb31c27b3a5cab881ff0d1515a37371a'
                }
            }
        }
        languages = [ordered]@{ audio = $langs; subtitle = $langs }
        encode    = [ordered]@{ outputExtension = 'mkv'; threads = 0; fps = '23.976'; audioHz = 44100 }
        border    = [ordered]@{ start = 120; duration = 120 }
        volume    = [ordered]@{ method = 'peak'; loudnorm = [ordered]@{ I = -16; TP = -1.5; LRA = 11 } }
        behavior  = [ordered]@{ cleanTemps = $true; separateWindow = $true; lockCloseButton = $true; debug = $false; log = $true }
        console   = [ordered]@{ background = 'DarkBlue'; foreground = 'Yellow'; font = 'Consolas'; fontSize = 18; windowWidth = 100; windowHeight = 50 }
    }
    $path = Join-Path $Root 'config.json'
    if (Test-Path $path) {
        try {
            $json = Get-Content -Raw -Path $path | ConvertFrom-Json
            Merge-CvConfig -Default $cfg -Override $json
        } catch {
            Write-Host ("AVISO: config.json no valido, se usan valores por defecto ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return $cfg
}

function Get-CvWorkDirs {
    <# Unica fuente de verdad de las carpetas de trabajo del proyecto (crear/comprobar). #>
    param([Parameter(Mandatory)]$Context)
    @($Context.Original, $Context.Proceso, $Context.Convertido, $Context.Tools, $Context.Logs)
}

function New-CvContext {
    <# Crea el objeto de contexto con rutas, herramientas y opciones (de config.json). #>
    param([Parameter(Mandatory)][string]$Root)

    $cfg = Get-CvConfig -Root $Root
    $plat  = Get-CvPlatform
    $ffSel = "$($cfg.downloads.ffmpeg.selected)"
    $agSel = "$($cfg.downloads.aacgain.selected)"

    $ctx = [pscustomobject]@{
        Root           = $Root
        Original       = Join-Path $Root 'Original'
        Proceso        = Join-Path $Root 'Proceso'
        Convertido     = Join-Path $Root 'Convertido'
        Tools          = Join-Path $Root 'tools'
        Logs           = Join-Path $Root 'logs'
        # Rutas de herramientas: las rellena New-CvToolContext mas abajo (fuente unica de
        # los nombres de exe), apuntando a la version 'selected'.
        FFmpeg         = $null
        FFprobe        = $null
        FFplay         = $null
        AacGain        = $null
        FFmpegVersion  = $ffSel
        AacGainVersion = $agSel
        Platform       = $plat
        Downloads      = $cfg.downloads
        VolumeMethod   = "$($cfg.volume.method)"
        LoudnormI      = $cfg.volume.loudnorm.I
        LoudnormTP     = $cfg.volume.loudnorm.TP
        LoudnormLRA    = $cfg.volume.loudnorm.LRA
        OutExt         = "$($cfg.encode.outputExtension)"
        Threads        = [int]$cfg.encode.threads
        Fps            = "$($cfg.encode.fps)"
        DefaultAudioHz = [int]$cfg.encode.audioHz
        BorderStart    = [int]$cfg.border.start
        BorderDur      = [int]$cfg.border.duration
        AudioLangs     = @($cfg.languages.audio)
        SubLangs       = @($cfg.languages.subtitle)
        # debug: desde config.json o creando el marcador 'debug_on' (cualquiera lo activa).
        Debug          = ([bool]$cfg.behavior.debug -or (Test-Path (Join-Path $Root 'debug_on')))
        # cleanTemps/separateWindow salen de config.json; los marcadores 'keep_temp' y
        # 'same_window' los desactivan sobre la marcha sin editar el json.
        CleanTemps     = ([bool]$cfg.behavior.cleanTemps     -and -not (Test-Path (Join-Path $Root 'keep_temp')))
        SeparateWindow = ([bool]$cfg.behavior.separateWindow -and -not (Test-Path (Join-Path $Root 'same_window')))
        LockClose      = [bool]$cfg.behavior.lockCloseButton
        # log: transcript de la ejecucion a logs\; el marcador 'no_log' lo desactiva.
        Log            = ([bool]$cfg.behavior.log -and -not (Test-Path (Join-Path $Root 'no_log')))
        ConsoleBackground = "$($cfg.console.background)"
        ConsoleForeground = "$($cfg.console.foreground)"
        ConsoleFont       = "$($cfg.console.font)"
        ConsoleFontSize   = [int]$cfg.console.fontSize
        WindowWidth       = [int]$cfg.console.windowWidth
        WindowHeight      = [int]$cfg.console.windowHeight
        Extensions     = @('*.avi','*.flv','*.mp4','*.mov','*.mkv')
    }

    # Rutas de las herramientas para la version 'selected' (fuente unica en New-CvToolContext).
    $ctx = New-CvToolContext -Context $ctx -FFmpegVersion $ffSel -AacGainVersion $agSel

    # Crear las carpetas de trabajo que falten (lista en Get-CvWorkDirs).
    foreach ($d in (Get-CvWorkDirs -Context $ctx)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
    }
    return $ctx
}

function Test-CvLanguage {
    <#
        Compara un codigo de idioma con una lista de preferidos, normalizando variantes:
        'es_es', 'es-ES', 'es' y 'spa' se consideran el mismo idioma si estan en la lista.
        Compara tanto el codigo completo como su parte principal (antes de '-' o '_').
    #>
    param([string]$Lang, [string[]]$Prefs)
    if ([string]::IsNullOrWhiteSpace($Lang) -or $null -eq $Prefs) { return $false }
    $l = $Lang.Trim().ToLower()
    $primary = ($l -split '[-_]')[0]
    foreach ($p in $Prefs) {
        if ($null -eq $p) { continue }
        $pp = $p.Trim().ToLower()
        $pprimary = ($pp -split '[-_]')[0]
        if ($l -eq $pp -or $primary -eq $pp -or $primary -eq $pprimary) { return $true }
    }
    return $false
}


function Set-CvWindowSize {
    <#
        Ajusta el tamano de la ventana de consola (columnas x lineas) desde config.json.
        Mantiene un buffer alto para conservar scroll hacia atras. 0 = no cambiar.
    #>
    param([int]$Cols, [int]$Lines)
    if ($Cols -le 0 -or $Lines -le 0) { return }
    try {
        $rui = $Host.UI.RawUI
        $maxW = $rui.MaxPhysicalWindowSize.Width
        $maxH = $rui.MaxPhysicalWindowSize.Height
        $wCols = [Math]::Min($Cols, $maxW)
        $wLines = [Math]::Min($Lines, $maxH)

        # 1) Encoger la ventana para poder redimensionar el buffer sin conflicto.
        $cur = $rui.WindowSize
        $rui.WindowSize = New-Object System.Management.Automation.Host.Size ([Math]::Min($cur.Width, $wCols)), ([Math]::Min($cur.Height, $wLines))
        # 2) Buffer: ancho = ventana; alto grande para scrollback.
        $rui.BufferSize = New-Object System.Management.Automation.Host.Size $wCols, ([Math]::Max($wLines, 3000))
        # 3) Ventana al tamano deseado.
        $rui.WindowSize = New-Object System.Management.Automation.Host.Size $wCols, $wLines
    } catch {}
}

function Set-CvAppearance {
    <#
        Aplica fuente, tamano de ventana, colores y titulo de la consola (config.json).
        Equivale al 'color 1e' + 'title' + 'mode con' del script batch antiguo.
    #>
    param([Parameter(Mandatory)]$Context, [string]$Title = 'ConversorVideoCMD')
    try { $Host.UI.RawUI.WindowTitle = $Title } catch {}

    # Fuente de la consola (Consolas por defecto; nombre vacio = no cambiar).
    Set-CvConsoleFont -Name $Context.ConsoleFont -Size $Context.ConsoleFontSize

    # Tamano de la ventana.
    Set-CvWindowSize -Cols $Context.WindowWidth -Lines $Context.WindowHeight

    $colors = [enum]::GetNames([System.ConsoleColor])
    if ($Context.ConsoleBackground -in $colors -and $Context.ConsoleForeground -in $colors) {
        try {
            [Console]::BackgroundColor = [System.ConsoleColor]$Context.ConsoleBackground
            [Console]::ForegroundColor = [System.ConsoleColor]$Context.ConsoleForeground
            Clear-Host   # repinta toda la ventana con el nuevo fondo
        } catch {}
    } elseif ($Context.ConsoleBackground -or $Context.ConsoleForeground) {
        Write-Host ("AVISO: color de consola no valido. Validos: {0}" -f ($colors -join ', ')) -ForegroundColor Yellow
    }
}

function Initialize-CvNative {
    <# Compila una sola vez las llamadas nativas (boton X + fuente de consola). #>
    if ('CvNative.Win' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace CvNative {
    [StructLayout(LayoutKind.Sequential)]
    public struct COORD { public short X; public short Y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFOEX {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string FaceName;
    }
    public static class Win {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]   public static extern IntPtr GetSystemMenu(IntPtr hWnd, bool bRevert);
        [DllImport("user32.dll")]   public static extern bool EnableMenuItem(IntPtr hMenu, uint uIDEnableItem, uint uEnable);
        [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX lpConsoleCurrentFontEx);
    }
}
'@ -ErrorAction Stop
}

function Set-CvCloseButton {
    <#
        Activa/desactiva el boton X (cerrar) de la ventana de consola, para evitar
        cerrarla por error a mitad de una conversion. Equivale al antiguo controls.exe.
        IMPORTANTE: reactivarlo siempre al terminar (se hace en un finally/trap).
    #>
    param([Parameter(Mandatory)][bool]$Enabled)
    try { Initialize-CvNative } catch { return }
    try {
        $hwnd = [CvNative.Win]::GetConsoleWindow()
        if ($hwnd -eq [System.IntPtr]::Zero) { return }
        $menu = [CvNative.Win]::GetSystemMenu($hwnd, $false)
        $SC_CLOSE   = [uint32]0xF060
        $MF_ENABLED = [uint32]0x0
        $MF_GRAYED  = [uint32]0x1
        $flag = if ($Enabled) { $MF_ENABLED } else { $MF_GRAYED }
        [void][CvNative.Win]::EnableMenuItem($menu, $SC_CLOSE, $flag)
    } catch {}
}

function Set-CvConsoleFont {
    <# Fija la fuente y el tamano de la consola (ej Consolas, 18). Nombre vacio = no cambia. #>
    param([string]$Name, [int]$Size = 18)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Size -le 0) { return }
    try { Initialize-CvNative } catch { return }
    try {
        $STD_OUTPUT = -11
        $h = [CvNative.Win]::GetStdHandle($STD_OUTPUT)
        if ($h -eq [System.IntPtr]::Zero -or $h -eq ([System.IntPtr](-1))) { return }
        $info = New-Object CvNative.CONSOLE_FONT_INFOEX
        $info.cbSize     = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][CvNative.CONSOLE_FONT_INFOEX])
        $info.FontFamily = 0
        $info.FontWeight = 400
        $info.FaceName   = $Name
        $coord = New-Object CvNative.COORD
        $coord.X = [int16]0
        $coord.Y = [int16]$Size
        $info.dwFontSize = $coord
        [void][CvNative.Win]::SetCurrentConsoleFontEx($h, $false, [ref]$info)
    } catch {}
}

function Write-CvLog {
    param([string]$Tag = 'GLOBAL', [string]$Message = '')
    Write-Host ("[{0}] {1}" -f $Tag, $Message)
}

function Write-CvDebug {
    param([Parameter(Mandatory)]$Context, [string]$Message)
    if ($Context.Debug) { Write-Host ("[DEBUG] {0}" -f $Message) -ForegroundColor DarkGray }
}

function ConvertTo-ArgString {
    <#
        Cita un array de argumentos segun las reglas de CreateProcess de Windows.
        Compatible con PS5.1 (no usa ProcessStartInfo.ArgumentList, que solo existe en PS7).
    #>
    param([string[]]$Arguments = @())
    $parts = foreach ($a in $Arguments) {
        if ($null -eq $a) { $a = '' }
        if ($a.Length -gt 0 -and $a -notmatch '[ \t"]') {
            $a
        } else {
            # escapar backslashes previos a comilla y las comillas
            $s = $a -replace '(\\*)"', '$1$1\"'
            $s = $s -replace '(\\+)$', '$1$1'
            '"' + $s + '"'
        }
    }
    return ($parts -join ' ')
}

function Invoke-ToolCapture {
    <#
        Ejecuta un exe capturando stdout/stderr. Para salidas pequenas (ffprobe, cropdetect,
        volumedetect, aacgain). Si se pasa -Context y esta en modo debug, muestra el comando
        y espera confirmacion antes de ejecutar.
    #>
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        $Context = $null
    )
    if ($null -ne $Context) {
        Write-CvDebug -Context $Context -Message ("RUN (analisis) => `"{0}`" {1}" -f $Exe, (ConvertTo-ArgString $Arguments))
        if ($Context.Debug) { Read-Host '  ...ENTER para ejecutar...' | Out-Null }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $Exe
    $psi.Arguments              = ConvertTo-ArgString $Arguments
    $psi.UseShellExecute        = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow         = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    # Leer stderr de forma asincrona para evitar bloqueos si el buffer se llena.
    $errTask = $p.StandardError.ReadToEndAsync()
    $out     = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    $err = $errTask.Result

    return [pscustomobject]@{ ExitCode = $p.ExitCode; StdOut = $out; StdErr = $err }
}

function Invoke-ToolShow {
    <#
        Ejecuta un exe y espera a que termine. Devuelve el codigo de salida.
        Las CODIFICACIONES se lanzan en una ventana aparte minimizada para no ensuciar
        la consola principal. Con -Preview (previsualizacion de bordes con FFplay) se
        ejecuta en la consola principal, como antes. En modo debug o con el marcador
        'same_window' todo va a la consola principal.
    #>
    param(
        [Parameter(Mandatory)][string]$Exe,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)]$Context,
        [switch]$Preview
    )
    Write-CvDebug -Context $Context -Message ("RUN => `"{0}`" {1}" -f $Exe, (ConvertTo-ArgString $Arguments))
    if ($Context.Debug) { Read-Host '  ...ENTER para ejecutar...' | Out-Null }

    # La previsualizacion se queda en la consola principal; solo las codificaciones
    # se mueven a una ventana aparte minimizada.
    $separate = ($Context.SeparateWindow -and -not $Context.Debug -and -not $Preview)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $Exe
    $psi.Arguments = ConvertTo-ArgString $Arguments
    if ($separate) {
        $psi.UseShellExecute = $true
        $psi.WindowStyle     = [System.Diagnostics.ProcessWindowStyle]::Minimized
    } else {
        # Hereda la consola actual (previsualizacion, debug o marcador same_window).
        $psi.UseShellExecute = $false
    }
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    return $p.ExitCode
}

# ---------- JOBS (config por archivo, en JSON) ----------

function Get-CvJobPath { param($Context,[string]$Name) Join-Path $Context.Proceso ("{0}.job.json" -f $Name) }
function Test-CvJob    { param($Context,[string]$Name) Test-Path -LiteralPath (Get-CvJobPath $Context $Name) }

function Write-CvJob {
    <#
        Escritura atomica del job: .tmp (UTF-8 sin BOM) y renombrado. Se usan operaciones
        .NET con rutas LITERALES porque los nombres pueden llevar corchetes, que PowerShell
        interpretaria como comodines en -Path.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)]$Job)
    $final = Get-CvJobPath $Context $Name
    $tmp   = "$final.tmp"
    $json  = $Job | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    if ([System.IO.File]::Exists($final)) { [System.IO.File]::Delete($final) }
    [System.IO.File]::Move($tmp, $final)
}

function Read-CvJob {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    Get-Content -Raw -LiteralPath (Get-CvJobPath $Context $Name) | ConvertFrom-Json
}

function Remove-CvJob {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    $f = Get-CvJobPath $Context $Name
    if (Test-Path -LiteralPath $f) { Remove-Item -Force -LiteralPath $f -ErrorAction SilentlyContinue }
}

function Get-CvTempPaths {
    <#
        UNICA FUENTE de los nombres de los ficheros temporales de un archivo en Proceso.
        La usan los que los crean (Video/Audio/Multiplex) y el que los limpia (Remove-CvTemps).
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    [pscustomobject]@{
        Video   = Join-Path $Context.Proceso ("{0}.mkv" -f $Name)           # video recodificado temporal
        Audio   = Join-Path $Context.Proceso ("{0}.m4a" -f $Name)           # audio recodificado temporal
        SyncWav = Join-Path $Context.Proceso ("{0}_concat.wav" -f $Name)    # wav de sincronizacion (silencio + audio)
        JobTmp  = Join-Path $Context.Proceso ("{0}.job.json.tmp" -f $Name)  # job a medio escribir (si quedo colgado)
    }
}

function Remove-CvTemps {
    <#
        Borra los ficheros temporales de un archivo en Proceso.
        Usa rutas EXACTAS (no comodines) para no tocar temporales de otro archivo
        cuyo nombre empiece igual (ej "Peli" vs "Peli 2").
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    $tmp = Get-CvTempPaths -Context $Context -Name $Name
    foreach ($p in @($tmp.Video, $tmp.Audio, $tmp.SyncWav, $tmp.JobTmp)) {
        if (Test-Path -LiteralPath $p) { Remove-Item -Force -LiteralPath $p -ErrorAction SilentlyContinue }
    }
}

# ---------- BLOQUEO ATOMICO ENTRE WORKERS ----------

function Enter-Lock {
    <#
        Reclama el archivo creando un fichero-lock con modo CreateNew (atomico: falla si ya
        existe). Se usa .NET (ruta literal) porque los nombres pueden llevar corchetes.
        Devuelve $true si lo consigue.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    $lock = Join-Path $Context.Proceso ("{0}.lock" -f $Name)
    try {
        $fs = [System.IO.File]::Open($lock, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $fs.Close()
        return $true
    } catch {
        return $false
    }
}

function Exit-Lock {
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    $lock = Join-Path $Context.Proceso ("{0}.lock" -f $Name)
    try { [System.IO.File]::Delete($lock) } catch {}
}

# ---------- UTIL ----------

function ConvertTo-InvDouble {
    <# Parseo de decimales independiente del locale (ffmpeg usa siempre punto). #>
    param([string]$Text)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $out = 0.0
    if ([double]::TryParse($Text, [System.Globalization.NumberStyles]::Float, $inv, [ref]$out)) { return $out }
    return $null
}

function Get-OutputPath {
    param($Context, [string]$Name)
    Join-Path $Context.Convertido ("{0}_fix.{1}" -f $Name, $Context.OutExt)
}

function Read-IntOrDefault {
    <# Lee un entero por teclado; si se deja vacio o no es valido, devuelve el valor por defecto. #>
    param([string]$Prompt, [int]$Default)
    $v = (Read-Host ("{0} [{1}]" -f $Prompt, $Default)).Trim()
    if ($v -eq '') { return $Default }
    $n = 0
    if ([int]::TryParse($v, [ref]$n)) { return $n }
    return $Default
}

function Read-QOrNull {
    <# Lee un cuantizador (0-51). Vacio o negativo => $null (desactivado). #>
    param([string]$Prompt, [object]$Default)
    $dtxt = if ($null -eq $Default) { '-' } else { "$Default" }
    $v = (Read-Host ("{0} [{1}] (-1 = desactivar)" -f $Prompt, $dtxt)).Trim()
    if ($v -eq '') { return $Default }
    $n = 0
    if ([int]::TryParse($v, [ref]$n)) { if ($n -lt 0) { return $null } return $n }
    return $Default
}

function Read-YesNo {
    <# Pregunta si/no. Devuelve $true/$false. #>
    param([string]$Prompt, [bool]$Default = $true)
    $d = if ($Default) { 'S' } else { 'N' }
    $a = (Read-Host ("{0} (s/n) [{1}]" -f $Prompt, $d)).Trim()
    if ($a -eq '') { return $Default }
    return ($a -match '^[SsYy]')
}

function Show-Menu {
    <#
        Dibuja un cuadro de doble linea (estilo clasico) alrededor del contenido.
        $Title = titulo; $Lines = lineas (una cadena vacia deja una linea en blanco dentro).
        Usa codigos [char] para los bordes, asi no depende de la codificacion del fichero.
    #>
    param([string]$Title, [string[]]$Lines = @())
    $inner = 62
    $H  = [char]0x2550   # horizontal
    $V  = [char]0x2551   # vertical
    $TL = [char]0x2554; $TR = [char]0x2557   # esquinas superiores
    $BL = [char]0x255A; $BR = [char]0x255D   # esquinas inferiores
    $hbar = [string]$H * $inner

    $rows = New-Object System.Collections.Generic.List[string]
    $rows.Add(("{0}{1}{2}" -f $TL, $hbar, $TR))
    $add = {
        param($txt)
        if ($txt.Length -gt $inner) { $txt = $txt.Substring(0, $inner) }
        $rows.Add(("{0}{1}{0}" -f $V, $txt.PadRight($inner)))
    }
    & $add ''
    if ($Title) { & $add ("   {0}" -f $Title); & $add '' }
    foreach ($l in $Lines) {
        if ($l -eq '') { & $add '' } else { & $add ("       {0}" -f $l) }
    }
    & $add ''
    $rows.Add(("{0}{1}{2}" -f $BL, $hbar, $BR))

    Write-Host ''
    foreach ($r in $rows) { Write-Host $r }
}

function Select-FromList {
    <#
        Muestra una lista numerada de opciones (enmarcada) y devuelve el valor elegido.
        La opcion 0 devuelve el valor $NoneValue (por defecto cadena vacia).
        ENTER selecciona la opcion por defecto ($DefaultIndex, 1-based; 0 = ninguno).
    #>
    param(
        [string]$Title,
        [Parameter(Mandatory)][string[]]$Options,
        [string]$NoneLabel = 'ninguno',
        [string]$NoneValue = '',
        [int]$DefaultIndex = 0
    )
    $lines = @()
    for ($i = 0; $i -lt $Options.Count; $i++) { $lines += ("{0}. {1}" -f ($i + 1), $Options[$i]) }
    $lines += ("0. {0}" -f $NoneLabel)
    Show-Menu -Title $Title -Lines $lines
    while ($true) {
        $k = (Read-Host ("   Opcion [{0}]" -f $DefaultIndex)).Trim()
        if ($k -eq '') { $k = "$DefaultIndex" }
        $n = 0
        if ([int]::TryParse($k, [ref]$n)) {
            if ($n -eq 0) { return $NoneValue }
            if ($n -ge 1 -and $n -le $Options.Count) { return $Options[$n - 1] }
        }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function *
