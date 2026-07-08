<#
    setup.ps1 - Gestion de herramientas y configuracion.

    Menu principal:
      - Instalar / cambiar version de ffmpeg (u otra app del catalogo 'downloads').
      - Reinstalar TODO (version por defecto de cada app).
      - Editar configuracion: editor navegable de TODO config.json (idiomas, encode,
        bordes, volumen, comportamiento, consola, descargas...) sin tocarlo a mano.

    Reutiliza el catalogo 'downloads' de config.json y las funciones de descarga de
    lib\Tools.psm1 (las mismas que usa Convert.ps1 cuando falta una herramienta).
    El guardado/reset de config.json vive en lib\Config.psm1.

    Lanzar:  setup.cmd   (o)   powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1
#>

[CmdletBinding()]
param(
    # Fichero de configuracion a editar/gestionar (por defecto config.json junto al programa).
    # Admite ruta absoluta o relativa al directorio actual.
    [string]$Config = ''
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = $PSScriptRoot
$Lib  = Join-Path $Root 'lib'
$modules = @('Log','Config','Context','Console','Exec','Tools')   # setup no usa el pipeline de conversion
foreach ($m in $modules) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}

# Resolver el fichero de config (-Config): relativo al directorio actual; vacio = Root\config.json.
$CfgPath = if ([string]::IsNullOrWhiteSpace($Config)) {
    Join-Path $Root 'config.json'
} elseif ([System.IO.Path]::IsPathRooted($Config)) {
    $Config
} else {
    Join-Path (Get-Location).Path $Config
}

$ctx = New-CvContext -Root $Root -ConfigPath $CfgPath
Set-CvMarkStyle -Ascii $ctx.AsciiMarks   # [OK]/[ERROR] en vez de simbolos si behavior.asciiMarks
Set-CvAppearance -Context $ctx -Title ("ConversorVideoCMD {0} - Setup" -f $ctx.Version)
Show-CvHeader -Context $ctx -Subtitle 'Setup'

# Log de la sesion (transcript) a logs\ (behavior.log / marcador no_log).
$logFile = Start-CvLog -Context $ctx -Prefix 'setup'

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
        $keys = @(Get-CvNodeKeys $Node)
        $opts = @()
        foreach ($k in $keys) {
            $v = Get-CvNodeVal $Node $k
            $kind = Get-CvNodeKind $v
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
        $val  = Get-CvNodeVal $Node $key
        $kind = Get-CvNodeKind $val
        if ($Path -eq '' -and $key -eq 'profiles') {
            # Perfiles propios: array de objetos; el editor de listas (escalares) los corromperia.
            Clear-Host
            Write-CvLog 'SETUP' 'Los perfiles propios se editan a mano en config.json (seccion "profiles").'
            Write-CvLog 'SETUP' 'Se anaden al menu USAR PERFIL como 8, 9, ... (ver docs/comandos.md).'
            Wait-Setup
            continue
        }
        if ($kind -eq 'object') {
            $sub = if ($Path) { "$Path/$key" } else { "$key" }
            Edit-Node -Node $val -Path $sub
        }
        elseif ($kind -eq 'array') {
            $r = Edit-Array -Key $key -Arr $val
            if ($r.changed) { Set-CvNodeVal $Node $key $r.value; $script:dirty = $true }
        }
        else {
            $r = Edit-Scalar -Key $key -Current $val -Kind $kind
            if ($r.changed) { Set-CvNodeVal $Node $key $r.value; $script:dirty = $true }
        }
    }
}

function Edit-Config {
    Clear-Host
    Write-CvLog 'SETUP' 'Editor de config.json (0 = volver en cada nivel).'
    # Se edita el config FUSIONADO (defaults + overrides), asi el editor muestra TODAS las
    # opciones aunque config.json sea minimo. $before es una copia sin editar para saber
    # exactamente que cambio.
    $cfg    = Get-CvConfig -Root $Root -Path $CfgPath
    $before = Get-CvConfig -Root $Root -Path $CfgPath
    $script:dirty = $false
    Edit-Node -Node $cfg -Path ''
    if ($script:dirty) {
        $a = (Read-Host 'Guardar cambios en config.json? (S/n)').Trim()
        if ($a -eq '' -or $a -match '^[SsYy]') {
            # Aplicar SOLO lo editado sobre el config.json ACTUAL (crudo): lo que difiere del
            # default se guarda; lo que vuelve al default se elimina del fichero.
            $raw = if (Test-Path -LiteralPath $CfgPath) { Read-CvConfigFile -Path $CfgPath } else { [pscustomobject]@{} }
            Update-CvConfigEdits -Edited $cfg -Before $before -Default (Get-CvConfigDefaults) -Target $raw
            Save-CvConfigFile -Path $CfgPath -Config $raw
            Write-CvLog 'SETUP' '[OK] - config.json actualizado (solo los valores distintos del default).'
        } else {
            Write-CvLog 'SETUP' 'Cambios descartados.'
        }
    } else {
        Write-CvLog 'SETUP' 'Sin cambios.'
    }
    Wait-Setup
}

