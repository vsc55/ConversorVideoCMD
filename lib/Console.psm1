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
        $Headers (opcional): hashtable { <indice0> = 'Titulo del bloque' } que inserta un
        titulo de seccion antes de esa opcion, sin afectar a la numeracion.
    #>
    param(
        [string]$Title,
        [Parameter(Mandatory)][string[]]$Options,
        [string]$NoneLabel = 'ninguno',
        [string]$NoneValue = '',
        [int]$DefaultIndex = 0,
        [hashtable]$Headers = $null
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
