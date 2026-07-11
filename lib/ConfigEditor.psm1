<#
    ConfigEditor.psm1 - Editor INTERACTIVO de config.json (usado por setup.ps1).

    UI por encima de las funciones puras del arbol de config de Config.psm1 (Get-CvNode*/Set-CvNodeVal/
    Update-CvConfigEdits/ConvertTo-CvJson...) y de los menus de Console.psm1 (Select-FromList). Se separa
    de Config.psm1 para que ese modulo siga siendo la capa de datos (defaults/serializacion/IO) sin UI.
    Punto de entrada: Edit-CvConfigFile. Estado interno de "hubo cambios": $script:CvEditDirty.
#>

$script:CvEditDirty = $false

function Read-CvEditorPause {
    <# Pausa "ENTER para continuar" propia del editor (equivalente a la de setup), para poder leer un
       mensaje antes de que el siguiente Clear-Host lo borre. #>
    Write-Host ''
    [void](Read-Host 'ENTER para continuar')
}

function Edit-Scalar {
    <#
        Devuelve @{ changed=$bool; value=... } conservando el tipo. La marca `<= por defecto` senala
        el valor POR DEFECTO DE FABRICA (-Default, de Get-CvConfigDefaults), NO el actual; el actual
        se muestra en el titulo. La opcion 0 (cancelar) deja el valor actual sin cambios.
    #>
    param([string]$Key, $Current, [string]$Kind, $Default = $null)
    $inv = [System.Globalization.CultureInfo]::InvariantCulture

    if ($Kind -eq 'bool') {
        $def = if ($Default) { 1 } else { 2 }   # marca el DEFAULT de fabrica (no el actual)
        $p = Select-FromList -Title ("{0} (actual: {1})" -f $Key, "$Current".ToLower()) -Options @('true','false') -NoneLabel 'cancelar (dejar actual)' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = ($p -eq 'true') }
    }
    # Selectores especiales por nombre de clave.
    if ($Key -in @('background','foreground')) {
        $colors = [enum]::GetNames([System.ConsoleColor])
        $def = [array]::IndexOf($colors, "$Default") + 1
        if ($def -lt 1) { $def = [array]::IndexOf($colors, "$Current") + 1 }
        if ($def -lt 1) { $def = 1 }
        $p = Select-FromList -Title ("{0} (actual: {1})" -f $Key, $Current) -Options $colors -NoneLabel 'cancelar (dejar actual)' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = "$p" }
    }
    if ($Key -eq 'method') {
        $opts = @(Get-CvVolumeMethods)
        $def = [array]::IndexOf($opts, "$Default") + 1
        if ($def -lt 1) { $def = [array]::IndexOf($opts, "$Current") + 1 }
        if ($def -lt 1) { $def = 1 }
        $p = Select-FromList -Title ("method (actual: {0})" -f $Current) -Options $opts -NoneLabel 'cancelar (dejar actual)' -DefaultIndex $def
        if ($p -eq '') { return @{ changed = $false } }
        return @{ changed = $true; value = "$p" }
    }

    # Numero / texto libre: sin menu; se muestra actual y default, ENTER = dejar actual.
    $defTxt = if ($null -ne $Default) { ", por defecto: $Default" } else { '' }
    $ans = (Read-Host ("   {0}  (actual: {1}{2})  nuevo valor [ENTER=cancelar]" -f $Key, $Current, $defTxt)).Trim()
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
    <#
        Navega un objeto de config: escalares se editan, objetos se recorren, arrays con su editor.
        -CfgName = nombre del fichero en uso (para el breadcrumb del titulo). Marca $script:CvEditDirty
        si hay algun cambio. La seccion 'profiles' (array de objetos) no se edita aqui (se avisa).
    #>
    param($Node, [string]$Path, [string]$CfgName = 'config.json')
    while ($true) {
        Clear-Host
        $keys = @(Get-CvNodeKeys $Node)
        $opts = @(); $descs = @()
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
            $opts  += ("{0} = {1}" -f $k, $preview)
            # Ayuda de la opcion (que hace) mostrada junto al valor; ruta con '/' como aqui.
            $descs += (Get-CvHelpFor $(if ($Path) { "$Path/$k" } else { "$k" }))
        }
        $title = if ($Path) { "$CfgName > $Path" } else { $CfgName }
        $sel = Select-FromList -Title $title -Options $opts -Descriptions $descs -NoneLabel 'volver' -DefaultIndex 0
        if ($sel -eq '') { break }
        $key  = $keys[[array]::IndexOf($opts, $sel)]
        $val  = Get-CvNodeVal $Node $key
        $kind = Get-CvNodeKind $val
        if ($Path -eq '' -and $key -eq 'profiles') {
            # Perfiles propios: array de objetos; el editor de listas (escalares) los corromperia.
            Clear-Host
            Write-CvLog 'SETUP' ("Los perfiles propios se editan a mano en {0} (seccion 'profiles')." -f $CfgName)
            Write-CvLog 'SETUP' 'Se anaden al menu USAR PERFIL como 8, 9, ... (ver docs/ref-comandos.md).'
            Read-CvEditorPause
            continue
        }
        if ($kind -eq 'object') {
            $sub = if ($Path) { "$Path/$key" } else { "$key" }
            Edit-Node -Node $val -Path $sub -CfgName $CfgName
        }
        elseif ($kind -eq 'array') {
            $r = Edit-Array -Key $key -Arr $val
            if ($r.changed) { Set-CvNodeVal $Node $key $r.value; $script:CvEditDirty = $true }
        }
        else {
            # Default de fabrica de esta opcion (por su ruta), para marcarlo en el editor.
            $defVal = Get-CvConfigDefaultValue $(if ($Path) { "$Path/$key" } else { "$key" })
            $r = Edit-Scalar -Key $key -Current $val -Kind $kind -Default $defVal
            if ($r.changed) { Set-CvNodeVal $Node $key $r.value; $script:CvEditDirty = $true }
        }
    }
}

