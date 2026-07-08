# Arquitectura

## Estructura de ficheros

```
ConversorVideoCMD/
├── Convert.cmd                 Lanzador del conversor (ExecutionPolicy Bypass + UTF-8)
├── setup.cmd               Lanzador de la utilidad de gestión
├── Convert.ps1        Orquestador: clasificar / preparar / worker
├── setup.ps1               Utilidad: herramientas + editor de config + limpieza
├── config.json             Toda la configuración (se carga al arrancar)
├── lib/
│   ├── Log.psm1            Log de consola (Write-CvLog) y transcript a logs\
│   ├── Config.psm1         Valores por defecto de config.json + carga/fusión/reset
│   ├── Context.psm1        Contexto de ejecución ($ctx) + helpers (idiomas, números)
│   ├── Console.psm1        Apariencia de consola, ventana nativa, menús y prompts
│   ├── Exec.psm1           Ejecución de procesos externos (ffmpeg/ffprobe…)
│   ├── Job.psm1            Cola: jobs JSON, lock atómico, temporales, ruta de salida
│   ├── Tools.psm1          Apps/versiones/descargas (ffmpeg, aacgain)
│   ├── MediaInfo.psm1      ffprobe (JSON), selección de pista, resumen
│   ├── Profile.psm1        Perfiles de codificación + menú
│   ├── Video.psm1          Detección de bordes, preview, args y codificación de vídeo
│   ├── Audio.psm1          Selección de pista, sincronía, volumen y codificación de audio
│   ├── Subtitle.psm1       Selección de subtítulos por idioma
│   └── Multiplex.psm1      Unión final de pistas a MKV
├── Original/               Entrada: vídeos a convertir
├── Proceso/                Trabajo: .job.json, .lock y temporales (.mkv/.m4a/.wav)
├── Convertido/             Salida: <nombre>_fix.mkv
├── tools/<app>/<ver>/<plat>/   Ejecutables (ffmpeg/ffprobe/ffplay, aacgain)
├── logs/                   Transcript de cada ejecución (fecha + PID)
└── docs/                   Esta documentación
```

Las carpetas de trabajo (`Original`, `Proceso`, `Convertido`, `tools`) se crean automáticamente si faltan.

## Módulos (`lib\`)

Todos son módulos de PowerShell 5.1 (`.psm1`) que exportan sus funciones (`Export-ModuleMember -Function *`). `Convert.ps1` los importa en orden:

```powershell
$modules = @('Log','Config','Context','Console','Exec','Job','Tools','MediaInfo','Profile','Video','Audio','Subtitle','Multiplex')
foreach ($m in $modules) {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}
```

(`setup.ps1` usa el mismo patrón con un subconjunto: `@('Log','Config','Context','Console','Exec','Tools')`.)

Los módulos se llaman entre sí (p. ej. `New-CvContext` de Context usa `Get-CvConfig` de Config y `New-CvToolContext` de Tools; `Install-CvTool` de Tools usa `Write-CvLog` de Log, `Invoke-ToolCapture` de Exec y `Select-FromList` de Console). Como todos se importan en la misma sesión, la resolución de comandos entre módulos funciona.

