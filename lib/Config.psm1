<#
    Config.psm1 - Valores por defecto de config.json, carga y fusion.
    Get-CvConfigDefaults es la FUENTE UNICA de los defaults; Get-CvConfig los fusiona
    (fusion profunda) con el config.json del usuario. Sin dependencias de otros modulos.
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

function Get-CvConfigDefaults {
    <# Valores por defecto de config.json (fuente unica: los usa Get-CvConfig y el reset). #>
    $langs = @('spa','es','esp','es-es','es_es','castellano','spanish')
    [ordered]@{
        downloads = [ordered]@{
            ffmpeg = [ordered]@{
                selected     = '8.1.2'
                type         = 'zip'
                url          = 'https://github.com/GyanD/codexffmpeg/releases/download/{version}/ffmpeg-{version}-full_build.zip'
                binPath      = 'ffmpeg-{version}-full_build/bin'
                files        = @('ffmpeg.exe','ffprobe.exe','ffplay.exe')
                platform     = 'x86_64'
                versionExe   = 'ffmpeg.exe'
                versionArgs  = @('-version')
                versionRegex = 'ffmpeg version (\d+\.\d+(?:\.\d+)?)'
                versions = [ordered]@{
                    '8.1.2' = 'b8cdefab5f50590a076c27c2b56b0294a0e6154faded28ba1ba05ebc4f801f57'
                    '7.1.1' = 'd760e1b3574402ed18b4865851f87d87e73965a982e6453212df8621fed1c508'
                    '5.1.2' = '1f4056c147694228fddaeb925083338e35d952e4b65e3bd3c5a0a2c13c7800d6'
                }
            }
            aacgain = [ordered]@{
                selected     = '2.0.0'
                type         = 'file'
                url          = 'https://github.com/dgilman/aacgain/releases/download/{version}/aacgain-{version}-windows-amd64.exe'
                files        = @('aacgain.exe')
                platform     = 'x86_64'
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
}

function Get-CvConfig {
    <#
        Carga config.json (si existe) sobre los valores por defecto, por secciones.
        Cualquier clave ausente en el json usa el valor por defecto (fusion profunda).
    #>
    param([Parameter(Mandatory)][string]$Root)
    $cfg = Get-CvConfigDefaults
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

# ---------- ACCESO GENERICO A NODOS (PSCustomObject de ConvertFrom-Json e IDictionary) ----------

function Get-CvNodeKind($v) {
    if ($null -eq $v)                                        { return 'null' }
    if ($v -is [bool])                                       { return 'bool' }
    if ($v -is [string])                                     { return 'string' }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [single] -or $v -is [decimal]) { return 'number' }
    if ($v -is [System.Collections.IDictionary])             { return 'object' }
    if ($v -is [System.Management.Automation.PSCustomObject]){ return 'object' }
    if ($v -is [System.Collections.IEnumerable])             { return 'array' }
    return 'string'
}
function Get-CvNodeKeys($node) {
    if ($node -is [System.Collections.IDictionary]) { return @($node.Keys) }
    if ($node) { return @($node.PSObject.Properties.Name) }
    return @()
}
function Get-CvNodeVal($node, $key) {
    # La coma unaria evita que PowerShell desenvuelva un array de 1 elemento al retornar.
    if ($node -is [System.Collections.IDictionary]) { return , $node[$key] }
    return , $node.$key
}
function Set-CvNodeVal($node, $key, $value) {
    if ($node -is [System.Collections.IDictionary]) { $node[$key] = $value }
    else { $node.$key = $value }
}

# ---------- SERIALIZADOR JSON PROPIO (4 espacios, arrays de escalares en linea) ----------

function ConvertTo-CvJsonString([string]$s) {
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
    switch (Get-CvNodeKind $Node) {
        'object' {
            $keys = @(Get-CvNodeKeys $Node)
            if ($keys.Count -eq 0) { return '{}' }
            $parts = @()
            foreach ($k in $keys) {
                $parts += ('{0}{1}: {2}' -f $pad1, (ConvertTo-CvJsonString "$k"), (ConvertTo-CvJson (Get-CvNodeVal $Node $k) ($Indent + 1)))
            }
            return "{`n" + ($parts -join ",`n") + "`n$pad}"
        }
        'array' {
            $items = @($Node)
            if ($items.Count -eq 0) { return '[]' }
            $allScalar = $true
            foreach ($it in $items) { if ((Get-CvNodeKind $it) -in @('object','array')) { $allScalar = $false; break } }
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
        default  { return (ConvertTo-CvJsonString "$Node") }
    }
}

# ---------- LECTURA / ESCRITURA DE config.json ----------

function Repair-CvConfigArrays($cfg) {
    <#
        PS 5.1 ConvertFrom-Json desenvuelve los arrays de 1 elemento a escalar (["es"] -> "es").
        Forzamos a array los campos que del esquema deben serlo (se editan como lista / [...] ).
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
function Read-CvConfigFile {
    param([Parameter(Mandatory)][string]$Path)
    $cfg = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    Repair-CvConfigArrays $cfg
    return $cfg
}
function Save-CvConfigFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Config)
    $json = (ConvertTo-CvJson -Node $Config -Indent 0) -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Reset-CvConfig {
    <#
        Restablece config.json a los valores por defecto, CONSERVANDO el catalogo de
        herramientas (seccion 'downloads' del config actual). Hace copia en <Path>.bak.
        Devuelve $true.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        try { Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force } catch {}
        try {
            $cur = Read-CvConfigFile -Path $Path
        } catch { $cur = $null }
    }
    $def = Get-CvConfigDefaults
    if ($cur -and $cur.downloads) { $def['downloads'] = $cur.downloads }   # preservar herramientas
    Save-CvConfigFile -Path $Path -Config $def
    return $true
}

Export-ModuleMember -Function *