function Reset-Config {
    # UI del reset; la logica vive en Reset-CvConfig (modulo Config).
    Clear-Host
    Write-CvLog 'SETUP' 'Restablecer config.json a los valores por defecto.'
    Write-CvLog 'SETUP' 'Se CONSERVA el catalogo de herramientas (downloads). El resto vuelve al valor por defecto.'
    $a = (Read-Host 'Continuar? (s/N)').Trim()
    if ($a -notmatch '^[SsYy]') { Write-CvLog 'SETUP' 'Cancelado.'; Wait-Setup; return }
    [void](Reset-CvConfig -Path $CfgPath)
    Write-CvLog 'SETUP' '[OK] - config.json restablecido (copia en config.json.bak; catalogo de herramientas conservado).'
    Wait-Setup
}

function Clear-Logs {
    # UI de limpieza de logs; la logica vive en Log.psm1 (excluye el log de la sesion actual).
    Clear-Host
    $files = @(Get-CvLogFiles -Context $ctx -ExceptPath $logFile)
    if ($files.Count -eq 0) { Write-CvLog 'SETUP' 'No hay logs que eliminar.'; Wait-Setup; return }
    Write-CvLog 'SETUP' ("Se eliminaran {0} log(s):" -f $files.Count)
    $files | ForEach-Object { Write-Host ("   - {0}" -f $_.Name) }
    $a = (Read-Host 'Confirmar borrado? (s/N)').Trim()
    if ($a -match '^[SsYy]') {
        [void](Remove-CvLogFiles -Files $files)
        Write-CvLog 'SETUP' '[OK] - Logs eliminados.'
    } else {
        Write-CvLog 'SETUP' 'Cancelado.'
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
    # Fija downloads.<app>.selected en config.json (solo el override). Si config.json es
    # minimo y la app o la seccion no estan, se crean con {selected} (el resto del descriptor
    # sale de los defaults al fusionar).
    param([string]$Name, [string]$Version)
    $cfg = Read-CvConfigFile -Path $CfgPath
    if (-not $cfg.PSObject.Properties['downloads'] -or $null -eq $cfg.downloads) {
        $cfg | Add-Member -NotePropertyName 'downloads' -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if (-not $cfg.downloads.PSObject.Properties[$Name]) {
        $cfg.downloads | Add-Member -NotePropertyName $Name -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if ($cfg.downloads.$Name.PSObject.Properties['selected']) { $cfg.downloads.$Name.selected = $Version }
    else { $cfg.downloads.$Name | Add-Member -NotePropertyName 'selected' -NotePropertyValue $Version -Force }
    Save-CvConfigFile -Path $CfgPath -Config $cfg
    return $true
}
function Show-Dirs {
    # Checklist de las carpetas de trabajo; crea las que falten y pinta su estado.
    Write-Host ''
    Write-CvLog 'SETUP' 'Directorios de trabajo:'
    foreach ($d in (Get-CvWorkDirs -Context $ctx)) {
        $name = Split-Path $d -Leaf
        if (Test-Path -LiteralPath $d) {
            Write-CvLog 'SETUP' ("  {0,-12} {1}" -f $name, (Get-CvMark $true))
        } else {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Write-CvLog 'SETUP' ("  {0,-12} {1} (creada)" -f $name, (Get-CvMark $true))
        }
    }
}

function Show-Status {
    Write-Host ''
    Write-CvLog 'SETUP' 'Estado de las herramientas:'
    foreach ($n in (Get-AppNames)) {
        $app = Get-App $n
        if (-not (Test-CvToolSupported -Context $ctx -Name $n)) {
            Write-CvLog 'SETUP' ("  {0} {1,-10} [NO SOPORTADO en {2}]    por defecto: {3}" -f (Get-CvMark $false), $n, (Get-CvPlatform), "$($app.selected)")
            continue
        }
        $plat = Get-CvAppPlatform -Context $ctx -Name $n
        $inst = @(Get-CvInstalledVersions -Context $ctx -Name $n)
        $instTxt = if ($inst.Count) { ($inst -join ', ') } else { 'ninguna' }
        # Marca: la version 'selected' (la que usa el conversor) esta instalada?
        $selOk = ($inst -contains "$($app.selected)")
        Write-CvLog 'SETUP' ("  {0} {1,-10} [{2}] instaladas: {3,-22} por defecto (config): {4}" -f (Get-CvMark $selOk), $n, $plat, $instTxt, "$($app.selected)")
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
#  Compatibilidad GPU (NVENC) de las versiones de ffmpeg instaladas
# ===========================================================================
function Show-NvencCheck {
    Clear-Host
    if (-not (Test-CvToolSupported -Context $ctx -Name 'ffmpeg')) {
        Write-CvLog 'SETUP' ("ffmpeg [NO SOPORTADO] en esta plataforma ({0})." -f (Get-CvPlatform))
        Wait-Setup; return
    }
    $vers = @(Get-CvInstalledVersions -Context $ctx -Name 'ffmpeg')
    if ($vers.Count -eq 0) {
        Write-CvLog 'SETUP' 'No hay ninguna version de ffmpeg instalada. Instala una primero.'
        Wait-Setup; return
    }
    Write-CvLog 'SETUP' ("Comprobando NVENC (codificacion por GPU) en {0} version(es) de ffmpeg..." -f $vers.Count)
    foreach ($v in $vers) {
        Write-Host ''
        [void](Write-CvNvencReport -Context $ctx -Version $v -Tag ("[FFMPEG {0}]" -f $v))
    }
    Wait-Setup
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
#  Estado general (directorios de trabajo + herramientas)
# ===========================================================================
function Show-Estado {
    $sep = '=' * 64
    Write-Host $sep
    Write-Host 'ESTADO'
    Write-Host $sep
    Show-Dirs
    Show-Status
    Write-Host $sep
}

# ===========================================================================
#  Submenu de herramientas (instalar / cambiar version de cada app)
# ===========================================================================
function Show-ToolsMenu {
    while ($true) {
        Clear-Host
        $names = @(Get-AppNames)
        $opts  = @()
        foreach ($n in $names) { $opts += ("Instalar / cambiar version de {0}" -f $n) }
        $opts += 'Reinstalar TODO (version por defecto de cada app)'
        $sel = Select-FromList -Title 'HERRAMIENTAS (instalar / versiones)' -Options $opts -NoneLabel 'volver' -DefaultIndex 1
        if ($sel -eq '') { return }
        Clear-Host
        if ($sel -like 'Reinstalar TODO*') {
            foreach ($n in $names) { Invoke-InstallApp -Name $n -Version "$((Get-App $n).selected)" | Out-Null }
        } else {
            $name = $names[[array]::IndexOf($opts, $sel)]
            $ver  = Select-CvToolVersion -Context $ctx -Name $name
            if ($ver -ne '') { Invoke-InstallApp -Name $name -Version $ver -Ask | Out-Null }
            else { Write-CvLog 'SETUP' 'Cancelado.' }
        }
        Wait-Setup
    }
}

# ===========================================================================
#  Menu principal
# ===========================================================================
$exit = $false
$firstMenu = $true
while (-not $exit) {
    if (-not $firstMenu) { Clear-Host }   # la 1a vuelta no limpia: deja ver la cabecera
    $firstMenu = $false
    $ctx = New-CvContext -Root $Root -ConfigPath $CfgPath   # recargar por si cambio config.json

    $opts    = @()
    $headers = @{}

    $headers[$opts.Count] = 'Herramientas'
    $opts += 'Instalar / gestionar herramientas (ffmpeg, aacgain, mkvtoolnix...)'

    $headers[$opts.Count] = 'Estado'
    $opts += 'Ver estado (directorios y herramientas)'

    $headers[$opts.Count] = 'Compatibilidad'
    $opts += 'Comprobar compatibilidad GPU (NVENC de ffmpeg)'

    $headers[$opts.Count] = 'Configuracion'
    $opts += 'Editar configuracion (config.json)'
    $opts += 'Restablecer config.json (valores por defecto)'

    $headers[$opts.Count] = 'Limpieza'
    $opts += 'Limpiar jobs / bloqueos (carpeta Proceso)'
    $opts += 'Limpiar logs (carpeta logs)'

    $choice = Select-FromList -Title 'SETUP - Que quieres hacer?' -Options $opts -NoneLabel 'salir' -DefaultIndex 1 -Headers $headers
    if ($choice -eq '') { $exit = $true; continue }

    if ($choice -eq 'Instalar / gestionar herramientas (ffmpeg, aacgain, mkvtoolnix...)') {
        Show-ToolsMenu                       # submenu con una entrada por app + reinstalar todo
    }
    elseif ($choice -eq 'Ver estado (directorios y herramientas)') {
        Clear-Host
        Show-Estado
        Wait-Setup
    }
    elseif ($choice -eq 'Editar configuracion (config.json)') {
        Edit-Config                          # limpia y pausa por su cuenta
    }
    elseif ($choice -eq 'Restablecer config.json (valores por defecto)') {
        Reset-Config                         # limpia y pausa por su cuenta
    }
    elseif ($choice -eq 'Limpiar jobs / bloqueos (carpeta Proceso)') {
        Show-CleanMenu                       # limpia y pausa por su cuenta
    }
    elseif ($choice -eq 'Limpiar logs (carpeta logs)') {
        Clear-Logs                           # limpia y pausa por su cuenta
    }
    elseif ($choice -eq 'Comprobar compatibilidad GPU (NVENC de ffmpeg)') {
        Show-NvencCheck                      # limpia y pausa por su cuenta
    }
}

Clear-Host
Write-CvLog 'SETUP' 'Hecho.'

# Cerrar el log de la sesion.
if ($logFile) { Stop-CvLog }
