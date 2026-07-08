<#
    Exec.psm1 - Ejecucion de procesos externos (ffmpeg/ffprobe/ffplay/aacgain): captura de
    salida, ventana aparte y modo debug.
#>

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


Export-ModuleMember -Function *
