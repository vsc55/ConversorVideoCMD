<#
    Job.psm1 - Cola de trabajo: jobs JSON (*-CvJob), lock atomico (Enter/Exit-Lock),
    ficheros temporales (Get-CvTempPaths/Remove-CvTemps) y ruta de salida (Get-OutputPath).
#>

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


function Test-CvLockStale {
    <#
        Un lock esta caducado si su worker dueño ya no existe. En el lock se guarda
        "PID=<pid>;HOST=<equipo>". Solo se considera caducado si es de ESTE equipo y el
        proceso con ese PID ya no corre (en otra maquina no se puede verificar -> no se roba).
    #>
    param([string]$LockPath)
    if (-not (Test-Path -LiteralPath $LockPath)) { return $false }
    try { $txt = [System.IO.File]::ReadAllText($LockPath) } catch { return $false }
    $m = [regex]::Match("$txt", 'PID=(\d+);HOST=(.+)')
    if (-not $m.Success) { return $false }
    if ($m.Groups[2].Value.Trim() -ne $env:COMPUTERNAME) { return $false }
    $lockPid = [int]$m.Groups[1].Value
    return ($null -eq (Get-Process -Id $lockPid -ErrorAction SilentlyContinue))
}

function Enter-Lock {
    <#
        Reclama el archivo creando un fichero-lock con modo CreateNew (atomico: falla si ya
        existe). Guarda PID+equipo para poder detectar y robar locks caducados (worker
        muerto). Ruta literal (los nombres pueden llevar corchetes). Devuelve $true si lo consigue.
    #>
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Name)
    $lock = Join-Path $Context.Proceso ("{0}.lock" -f $Name)
    # Si hay un lock de un worker que ya no existe, robarlo.
    if (Test-CvLockStale $lock) {
        try { [System.IO.File]::Delete($lock) } catch {}
    }
    try {
        $fs = [System.IO.File]::Open($lock, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes(("PID={0};HOST={1}" -f $PID, $env:COMPUTERNAME))
            $fs.Write($bytes, 0, $bytes.Length)
        } finally { $fs.Close() }
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


function Get-OutputPath {
    param($Context, [string]$Name)
    Join-Path $Context.Convertido ("{0}_fix.{1}" -f $Name, $Context.OutExt)
}


Export-ModuleMember -Function *
