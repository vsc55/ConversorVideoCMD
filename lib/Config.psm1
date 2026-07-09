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
            # 7zr: extractor 7z minimo (un solo .exe). Es el 'bootstrap' que necesita mkvtoolnix
            # (que se distribuye como .7z/LZMA y no lo abre Expand-Archive ni el tar de Windows).
            sevenzip = [ordered]@{
                selected     = '26.02'
                type         = 'file'
                url          = 'https://github.com/ip7z/7zip/releases/download/{version}/7zr.exe'
                files        = @('7zr.exe')
                platform     = 'x86_64'
                versionExe   = '7zr.exe'
                versionArgs  = @()
                versionRegex = '7-Zip.*?(\d+\.\d+)'
                versions     = [ordered]@{
                    '26.02' = '56b8cc9f4971cef253644fafe54063ed7fdca551d4dee0f8c6baa81b855acd72'
                }
            }
            # mkvtoolnix: solo se usa 'mkvpropedit.exe' para limpiar las etiquetas DURATION del
            # MKV final. Se distribuye como .7z (se extrae con 7zr). El exe es autosuficiente.
            mkvtoolnix = [ordered]@{
                selected     = '100.0'
                type         = '7z'
                url          = 'https://mkvtoolnix.download/windows/releases/{version}/mkvtoolnix-64-bit-{version}.7z'
                binPath      = 'mkvtoolnix'
                files        = @('mkvpropedit.exe')
                dependsOn    = @('sevenzip')   # 7zr para extraer el .7z (LZMA)
                platform     = 'x86_64'
                versionExe   = 'mkvpropedit.exe'
                versionArgs  = @('--version')
                versionRegex = 'mkvpropedit v(\d+\.\d+)'
                versions     = [ordered]@{
                    '100.0' = '061de38bd10e7e28697b897e0b890b78d6f2ec8d668a9c198600ed45c19672ab'
                }
            }
        }
        languages = [ordered]@{ audio = $langs; subtitle = $langs }
        # encode: outputExtension = contenedor de salida; extensions = extensiones de ENTRADA que
        # se procesan de Original\ (sin punto); audioChannels = canales del audio recodificado (2
        # = estereo; 6 = 5.1; 8 = 7.1); threads/fps/audioHz para ffmpeg.
        encode    = [ordered]@{ outputExtension = 'mkv'; extensions = @('avi','flv','mp4','mov','mkv'); threads = 0; fps = '23.976'; audioHz = 44100; audioChannels = 2 }
        # border: deteccion de bordes negros con cropdetect.
        #  - start: segundo del primer punto de escaneo. duration: segundos que escanea CADA punto.
        #  - samples: en cuantos puntos repartidos del video se escanea (1 = solo al inicio, clasico).
        #  - autoAcceptPct: si el recorte mas votado alcanza este % de los puntos que detectaron
        #    borde, se acepta AUTOMATICAMENTE (se descartan los atipicos); por debajo, se pregunta.
        #  - autoAcceptMinMargin: ADEMAS del %, el mas votado debe superar al 2o por al menos estos
        #    votos. Evita auto-aceptar con evidencia debil cuando hay pocas muestras (2/3 = 67% pero
        #    solo 1 de margen -> pregunta; 6/9 = 67% con 3+ de margen -> auto). 0 = sin margen.
        border    = [ordered]@{ start = 120; duration = 120; samples = 9; autoAcceptPct = 60; autoAcceptMinMargin = 2 }
        # Previsualizacion con ffplay (audio/video/bordes en PREPARAR): desde que segundo empieza
        # y cuantos dura la muestra. Util para buscar dialogo y saber el idioma de una pista.
        preview   = [ordered]@{ start = 120; seconds = 30 }
        # volume: metodo de normalizacion. peakTarget = pico objetivo en dBFS del metodo 'peak'
        # (0 = maximo sin recorte; -1 deja margen/headroom contra el clipping inter-sample del AAC).
        volume    = [ordered]@{ method = 'peak'; peakTarget = 0; loudnorm = [ordered]@{ I = -16; TP = -1.5; LRA = 11 } }
        # Postproceso del MKV final:
        #  - stripTags: limpiar con mkvpropedit las etiquetas DURATION por pista que anade el
        #    muxer de ffmpeg (mkvpropedit vacio = usar la version descargada en tools\).
        #  - attachments: conservar adjuntos del original, permitiendo/excluyendo por categoria
        #    (keep = interruptor maestro; fonts = fuentes p. ej. para subtitulos ASS; covers =
        #    caratulas/imagenes; other = el resto).
        postprocess = [ordered]@{
            stripTags   = $true
            mkvpropedit = ''
            attachments = [ordered]@{ keep = $false; fonts = $true; covers = $false; other = $false }
        }
        behavior  = [ordered]@{ cleanTemps = $true; separateWindow = $true; lockCloseButton = $true; debug = $false; log = $true; workers = 2; retries = 2; asciiMarks = $false }
        # Modo pruebas: si 'enabled', cada archivo se codifica solo hasta 'minutes' minutos (el resto
        #   se descarta). Sirve para validar perfiles/ajustes rapido. Tambien se activa con 'test_on'.
        test      = [ordered]@{ enabled = $false; minutes = 5 }
        console   = [ordered]@{ background = 'DarkBlue'; foreground = 'Yellow'; font = 'Cascadia Code'; fontSize = 18; windowWidth = 100; windowHeight = 50 }
        # Carpetas de trabajo: vacio = junto al programa; admite ruta absoluta o relativa.
        paths     = [ordered]@{ original = ''; proceso = ''; convertido = ''; logs = '' }
        # Perfiles de codificacion PROPIOS: se ANADEN a los 7 de serie en el menu USAR PERFIL
        # (no los sustituyen). Cada objeto admite: label, videoEncoder, videoProfile, videoLevel,
        # qmin, qmax, crf, detectBorder, changeSize, audioEncoder, audioBitrate, audioHz.
        # Ejemplo: { "label":"Anime 1080p", "videoEncoder":"libx265", "crf":18, "changeSize":"1920:-1" }
        profiles  = @()
    }
}

