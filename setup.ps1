<#
    setup.ps1 - Gestion de herramientas y configuracion.

    Menu principal:
      - Instalar / cambiar version de ffmpeg (u otra app del catalogo 'downloads').
      - Reinstalar TODO (version por defecto de cada app).
      - Editar configuracion: editor navegable de TODO config.json (idiomas, encode,
        bordes, volumen, comportamiento, consola, descargas...) sin tocarlo a mano.

    Reutiliza el catalogo 'downloads' de config.json y las funciones de descarga de
    lib\Common.psm1 (las mismas que usa Convert.ps1 cuando falta una herramienta).
    El guardado usa un serializador propio (indentacion de 4 espacios, CRLF) para no
    depender de ConvertTo-Json (que en PS 5.1 reordena/reformatea).

    Lanzar:  setup.cmd   (o)   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
Import-Module (Join-Path $Root 'lib\Common.psm1') -Force
Import-Module (Join-Path $Root 'lib\Tools.psm1')  -Force

$ctx = New-CvContext -Root $Root
Set-CvAppearance -Context $ctx -Title 'ConversorVideoCMD - Setup'

$CfgPath = Join-Path $Root 'config.json'

# Log de la sesion (transcript) a logs\. Desactivable con behavior.log=false o marcador no_log.
$cvTranscript = $false
if ($ctx.Log) {
    $logFile = Join-Path $ctx.Logs ("setup_{0}_{1}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $PID)
    try { Start-Transcript -LiteralPath $logFile -Append -ErrorAction Stop | Out-Null; $cvTranscript = $true } catch {}
}

# ===========================================================================
#  Acceso generico a nodos (soporta PSCustomObject de ConvertFrom-Json e IDictionary)
# ===========================================================================
function Get-NodeKind($v) {
    if ($null -eq $v)                                        { return 'null' }
    if ($v -is [bool])                                       { return 'bool' }
    if ($v -is [string])                                     { return 'string' }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [single] -or $v -is [decimal]) { return 'number' }
    if ($v -is [System.Collections.IDictionary])             { return 'object' }
    if ($v -is [System.Management.Automation.PSCustomObject]){ return 'object' }
    if ($v -is [System.Collections.IEnumerable])             { return 'array' }
    return 'string'
}
function Get-Keys($node) {
    if ($node -is [System.Collections.IDictionary]) { return @($node.Keys) }
    if ($node) { return @($node.PSObject.Properties.Name) }
    return @()
}
function Get-Val($node, $key) {
    # La coma unaria evita que PowerShell desenvuelva un array de 1 elemento al retornar
    # (si no, ["-version"] se convertiria en la cadena "-version" al serializar).
    if ($node -is [System.Collections.IDictionary]) { return , $node[$key] }
    return , $node.$key
}
function Set-Val($node, $key, $value) {
    if ($node -is [System.Collections.IDictionary]) { $node[$key] = $value }
    else { $node.$key = $value }
}

