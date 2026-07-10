<#
    Exec.psm1 - Ejecucion de procesos externos (ffmpeg/ffprobe/ffplay/aacgain): captura de
    salida, ventana aparte y modo debug.
#>

# Helper nativo: lanza un proceso en una CONSOLA NUEVA MINIMIZADA SIN ROBAR EL FOCO
# (SW_SHOWMINNOACTIVE). El Start-Process con -WindowStyle Minimized usa SW_SHOWMINIMIZED,
# que activa la ventana y roba el foco aunque quede minimizada.
if (-not ('CvProc' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Text;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class CvProc {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow; public short cbReserved2; public IntPtr lpReserved2;
        public IntPtr hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcess(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit,
        uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetExitCodeProcess(IntPtr h, out uint code);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    const uint CREATE_NEW_CONSOLE = 0x00000010; const int STARTF_USESHOWWINDOW = 0x00000001;
    const short SW_SHOWMINNOACTIVE = 7; const uint INFINITE = 0xFFFFFFFF;
    public static int RunMinimizedNoActivate(string exe, string args, string cwd) {
        var si = new STARTUPINFO();
        si.cb = Marshal.SizeOf(si);
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_SHOWMINNOACTIVE;
        var cmd = new StringBuilder("\"" + exe + "\" " + args);
        PROCESS_INFORMATION pi;
        if (!CreateProcess(exe, cmd, IntPtr.Zero, IntPtr.Zero, false, CREATE_NEW_CONSOLE, IntPtr.Zero, cwd, ref si, out pi))
            throw new Win32Exception(Marshal.GetLastWin32Error());
        WaitForSingleObject(pi.hProcess, INFINITE);
        uint code; GetExitCodeProcess(pi.hProcess, out code);
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        return (int)code;
    }
}
'@
}

# Helper nativo: traer una ventana al PRIMER PLANO y darle el foco. Se usa para la ventana de
# previsualizacion (ffplay), que debe recibir el foco para poder cerrarla ('q'/ESC) y que las
# teclas vayan a ella y no a la consola (al contrario que las ventanas de codificacion, que van
# sin foco). Al reves que el no-foco de CvProc.
if (-not ('CvWin' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CvWin {
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int nCmdShow);
    [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
    const int SW_SHOW = 5; const int SW_RESTORE = 9;
    public static void ToForeground(IntPtr h) {
        if (h == IntPtr.Zero) return;
        ShowWindow(h, SW_RESTORE); ShowWindow(h, SW_SHOW);
        BringWindowToTop(h); SetForegroundWindow(h);
    }
}
'@
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

    if ($separate) {
        # Ventana aparte MINIMIZADA sin robar el foco (SW_SHOWMINNOACTIVE via CreateProcess).
        $cwd = "$($Context.Root)"; if ([string]::IsNullOrWhiteSpace($cwd)) { $cwd = (Get-Location).Path }
        try {
            return [CvProc]::RunMinimizedNoActivate($Exe, (ConvertTo-ArgString $Arguments), $cwd)
        } catch {
            # Fallback: minimizada clasica (puede robar foco) si la API nativa fallara.
            Write-CvDebug -Context $Context -Message ("ventana sin foco no disponible ({0}); minimizada normal" -f $_.Exception.Message)
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName        = $Exe
            $psi.Arguments       = ConvertTo-ArgString $Arguments
            $psi.UseShellExecute = $true
            $psi.WindowStyle     = [System.Diagnostics.ProcessWindowStyle]::Minimized
            $p = [System.Diagnostics.Process]::Start($psi)
            $p.WaitForExit()
            return $p.ExitCode
        }
    }

    # Consola actual (previsualizacion, debug o marcador same_window).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName        = $Exe
    $psi.Arguments       = ConvertTo-ArgString $Arguments
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    if ($Preview) {
        # La ventana de preview (ffplay) DEBE tener el foco: si no, las teclas ('q'/ESC para
        # cerrarla) irian a la consola. Windows no siempre le da el primer plano al abrirla, asi
        # que se espera a que cree su ventana (hasta ~2 s) y se trae al frente. Best-effort.
        try {
            for ($i = 0; $i -lt 40 -and $p.MainWindowHandle -eq [IntPtr]::Zero -and -not $p.HasExited; $i++) {
                Start-Sleep -Milliseconds 50; $p.Refresh()
            }
            if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [CvWin]::ToForeground($p.MainWindowHandle) }
        } catch {
            Write-CvDebug -Context $Context -Message ("no se pudo dar foco a la preview: {0}" -f $_.Exception.Message)
        }
    }
    $p.WaitForExit()
    return $p.ExitCode
}

function Invoke-CvPreview {
    <#
        Nucleo comun de las previews con ffplay (bordes, pista de video/audio, subtitulo):
        tramo -ss/-t/-autoexit con inicio/duracion de config (preview.start/seconds), ajustado
        a la duracion real del video (Get-CvSafeStart), + los args de seleccion/filtro que
        aporta cada llamador (-vst/-ast/-sst/-vf/-nodisp).
    #>
    param(
        [Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$File,
        [string[]]$ExtraArgs = @(), [string]$Label = 'PREVIEW',
        [int]$Start = -1, [int]$Seconds = -1, [double]$Duration = 0
    )
    $s = if ($Start -ge 0) { $Start } else { [int]$Context.PreviewStart }
    $s = Get-CvSafeStart -Start $s -Duration $Duration -Window 1
    if ($Seconds -lt 0) { $Seconds = [int]$Context.PreviewSeconds }
    $a = @('-hide_banner','-loglevel','error','-ss',"$s",'-t',"$Seconds",'-autoexit') + $ExtraArgs + @('-window_title',$Label,$File)
    Invoke-ToolShow -Exe $Context.FFplay -Arguments $a -Context $Context -Preview | Out-Null
}


Export-ModuleMember -Function *
