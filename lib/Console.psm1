<#
    Console.psm1 - Consola: apariencia, control nativo de la ventana (P/Invoke), menus
    (Show-Menu / Select-FromList) y prompts (Read-*).
#>

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


function Read-CvLine {
    <#
        Lee una linea del teclado con soporte de la tecla ESC. Devuelve el texto; con
        -AllowCancel, pulsar ESC lanza CV_CANCEL. Maneja Enter y Retroceso. Si la entrada
        esta redirigida (sin consola interactiva), cae a Read-Host (sin ESC).
    #>
    param([string]$Prompt = '', [switch]$AllowCancel)
    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }
    if (-not $interactive) { return (Read-Host $Prompt) }

    Write-Host ("{0}: " -f $Prompt) -NoNewline
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
        $key = [Console]::ReadKey($true)   # $true = no eco automatico
        if ($key.Key -eq 'Enter')     { Write-Host ''; return $sb.ToString() }
        if ($key.Key -eq 'Escape')    { if ($AllowCancel) { Write-Host ''; throw 'CV_CANCEL' } ; continue }
        if ($key.Key -eq 'Backspace') { if ($sb.Length -gt 0) { [void]$sb.Remove($sb.Length - 1, 1); Write-Host "`b `b" -NoNewline } ; continue }
        $ch = $key.KeyChar
        if ($ch -and -not [char]::IsControl($ch)) { [void]$sb.Append($ch); Write-Host $ch -NoNewline }
    }
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
    <# Lee un cuantizador (0-51). Vacio o negativo => $null (desactivado). Con -AllowCancel, 'C' lanza CV_CANCEL. #>
    param([string]$Prompt, [object]$Default, [switch]$AllowCancel)
    $dtxt = if ($null -eq $Default) { '-' } else { "$Default" }
    $hint = if ($AllowCancel) { '-1 = desactivar, C/ESC = cancelar' } else { '-1 = desactivar' }
    $pr   = "{0} [{1}] ({2})" -f $Prompt, $dtxt, $hint
    $v = (& { if ($AllowCancel) { Read-CvLine -Prompt $pr -AllowCancel } else { Read-Host $pr } }).Trim()
    if ($AllowCancel -and $v -match '^[Cc]$') { throw 'CV_CANCEL' }
    if ($v -eq '') { return $Default }
    $n = 0
    if ([int]::TryParse($v, [ref]$n)) { if ($n -lt 0) { return $null } return $n }
    return $Default
}


function Read-YesNo {
    <# Pregunta si/no. Devuelve $true/$false. Con -AllowCancel, 'C' lanza CV_CANCEL. #>
    param([string]$Prompt, [bool]$Default = $true, [switch]$AllowCancel)
    $d = if ($Default) { 'S' } else { 'N' }
    $opts = if ($AllowCancel) { 's/n/c' } else { 's/n' }
    $pr = "{0} ({1}) [{2}]" -f $Prompt, $opts, $d
    $a = (& { if ($AllowCancel) { Read-CvLine -Prompt $pr -AllowCancel } else { Read-Host $pr } }).Trim()
    if ($AllowCancel -and $a -match '^[Cc]$') { throw 'CV_CANCEL' }
    if ($a -eq '') { return $Default }
    return ($a -match '^[SsYy]')
}


function Show-CvHeader {
    <# Cabecera al arrancar: nombre de la app + version (y subtitulo opcional). #>
    param([Parameter(Mandatory)]$Context, [string]$Subtitle = '')
    $name = 'ConversorVideoCMD {0}' -f $Context.Version
    if ($Subtitle) { $name = "$name - $Subtitle" }
    $sep = '=' * 64
    Write-Host ''
    Write-Host $sep  -ForegroundColor Cyan
    Write-Host ("  {0}" -f $name) -ForegroundColor Cyan
    Write-Host $sep  -ForegroundColor Cyan
    Write-Host ''
}

function Show-Menu {
    <#
        Muestra un bloque de menu enmarcado con lineas de guiones (antes y despues),
        sin recuadro. $Title = titulo; $Lines = opciones (cadena vacia = linea en blanco).
        No trunca: las lineas largas se imprimen enteras.
    #>
    param([string]$Title, [string[]]$Lines = @(), [int]$Indent = 0)
    $pad = ' ' * $Indent
    $sep = $pad + ('-' * 64)
    Write-Host ''
    Write-Host $sep
    if ($Title) {
        Write-Host ($pad + ("  {0}" -f $Title))
        Write-Host $sep
    }
    foreach ($l in $Lines) {
        if ($l -eq '') { Write-Host '' } else { Write-Host ($pad + ("    {0}" -f $l)) }
    }
    Write-Host $sep
}