# ===========================================================================
#  Serializador JSON propio (4 espacios, arrays de escalares en linea)
# ===========================================================================
function ConvertTo-JsonString([string]$s) {
    $e = $s.Replace('\','\\').Replace('"','\"').Replace("`r",'\r').Replace("`n",'\n').Replace("`t",'\t')
    return '"' + $e + '"'
}
function Format-CvNumber($n) {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($n -is [double] -or $n -is [single] -or $n -is [decimal]) { return ([double]$n).ToString($inv) }
    return ([long]$n).ToString($inv)
}
function ConvertTo-CvJson {
    param($Node, [int]$Indent = 0)
    $pad  = '    ' * $Indent
    $pad1 = '    ' * ($Indent + 1)
    switch (Get-NodeKind $Node) {
        'object' {
            $keys = @(Get-Keys $Node)
            if ($keys.Count -eq 0) { return '{}' }
            $parts = @()
            foreach ($k in $keys) {
                $parts += ('{0}{1}: {2}' -f $pad1, (ConvertTo-JsonString "$k"), (ConvertTo-CvJson (Get-Val $Node $k) ($Indent + 1)))
            }
            return "{`n" + ($parts -join ",`n") + "`n$pad}"
        }
        'array' {
            $items = @($Node)
            if ($items.Count -eq 0) { return '[]' }
            $allScalar = $true
            foreach ($it in $items) { if ((Get-NodeKind $it) -in @('object','array')) { $allScalar = $false; break } }
            if ($allScalar) {
                $vals = foreach ($it in $items) { ConvertTo-CvJson $it 0 }
                return '[' + ($vals -join ', ') + ']'
            }
            $parts = foreach ($it in $items) { $pad1 + (ConvertTo-CvJson $it ($Indent + 1)) }
            return "[`n" + ($parts -join ",`n") + "`n$pad]"
        }
        'bool'   { if ($Node) { return 'true' } else { return 'false' } }
        'number' { return (Format-CvNumber $Node) }
        'null'   { return 'null' }
        default  { return (ConvertTo-JsonString "$Node") }
    }
}
function Repair-ConfigArrays($cfg) {
    <#
        PS 5.1 ConvertFrom-Json desenvuelve los arrays de 1 elemento a escalar
        (["es"] -> "es"). Forzamos a array los campos que del esquema deben serlo,
        para que se editen como lista y se serialicen como [...].
    #>
    if ($cfg.languages) {
        if ($null -ne $cfg.languages.audio)    { $cfg.languages.audio    = @($cfg.languages.audio) }
        if ($null -ne $cfg.languages.subtitle) { $cfg.languages.subtitle = @($cfg.languages.subtitle) }
    }
    if ($cfg.downloads) {
        foreach ($p in $cfg.downloads.PSObject.Properties) {
            $app = $p.Value
            if ($null -ne $app.files)       { $app.files       = @($app.files) }
            if ($null -ne $app.versionArgs) { $app.versionArgs = @($app.versionArgs) }
        }
    }
}
function Read-ConfigFile {
    $cfg = Get-Content -Raw -LiteralPath $CfgPath | ConvertFrom-Json
    Repair-ConfigArrays $cfg
    return $cfg
}
function Save-ConfigFile($obj) {
    $json = (ConvertTo-CvJson -Node $obj -Indent 0) -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($CfgPath, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Wait-Setup {
    # Pausa antes de limpiar la pantalla, para poder leer la info mostrada.
    Write-Host ''
    Read-Host 'ENTER para continuar' | Out-Null
}

# ===========================================================================
#  Editor de valores
# ===========================================================================
function Edit-Scalar {
    <# Devuelve @{ changed=$bool; value=... } conservando el tipo. #>
    param([string]$Key, $Current, [string]$Kind)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    if ($Kind -eq 'bool') {
        $def = 2; if ($Current) { $def = 1 }
        $p = Select-FromList -Title ("{0} (actual: {1})" -f $Key, "$Current".ToLower()) -Options @('true','false') -NoneLabel 'cancelar' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = ($p -eq 'true') }
    }
    # Selectores especiales por nombre de clave.
    if ($Key -in @('background','foreground')) {
        $colors = [enum]::GetNames([System.ConsoleColor])
        $def = [array]::IndexOf($colors, "$Current") + 1; if ($def -lt 1) { $def = 1 }
        $p = Select-FromList -Title ("{0} (actual: {1})" -f $Key, $Current) -Options $colors -NoneLabel 'cancelar' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = "$p" }
    }
    if ($Key -eq 'method') {
        $opts = @('peak','loudnorm','aacgain')
        $def = [array]::IndexOf($opts, "$Current") + 1; if ($def -lt 1) { $def = 1 }
        $p = Select-FromList -Title ("method (actual: {0})" -f $Current) -Options $opts -NoneLabel 'cancelar' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = "$p" }
    }

    $ans = (Read-Host ("   {0}  (actual: {1})  nuevo valor [ENTER=cancelar]" -f $Key, $Current)).Trim()
    if ($ans -eq '') { return @{ changed = $false } }
    if ($Kind -eq 'number') {
        if ($ans -match '^-?\d+$') { return @{ changed = $true; value = [long]$ans } }
        $d = 0.0
        if ([double]::TryParse($ans, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return @{ changed = $true; value = $d } }
        Write-Host '   Numero no valido.' -ForegroundColor Yellow
        return @{ changed = $false }
    }
    return @{ changed = $true; value = $ans }
}

