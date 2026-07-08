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
│   ├── Common.psm1         Contexto, config, logging, jobs JSON, lock, consola, temporales
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
foreach ($m in 'Common','Tools','MediaInfo','Profile','Video','Audio','Subtitle','Multiplex') {
    Import-Module (Join-Path $Lib ("{0}.psm1" -f $m)) -Force
}
```

`Common` y `Tools` se llaman mutuamente (p. ej. `New-CvContext` de Common usa `New-CvToolContext` de Tools, y `Install-CvTool` de Tools usa `Write-CvLog` de Common). Como ambos se importan en la misma sesión, la resolución de comandos entre módulos funciona.

| Módulo | Responsabilidad |
|---|---|
| **Common** | `New-CvContext`, `Get-CvConfig`, `Write-CvLog`, jobs (`*-CvJob`), lock (`Enter/Exit-Lock`), temporales (`Get-CvTempPaths`, `Remove-CvTemps`), consola (`Set-CvAppearance`…), ejecución (`Invoke-ToolShow/Capture`). |
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