function Resolve-CvConfigPathArg {
    <#
        Resuelve el argumento -Config de Convert.ps1/setup.ps1 a una ruta completa:
        vacio = <Root>\config.json; relativo = respecto al directorio actual; absoluto = tal cual.
    #>
    param([Parameter(Mandatory)][string]$Root, [string]$Config = '')
    if ([string]::IsNullOrWhiteSpace($Config)) { return (Join-Path $Root 'config.json') }
    if ([System.IO.Path]::IsPathRooted($Config)) { return $Config }
    return (Join-Path (Get-Location).Path $Config)
}

function Get-CvConfig {
    <#
        Carga config.json (si existe) sobre los valores por defecto, por secciones.
        Cualquier clave ausente en el json usa el valor por defecto (fusion profunda).
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        # Ruta explicita al config (parametro -Config de Convert/setup). Vacio = Root\config.json.
        [string]$Path = ''
    )
    $cfg = Get-CvConfigDefaults
    $path = if ([string]::IsNullOrWhiteSpace($Path)) { Join-Path $Root 'config.json' } else { $Path }
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
    # Nota: en un PSCustomObject sin propiedades, .Name devuelve $null y @($null) daria una
    # clave fantasma; filtramos nulos/vacios para que un objeto vacio de 0 claves.
    if ($node) { return @($node.PSObject.Properties.Name | Where-Object { -not [string]::IsNullOrEmpty($_) }) }
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

# ---------- APLICAR SOLO LOS CAMBIOS (para que el editor no reescriba todo config.json) ----------