function Edit-Array {
    <# Editor de listas de cadenas (idiomas, etc.). Devuelve @{ changed; value=@(...) }. #>
    param([string]$Key, $Arr)
    $items = @(@($Arr) | ForEach-Object { "$_" })
    $changed = $false
    while ($true) {
        Clear-Host
        $opts = @()
        for ($i = 0; $i -lt $items.Count; $i++) { $opts += ("[{0}] {1}" -f $i, $items[$i]) }
        $opts += '(+) Anadir elemento'
        if ($items.Count -gt 0) { $opts += '(-) Eliminar elemento' }
        $sel = Select-FromList -Title ("Lista '{0}'  ({1} elementos)" -f $Key, $items.Count) -Options $opts -NoneLabel 'volver' -DefaultIndex 0
        if ($sel -eq '') { break }
        if ($sel -eq '(+) Anadir elemento') {
            $v = (Read-Host '   Nuevo valor').Trim()
            if ($v -ne '') { $items = @($items) + $v; $changed = $true }
        }
        elseif ($sel -eq '(-) Eliminar elemento') {
            $d = (Read-Host '   Indice a eliminar').Trim()
            $n = 0
            if ([int]::TryParse($d, [ref]$n) -and $n -ge 0 -and $n -lt $items.Count) {
                $tmp = New-Object System.Collections.ArrayList
                for ($i = 0; $i -lt $items.Count; $i++) { if ($i -ne $n) { [void]$tmp.Add($items[$i]) } }
                $items = @($tmp.ToArray()); $changed = $true
            } else { Write-Host '   Indice no valido.' -ForegroundColor Yellow }
        }
        elseif ($sel -match '^\[(\d+)\]') {
            $i  = [int]$Matches[1]
            $nv = (Read-Host ("   Nuevo valor para [{0}] (actual: {1}) [ENTER=cancelar]" -f $i, $items[$i])).Trim()
            if ($nv -ne '') { $items[$i] = $nv; $changed = $true }
        }
    }
    return @{ changed = $changed; value = @($items) }
}

function Edit-Node {
    <# Navega un objeto de config: escalares se editan, objetos se recorren, arrays con su editor. #>
    param($Node, [string]$Path)
    while ($true) {
        Clear-Host
        $keys = @(Get-Keys $Node)
        $opts = @()
        foreach ($k in $keys) {
            $v = Get-Val $Node $k
            $kind = Get-NodeKind $v
            $preview = switch ($kind) {
                'object' { '{...}' }
                'array'  { '[' + ((@($v) | ForEach-Object { "$_" }) -join ', ') + ']' }
                'bool'   { "$v".ToLower() }
                'null'   { 'null' }
                default  { "$v" }
            }
            if ($preview.Length -gt 42) { $preview = $preview.Substring(0, 39) + '...' }
            $opts += ("{0} = {1}" -f $k, $preview)
        }
        $title = if ($Path) { "config > $Path" } else { 'config.json' }
        $sel = Select-FromList -Title $title -Options $opts -NoneLabel 'volver' -DefaultIndex 0
        if ($sel -eq '') { break }
        $key  = $keys[[array]::IndexOf($opts, $sel)]
        $val  = Get-Val $Node $key
        $kind = Get-NodeKind $val
        if ($kind -eq 'object') {
            $sub = if ($Path) { "$Path/$key" } else { "$key" }
            Edit-Node -Node $val -Path $sub
        }
        elseif ($kind -eq 'array') {
            $r = Edit-Array -Key $key -Arr $val
            if ($r.changed) { Set-Val $Node $key $r.value; $script:dirty = $true }
        }
        else {
            $r = Edit-Scalar -Key $key -Current $val -Kind $kind
            if ($r.changed) { Set-Val $Node $key $r.value; $script:dirty = $true }
        }
    }
}

function Edit-Config {
    Clear-Host
    Write-CvLog 'SETUP' 'Editor de config.json (0 = volver en cada nivel).'
    $cfg = Read-ConfigFile
    $script:dirty = $false
    Edit-Node -Node $cfg -Path ''
    if ($script:dirty) {
        $a = (Read-Host 'Guardar cambios en config.json? (S/n)').Trim()
        if ($a -eq '' -or $a -match '^[SsYy]') {
            Save-ConfigFile $cfg
            Write-CvLog 'SETUP' '[OK] - config.json guardado.'
        } else {
            Write-CvLog 'SETUP' 'Cambios descartados.'
        }
    } else {
        Write-CvLog 'SETUP' 'Sin cambios.'
    }
    Wait-Setup
}