function Edit-CvConfigFile {
    <#
        Editor interactivo del fichero de config -CfgPath (nombre -CfgName para los textos). Edita el
        config FUSIONADO (defaults + overrides) para mostrar TODAS las opciones aunque el fichero sea
        minimo; al guardar aplica SOLO lo que difiere del default sobre el fichero crudo (lo que vuelve
        al default se elimina). No pausa al terminar: eso lo hace el llamador (setup).
    #>
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$CfgPath, [string]$CfgName = 'config.json')
    Clear-Host
    Write-CvLog 'SETUP' ("Editor de {0} (0 = volver en cada nivel)." -f $CfgName)
    $cfg    = Get-CvConfig -Root $Root -Path $CfgPath
    $before = Get-CvConfig -Root $Root -Path $CfgPath
    $script:CvEditDirty = $false
    Edit-Node -Node $cfg -Path '' -CfgName $CfgName
    if ($script:CvEditDirty) {
        if (Read-YesNo ("Guardar cambios en {0}?" -f $CfgName) $true) {
            # Aplicar SOLO lo editado sobre el fichero ACTUAL (crudo): lo que difiere del default se
            # guarda; lo que vuelve al default se elimina del fichero.
            $raw = if (Test-Path -LiteralPath $CfgPath) { Read-CvConfigFile -Path $CfgPath } else { [pscustomobject]@{} }
            Update-CvConfigEdits -Edited $cfg -Before $before -Default (Get-CvConfigDefaults) -Target $raw
            Save-CvConfigFile -Path $CfgPath -Config $raw
            Write-CvLog 'SETUP' ("[OK] - {0} actualizado (solo los valores distintos del default)." -f $CfgName)
        } else {
            Write-CvLog 'SETUP' 'Cambios descartados.'
        }
    } else {
        Write-CvLog 'SETUP' 'Sin cambios.'
    }
}

Export-ModuleMember -Function *
