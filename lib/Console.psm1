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


function ConvertFrom-CvPlayCommand {
    <#
        Parsea el comando de reproduccion de los menus de seleccion de pista:
        'P N [seg]' (video + pista) y, con -AllowAudioOnly, tambien 'A N [seg]' (solo audio).
        Devuelve @{ AudioOnly; Index; Start } (Start = -1 si no se indico) o $null si el texto
        no es un comando de reproduccion.
    #>
    param([string]$Text, [switch]$AllowAudioOnly)
    $pat = if ($AllowAudioOnly) { '^([PpAa])\s*(\d+)(?:\s+(\d+))?$' } else { '^([Pp])\s*(\d+)(?:\s+(\d+))?$' }
    $m = [regex]::Match("$Text", $pat)
    if (-not $m.Success) { return $null }
    [pscustomobject]@{
        AudioOnly = ($m.Groups[1].Value -match '^[Aa]$')
        Index     = [int]$m.Groups[2].Value
        Start     = $(if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { -1 })
    }
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
    <#
        Lee un cuantizador/CRF. Vacio => valor por defecto; negativo => $null (desactivado/auto).
        -Max (>0): valor maximo aceptado; por encima se re-pregunta (p. ej. 51 para el QP de
        H.264/HEVC y el CRF de x264/x265). Con -AllowCancel, 'C'/ESC lanza CV_CANCEL.
    #>
    param([string]$Prompt, [object]$Default, [int]$Max = 0, [switch]$AllowCancel)
    $dtxt = if ($null -eq $Default) { '-' } else { "$Default" }
    $hint = if ($AllowCancel) { '-1 = desactivar, C/ESC = cancelar' } else { '-1 = desactivar' }
    $pr   = "{0} [{1}] ({2})" -f $Prompt, $dtxt, $hint
    while ($true) {
        $v = (& { if ($AllowCancel) { Read-CvLine -Prompt $pr -AllowCancel } else { Read-Host $pr } }).Trim()
        if ($AllowCancel -and $v -match '^[Cc]$') { throw 'CV_CANCEL' }
        if ($v -eq '') { return $Default }
        $n = 0
        if ([int]::TryParse($v, [ref]$n)) {
            if ($n -lt 0) { return $null }                                    # negativo = desactivar/auto
            if ($Max -gt 0 -and $n -gt $Max) { Write-Host ("   Fuera de rango (0-{0})." -f $Max) -ForegroundColor Yellow; continue }
            return $n
        }
        Write-Host '   Valor no valido (numero entero).' -ForegroundColor Yellow
    }
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


function Select-FromList {
    <#
        Muestra una lista numerada de opciones (enmarcada) y devuelve el valor elegido.
        Cada opcion puede ser una CADENA o un objeto @{ Value; Text } (Value = lo que se devuelve;
        Text = descripcion que se muestra tras el nombre). Asi los catalogos Get-Cv* (que usan ese
        formato) se pasan tal cual. La opcion 0 devuelve $NoneValue. ENTER = opcion por defecto
        ($DefaultIndex, 1-based; 0 = ninguno). $Headers: { <indice0> = 'Titulo' } inserta un titulo.
    #>
    param(
        [string]$Title,
        [Parameter(Mandatory)][object[]]$Options,   # cadenas o @{ Value; Text; Position }
        [string]$NoneLabel = 'ninguno',
        [string]$NoneValue = '',
        [int]$DefaultIndex = 0,
        [string]$DefaultValue = '',       # si se da, ENTER devuelve este valor (aunque no este en la lista)
        [string]$NoneKey = '',            # letra alternativa para la opcion 0 (p.ej. 'S' = salir)
        [string[]]$Descriptions = @(),    # descripcion por opcion (si la opcion no es objeto con Text)
        [string]$NoneDescription = '',    # descripcion opcional de la opcion 0
        [string]$CancelLabel = '',        # texto de la linea de cancelar (si -AllowCancel)
        [hashtable]$Headers = $null,
        [switch]$NoNone,                  # oculta la opcion 0 (salvo que haya una opcion Position='first')
        [switch]$AllowCancel
    )
    # Normalizar cada opcion a registro { Val; Txt; Pos }. Acepta cadenas o @{ Value; Text; Position }
    # (o PSObject con esas propiedades). Position: 'first' -> opcion 0 (None); 'end' -> al final.
    $recs = @()
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $o = $Options[$i]
        if ($o -is [System.Collections.IDictionary]) {
            $recs += @{ Val = "$($o['Value'])"; Txt = "$($o['Text'])"; Pos = "$($o['Position'])" }
        } elseif ($o -is [psobject] -and $o.PSObject.Properties['Value']) {
            $recs += @{ Val = "$($o.Value)"; Txt = "$($o.Text)"; Pos = "$(if ($o.PSObject.Properties['Position']) { $o.Position })" }
        } else {
            $recs += @{ Val = "$o"; Txt = $(if ($i -lt $Descriptions.Count) { $Descriptions[$i] } else { '' }); Pos = '' }
        }
    }
    # Reparto por posicion: numeradas = mids (sin Position) + ends; la opcion 0 = 'first' si existe.
    $numbered = @($recs | Where-Object { $_.Pos -ne 'first' -and $_.Pos -ne 'end' }) + @($recs | Where-Object { $_.Pos -eq 'end' })
    $first    = @($recs | Where-Object { $_.Pos -eq 'first' })[0]
    $hasNone  = $true; $noneVal = $NoneValue; $noneLbl = $NoneLabel; $noneDsc = $NoneDescription
    if ($first) { $noneVal = $first.Val; $noneLbl = $first.Val; $noneDsc = $first.Txt }
    elseif ($NoNone) { $hasNone = $false }

    # Default: por valor (prioridad, puede ser libre) o por indice.
    $defIdx = $DefaultIndex; $defRet = $null
    if ($DefaultValue) {
        $defRet = $DefaultValue
        $mi = [array]::IndexOf(@($numbered | ForEach-Object { $_.Val }), "$DefaultValue")
        if ($mi -ge 0) { $defIdx = $mi + 1 } elseif ($hasNone -and $noneVal -eq $DefaultValue) { $defIdx = 0 } else { $defIdx = -1 }
    }
    $defShown = if ($null -ne $defRet) { $defRet } else { "$defIdx" }

    $mark    = '  <= por defecto'
    $noneNum = if ($NoneKey) { '0 / {0}' -f $NoneKey.ToUpper() } else { '0' }
    $leftNum = @(); $descNum = @()
    for ($i = 0; $i -lt $numbered.Count; $i++) { $leftNum += ('{0}. {1}' -f ($i + 1), $numbered[$i].Val); $descNum += $numbered[$i].Txt }
    $leftNone = if ($hasNone) { '{0}. {1}' -f $noneNum, $noneLbl } else { '' }
    $anyDesc  = (@($descNum | Where-Object { $_ }).Count -gt 0) -or [bool]$noneDsc
    $allLeft  = @($leftNum); if ($hasNone) { $allLeft += $leftNone }
    $w        = if ($anyDesc -and $allLeft.Count) { ($allLeft | Measure-Object -Property Length -Maximum).Maximum } else { 0 }

    # Cuerpo de cada fila (izquierda alineada a $w + su descripcion), SIN la marca de defecto.
    $bodyNum = @()
    for ($i = 0; $i -lt $numbered.Count; $i++) {
        $bodyNum += $(if ($descNum[$i]) { $leftNum[$i].PadRight($w) + '  - ' + $descNum[$i] } else { $leftNum[$i] })
    }
    $bodyNone = ''
    if ($hasNone) { $bodyNone = $(if ($noneDsc) { $leftNone.PadRight($w) + '  - ' + $noneDsc } else { $leftNone }) }
    # Ancho comun para alinear "<= por defecto" en columna, tras el cuerpo (texto) mas largo.
    $allBody = @($bodyNum); if ($hasNone) { $allBody += $bodyNone }
    $bodyW   = if ($allBody.Count) { ($allBody | Measure-Object -Property Length -Maximum).Maximum } else { 0 }

    $lines = @()
    for ($i = 0; $i -lt $numbered.Count; $i++) {
        if ($Headers -and $Headers.Contains($i)) {
            if ($i -gt 0) { $lines += '' }                 # separacion antes del bloque
            $lines += ("-- {0} --" -f $Headers[$i])
        }
        $lines += $(if (($i + 1) -eq $defIdx) { $bodyNum[$i].PadRight($bodyW) + $mark } else { $bodyNum[$i] })
    }
    if ($hasNone) {
        $lines += ''
        $lines += $(if ($defIdx -eq 0) { $bodyNone.PadRight($bodyW) + $mark } else { $bodyNone })
    }
    if ($AllowCancel) {
        $lines += ''                                       # separacion antes de la linea de cancelar
        $lines += $(if ($CancelLabel) { $CancelLabel } else { 'C / ESC. Cancelar' })
    }
    Show-Menu -Title $Title -Lines $lines
    while ($true) {
        $pr = "   Opcion [{0}]" -f $defShown
        $k = (& { if ($AllowCancel) { Read-CvLine -Prompt $pr -AllowCancel } else { Read-Host $pr } }).Trim()
        if ($AllowCancel -and $k -match '^[Cc]$') { throw 'CV_CANCEL' }
        if ($hasNone -and $NoneKey -and $k -ieq $NoneKey) { return $noneVal }   # letra alternativa de la opcion 0
        if ($k -eq '') {
            if ($null -ne $defRet) { return $defRet }      # default por valor (incluido valor libre)
            $k = "$defIdx"
        }
        $n = 0
        if ([int]::TryParse($k, [ref]$n)) {
            if ($n -eq 0 -and $hasNone) { return $noneVal }
            if ($n -ge 1 -and $n -le $numbered.Count) { return $numbered[$n - 1].Val }
        }
        Write-Host '   Opcion no valida.' -ForegroundColor Yellow
    }
}


Export-ModuleMember -Function *