# ===========================================================================
#  Gestion de herramientas (catalogo 'downloads')
# ===========================================================================
function Get-AppNames {
    $apps = $ctx.Downloads
    if ($apps -is [System.Collections.IDictionary]) { return @($apps.Keys) }
    if ($apps) { return @($apps.PSObject.Properties.Name) }
    return @()
}
function Get-App {
    param([string]$Name)
    Get-CvAppDescriptor -Context $ctx -Name $Name
}
function Remove-AppVersion {
    # Borra la carpeta de una version concreta (tools\<app>\<version>\<plataforma>).
    param([string]$Name, [string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return }
    $dir = Get-CvToolDir -Context $ctx -Name $Name -Version $Version
    if (Test-Path -LiteralPath $dir) { Remove-Item -Recurse -Force -LiteralPath $dir -ErrorAction SilentlyContinue }
}
function Set-AppSelected {
    param([string]$Name, [string]$Version)
    $cfg = Read-ConfigFile
    if ($cfg.downloads -and $cfg.downloads.PSObject.Properties[$Name]) {
        $cfg.downloads.$Name.selected = $Version
        Save-ConfigFile $cfg
        return $true
    }
    return $false
}
function Show-Dirs {
    # Checklist de las carpetas de trabajo; crea las que falten y pinta su estado.
    Write-Host ''
    Write-CvLog 'SETUP' 'Directorios de trabajo:'
    foreach ($d in (Get-CvWorkDirs -Context $ctx)) {
        $name = Split-Path $d -Leaf
        if (Test-Path -LiteralPath $d) {
            Write-CvLog 'SETUP' ("  {0,-12} [OK]" -f $name)
        } else {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Write-CvLog 'SETUP' ("  {0,-12} [CREADA]" -f $name)
        }
    }
}

function Show-Status {
    Write-Host ''
    Write-CvLog 'SETUP' 'Estado de las herramientas:'
    foreach ($n in (Get-AppNames)) {
        $app = Get-App $n
        if (-not (Test-CvToolSupported -Context $ctx -Name $n)) {
            Write-CvLog 'SETUP' ("  {0,-10} [NO SOPORTADO en {1}]    por defecto: {2}" -f $n, (Get-CvPlatform), "$($app.selected)")
            continue
        }
        $plat = Get-CvAppPlatform -Context $ctx -Name $n
        $inst = @(Get-CvInstalledVersions -Context $ctx -Name $n)
        $instTxt = if ($inst.Count) { ($inst -join ', ') } else { 'ninguna' }
        Write-CvLog 'SETUP' ("  {0,-10} [{1}] instaladas: {2,-22} por defecto (config): {3}" -f $n, $plat, $instTxt, "$($app.selected)")
    }
    Write-Host ''
}
function Invoke-InstallApp {
    param([string]$Name, [string]$Version, [switch]$Ask)
    if ([string]::IsNullOrWhiteSpace($Version)) { Write-CvLog 'SETUP' ("[ERR] - {0}: version no indicada" -f $Name); return $false }
    if (-not (Test-CvToolSupported -Context $ctx -Name $Name)) {
        Write-CvLog 'SETUP' ("[NO SOPORTADO] - {0} no tiene build para la plataforma de este equipo ({1})." -f $Name, (Get-CvPlatform))
        return $false
    }
    Write-CvLog 'SETUP' ("Reinstalando {0} {1} (se borra esa version y se descarga)..." -f $Name, $Version)
    Remove-AppVersion -Name $Name -Version $Version
    $ok = Install-CvTool -Context $ctx -Name $Name -Version $Version
    if (-not $ok) { Write-CvLog 'SETUP' ("[ERR] - Fallo la instalacion de {0} {1}" -f $Name, $Version); return $false }
    if ($Ask -and "$((Get-App $Name).selected)" -ne $Version) {
        $a = (Read-Host ("   Fijar {0} como version por defecto de {1} en config.json? (S/n)" -f $Version, $Name)).Trim()
        if ($a -eq '' -or $a -match '^[SsYy]') {
            if (Set-AppSelected -Name $Name -Version $Version) { Write-CvLog 'SETUP' ("[OK] - config.json: {0}.selected = {1}" -f $Name, $Version) }
            else { Write-CvLog 'SETUP' '[AVISO] - No se pudo actualizar config.json.' }
        }
    }
    return $true
}

# ===========================================================================
#  Mantenimiento de la carpeta Proceso (jobs / bloqueos / temporales)
# ===========================================================================
function Clear-Proceso {
    param([ValidateSet('jobs','locks','temps','all')][string]$What)
    $proc = $ctx.Proceso
    if (-not (Test-Path -LiteralPath $proc)) { Write-CvLog 'SETUP' 'No existe la carpeta Proceso.'; return }
    $patterns = switch ($What) {
        'jobs'  { @('*.job.json','*.job.json.tmp') }
        'locks' { @('*.lock') }
        'temps' { @('*.mkv','*.m4a','*_concat.wav','*.job.json.tmp') }
        'all'   { @('*.job.json','*.job.json.tmp','*.lock','*.mkv','*.m4a','*_concat.wav') }
    }
    $files = @()
    foreach ($p in $patterns) { $files += @(Get-ChildItem -LiteralPath $proc -Filter $p -File -ErrorAction SilentlyContinue) }
    $files = @($files | Sort-Object -Property FullName -Unique)
    if ($files.Count -eq 0) { Write-CvLog 'SETUP' 'Nada que eliminar.'; return }

    Write-CvLog 'SETUP' ("Se eliminaran {0} fichero(s):" -f $files.Count)
    $files | ForEach-Object { Write-Host ("   - {0}" -f $_.Name) }
    $a = (Read-Host 'Confirmar borrado? (s/N)').Trim()
    if ($a -match '^[SsYy]') {
        $files | Remove-Item -Force -ErrorAction SilentlyContinue
        Write-CvLog 'SETUP' '[OK] - Eliminados.'
    } else {
        Write-CvLog 'SETUP' 'Cancelado.'
    }
}

function Show-CleanMenu {
    Clear-Host
    $proc  = $ctx.Proceso
    $njob  = @(Get-ChildItem -LiteralPath $proc -Filter '*.job.json' -File -ErrorAction SilentlyContinue).Count
    $nlock = @(Get-ChildItem -LiteralPath $proc -Filter '*.lock'     -File -ErrorAction SilentlyContinue).Count
    $opts = @(
        ("Eliminar jobs (*.job.json)        [{0}]" -f $njob),
        ("Eliminar bloqueos (*.lock)        [{0}]" -f $nlock),
        'Eliminar temporales (mkv / m4a / wav)',
        'Eliminar TODO (jobs + bloqueos + temporales)'
    )
    $sel = Select-FromList -Title ("Limpiar carpeta Proceso") -Options $opts -NoneLabel 'volver' -DefaultIndex 0
    if ($sel -eq '') { return }
    Clear-Host
    switch -Wildcard ($sel) {
        'Eliminar jobs*'       { Clear-Proceso -What 'jobs' }
        'Eliminar bloqueos*'   { Clear-Proceso -What 'locks' }
        'Eliminar temporales*' { Clear-Proceso -What 'temps' }
        'Eliminar TODO*'       { Clear-Proceso -What 'all' }
    }
    Wait-Setup
}

# ===========================================================================
#  Menu principal
# ===========================================================================
$exit = $false
while (-not $exit) {
    Clear-Host
    $ctx = New-CvContext -Root $Root   # recargar por si cambio config.json
    Show-Dirs
    Show-Status

    $names = @(Get-AppNames)
    $opts  = @()
    foreach ($n in $names) { $opts += ("Instalar / cambiar version de {0}" -f $n) }
    $opts += 'Reinstalar TODO (version por defecto de cada app)'
    $opts += 'Editar configuracion (config.json)'
    $opts += 'Limpiar jobs / bloqueos (carpeta Proceso)'

    $choice = Select-FromList -Title 'SETUP - Que quieres hacer?' -Options $opts -NoneLabel 'salir' -DefaultIndex 1
    if ($choice -eq '') { $exit = $true; continue }

    if ($choice -eq 'Editar configuracion (config.json)') {
        Edit-Config                          # limpia y pausa por su cuenta
    }
    elseif ($choice -eq 'Limpiar jobs / bloqueos (carpeta Proceso)') {
        Show-CleanMenu                       # limpia y pausa por su cuenta
    }
    elseif ($choice -like 'Reinstalar TODO*') {
        Clear-Host
        foreach ($n in $names) { Invoke-InstallApp -Name $n -Version "$((Get-App $n).selected)" | Out-Null }
        Wait-Setup
    }
    else {
        $name = $names[[array]::IndexOf($opts, $choice)]
        Clear-Host
        $ver  = Select-CvToolVersion -Context $ctx -Name $name
        if ($ver -ne '') { Invoke-InstallApp -Name $name -Version $ver -Ask | Out-Null }
        else { Write-CvLog 'SETUP' 'Cancelado.' }
        Wait-Setup
    }
}

Clear-Host
Write-CvLog 'SETUP' 'Hecho.'

# Cerrar el log de la sesion.
if ($cvTranscript) { try { Stop-Transcript | Out-Null } catch {} }