function Get-CvChildNode {
    <# Devuelve el subnodo objeto $Node[$Key]; si no existe (o no es objeto) lo crea vacio. #>
    param($Node, [string]$Key)
    if ($Node -is [System.Collections.IDictionary]) {
        if (-not $Node.Contains($Key) -or (Get-CvNodeKind $Node[$Key]) -ne 'object') { $Node[$Key] = [ordered]@{} }
        return $Node[$Key]
    }
    if (-not $Node.PSObject.Properties[$Key]) { $Node | Add-Member -NotePropertyName $Key -NotePropertyValue ([pscustomobject]@{}) -Force }
    elseif ((Get-CvNodeKind $Node.$Key) -ne 'object') { $Node.$Key = [pscustomobject]@{} }
    return $Node.$Key
}

function Set-CvChildLeaf {
    <# Fija $Node[$Key] = $Value, creando la propiedad si falta (PSCustomObject o IDictionary). #>
    param($Node, [string]$Key, $Value)
    if ($Node -is [System.Collections.IDictionary]) { $Node[$Key] = $Value; return }
    if ($Node.PSObject.Properties[$Key]) { $Node.$Key = $Value }
    else { $Node | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force }
}

function Remove-CvChild {
    <# Elimina la clave $Key de $Node (PSCustomObject o IDictionary). #>
    param($Node, [string]$Key)
    if ($Node -is [System.Collections.IDictionary]) { if ($Node.Contains($Key)) { $Node.Remove($Key) }; return }
    if ($Node.PSObject.Properties[$Key]) { $Node.PSObject.Properties.Remove($Key) }
}

function Update-CvConfigEdits {
    <#
        Aplica en $Target (config.json crudo) SOLO las hojas que cambiaron entre $Before y $Edited:
          - si el nuevo valor es IGUAL al default -> se ELIMINA de $Target (se usara el default).
          - si DIFIERE del default                -> se fija en $Target.
        Las hojas no editadas no se tocan (un config completo conserva lo no editado). Las
        secciones que quedan vacias tras eliminar se podan. Compara por serializacion JSON.
    #>
    param($Edited, $Before, $Default, $Target)
    $bkeys = @(Get-CvNodeKeys $Before)
    $dkeys = @(Get-CvNodeKeys $Default)
    foreach ($key in @(Get-CvNodeKeys $Edited)) {
        $ev = Get-CvNodeVal $Edited $key
        $bv = if ($bkeys -contains $key) { Get-CvNodeVal $Before $key } else { $null }
        # sin cambios respecto al inicio de la edicion -> no tocar
        if (($bkeys -contains $key) -and ((ConvertTo-CvJson $ev 0) -eq (ConvertTo-CvJson $bv 0))) { continue }

        $dv = if ($dkeys -contains $key) { Get-CvNodeVal $Default $key } else { $null }

        if ((Get-CvNodeKind $ev) -eq 'object' -and (Get-CvNodeKind $bv) -eq 'object') {
            # seccion con cambios dentro: recursar y podar si queda vacia
            $tchild = Get-CvChildNode -Node $Target -Key $key
            Update-CvConfigEdits -Edited $ev -Before $bv -Default $dv -Target $tchild
            if (@(Get-CvNodeKeys $tchild).Count -eq 0) { Remove-CvChild -Node $Target -Key $key }
        }
        elseif (($dkeys -contains $key) -and ((ConvertTo-CvJson $ev 0) -eq (ConvertTo-CvJson $dv 0))) {
            Remove-CvChild -Node $Target -Key $key      # volvio al default -> quitar del json
        }
        else {
            Set-CvChildLeaf -Node $Target -Key $key -Value $ev   # distinto del default -> guardar
        }
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
            if ($null -ne $app.dependsOn)   { $app.dependsOn   = @($app.dependsOn) }
        }
    }
    if ($cfg.PSObject.Properties['profiles'] -and $null -ne $cfg.profiles) { $cfg.profiles = @($cfg.profiles) }
    if ($cfg.encode -and $null -ne $cfg.encode.extensions) { $cfg.encode.extensions = @($cfg.encode.extensions) }
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