function Show-CvBox {
    <#
        Dibuja un CUADRO de doble linea alrededor del contenido. Pensado para mensajes
        destacados (avisos, errores, resumenes...). -Color aplica color a todo el cuadro.
        Usa codigos [char] para los bordes (no depende de la codificacion del fichero).
    #>
    param([string]$Title, [string[]]$Lines = @(), [System.ConsoleColor]$Color)
    $inner = 62
    $H  = [char]0x2550
    $V  = [char]0x2551
    $TL = [char]0x2554; $TR = [char]0x2557
    $BL = [char]0x255A; $BR = [char]0x255D
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
        if ($l -eq '') { & $add '' } else { & $add ("   {0}" -f $l) }
    }
    & $add ''
    $rows.Add(("{0}{1}{2}" -f $BL, $hbar, $BR))

    $col = @{}
    if ($PSBoundParameters.ContainsKey('Color')) { $col.ForegroundColor = $Color }
    Write-Host ''
    foreach ($r in $rows) { Write-Host $r @col }
}


function Get-CvMenuLines {
    <#
        Genera las lineas de un menu a partir de un [ordered] de opciones (clave -> valor),
        para no duplicar los datos entre el mapa y el texto del menu. El valor puede ser:
          - una cadena            -> "clave. valor"
          - @{ Value=..; Text=.. } -> "clave. valor<pad> Text"  (Text descripcion, opcional)
        Se usa el MISMO mapa para el lookup (Get-CvOptionValue).
    #>
    param([Parameter(Mandatory)]$Options)
    $lines = @()
    foreach ($key in $Options.Keys) {
        $v = $Options[$key]
        if ($v -is [System.Collections.IDictionary]) {
            $txt = "$($v.Text)"
            if ($txt) { $lines += ("{0}. {1,-12}{2}" -f $key, "$($v.Value)", $txt) }
            else      { $lines += ("{0}. {1}"        -f $key, "$($v.Value)") }
        } else {
            $lines += ("{0}. {1}" -f $key, "$v")
        }
    }
    $lines
}

function Get-CvOptionValue {
    <# Valor de una opcion por su clave (Value si es hashtable, la cadena si no); '' si no existe. #>
    param([Parameter(Mandatory)]$Options, [string]$Key)
    if (-not $Options.Contains($Key)) { return '' }
    $v = $Options[$Key]
    if ($v -is [System.Collections.IDictionary]) { return "$($v.Value)" }
    return "$v"
}


function Select-FromList {
    <#
        Muestra una lista numerada de opciones (enmarcada) y devuelve el valor elegido.
        La opcion 0 devuelve el valor $NoneValue (por defecto cadena vacia).
        ENTER selecciona la opcion por defecto ($DefaultIndex, 1-based; 0 = ninguno).
        $Headers (opcional): hashtable { <indice0> = 'Titulo del bloque' } que inserta un
        titulo de seccion antes de esa opcion, sin afectar a la numeracion.
    #>
    param(
        [string]$Title,
        [Parameter(Mandatory)][string[]]$Options,
        [string]$NoneLabel = 'ninguno',
        [string]$NoneValue = '',
        [int]$DefaultIndex = 0,
        [hashtable]$Headers = $null,
        [switch]$AllowCancel
    )
    $lines = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        if ($Headers -and $Headers.Contains($i)) {
            if ($i -gt 0) { $lines += '' }                 # separacion antes del bloque
            $lines += ("-- {0} --" -f $Headers[$i])
        }
        $lines += ("{0}. {1}" -f ($i + 1), $Options[$i])
    }
    $lines += ''
    $lines += ("0. {0}" -f $NoneLabel)
    if ($AllowCancel) { $lines += 'C / ESC. Cancelar' }
    Show-Menu -Title $Title -Lines $lines
    while ($true) {
        $pr = "   Opcion [{0}]" -f $DefaultIndex
        $k = (& { if ($AllowCancel) { Read-CvLine -Prompt $pr -AllowCancel } else { Read-Host $pr } }).Trim()
        if ($AllowCancel -and $k -match '^[Cc]$') { throw 'CV_CANCEL' }
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