| Módulo | Responsabilidad |
|---|---|
| **Log** | `Write-CvLog` (log de consola; resalta `[ERR]` en rojo y `[AVISO]`/`[NO SOPORTADO]` en amarillo), `Start-CvLog`/`Stop-CvLog` (transcript a `logs\`), `Get-CvLogFiles`/`Remove-CvLogFiles`. |
| **Config** | `Get-CvConfigDefaults` (fuente única de defaults), `Get-CvConfig` (carga + fusión), `Reset-CvConfig`, serialización (`ConvertTo-CvJson`, `Read/Save-CvConfigFile`). |
| **Context** | `New-CvContext` (`$ctx`), `Get-CvWorkDirs`, `Test-CvLanguage`, `ConvertTo-InvDouble`. |
| **Console** | Apariencia (`Set-CvAppearance`…), ventana nativa (`Set-CvCloseButton`, `Initialize-CvNative`), menús (`Show-Menu`, `Select-FromList`), prompts (`Read-*`). |
| **Exec** | `Invoke-ToolCapture`, `Invoke-ToolShow`, `ConvertTo-ArgString`, `Write-CvDebug`. |
| **Job** | Jobs (`*-CvJob`), lock (`Enter/Exit-Lock`), temporales (`Get-CvTempPaths`, `Remove-CvTemps`), salida (`Get-OutputPath`). |
| **Tools** | Descargas y versiones: `Install-CvTool`, `Confirm-CvTool`, `Select-CvToolVersion`, `Get-CvToolDir`, `Test-CvToolInstalled`, `Get-CvInstalledVersions`, `Test-CvToolSupported`, `New-CvToolContext`, `Test-CvTools`. |
| **MediaInfo** | `Get-MediaInfo` (ffprobe JSON), `Select-AudioStream`, `Get-VideoStream`, `Write-ConversionSummary`. |
| **Profile** | `Get-CvProfiles`, `Select-Profile`, `New-CustomProfile`. |
| **Video** | `Find-CropDetect`, `Show-Preview`, `Invoke-VideoAsk`, `Get-VideoArgs`, `Invoke-VideoRun`. |
| **Audio** | `Invoke-AudioAsk`, `Get-AudioInitDelay`, `Get-MaxVolume`, `Invoke-AudioRun`. |
| **Subtitle** | `Select-Subtitles`. |
| **Multiplex** | `Invoke-Multiplex`. |

## El contexto (`$ctx`)

`New-CvContext -Root <dir>` lee `config.json` y devuelve un `[pscustomobject]` que se pasa a casi todas las funciones. Campos principales:

| Campo | Origen | Uso |
|---|---|---|
| `Root`, `Original`, `Proceso`, `Convertido`, `Tools`, `Logs` | rutas | Carpetas de trabajo. |
| `Log` | `config.behavior.log` | Si se genera el transcript en `logs\`. |
| `FFmpeg`, `FFprobe`, `FFplay`, `AacGain` | `New-CvToolContext` | Rutas a los ejecutables de la versión en uso. |
| `FFmpegVersion`, `AacGainVersion`, `Platform` | `downloads.*.selected` | Versiones y plataforma. |
| `Downloads` | `config.downloads` | Catálogo de apps/versiones. |
| `VolumeMethod`, `LoudnormI/TP/LRA` | `config.volume` | Normalización de volumen. |
| `Threads`, `Fps`, `DefaultAudioHz`, `OutExt` | `config.encode` | Parámetros de codificación. |
| `BorderStart`, `BorderDur` | `config.border` | Muestreo de detección de bordes. |
| `AudioLangs`, `SubLangs` | `config.languages` | Idiomas preferidos. |
| `Debug`, `CleanTemps`, `SeparateWindow`, `LockClose` | `config.behavior` + marcadores | Comportamiento. |
| `Console*`, `Window*` | `config.console` | Apariencia. |
| `Extensions` | fijo | `*.avi *.flv *.mp4 *.mov *.mkv`. |

En el **worker**, cada job se ejecuta con un contexto clonado (`New-CvToolContext`) que apunta las herramientas a la versión congelada en ese job — ver [jobs.md](jobs.md).

## Fuentes únicas de verdad

Para evitar duplicación, ciertos datos viven en una sola función:

| Concepto | Función |
|---|---|
| Carpetas de trabajo | `Get-CvWorkDirs` |
| Descriptor de una app del catálogo | `Get-CvAppDescriptor` |
| Rutas y nombres de los ejecutables | `New-CvToolContext` |
| Carpeta `tools\<app>\<ver>\<plat>` | `Get-CvToolDir` |
| Plataforma normalizada del binario | `Get-CvAppPlatform` |
| Rutas de los ficheros temporales | `Get-CvTempPaths` |

## Marcadores (ficheros vacíos en la raíz)

Activan comportamientos sin editar `config.json`:

| Fichero | Efecto |
|---|---|
| `debug_on` | Modo debug (muestra y confirma cada comando). |
| `keep_temp` | No borra los temporales de `Proceso`. |
| `same_window` | Codifica en la ventana principal (no en ventana aparte). |
| `no_log` | No genera el transcript en `logs\`. |
