# Referencia de `config.json`

Se carga al arrancar (`Get-CvConfig`) y se **fusiona en profundidad** con unos valores por defecto: puedes tener un `config.json` parcial y se completan las claves que falten, sin romper al añadir opciones nuevas.

La forma cómoda de editarlo es `setup.cmd` → **Editar configuración** (ver [herramientas.md](herramientas.md)), que conserva tipos, arrays y formato.

## Estructura

```json
{
  "downloads": { "ffmpeg": {...}, "aacgain": {...} },
  "languages": { "audio": [...], "subtitle": [...] },
  "encode":    { "outputExtension": "mkv", "threads": 0, "fps": "23.976", "audioHz": 44100 },
  "border":    { "start": 120, "duration": 120 },
  "volume":    { "method": "peak", "loudnorm": { "I": -16, "TP": -1.5, "LRA": 11 } },
  "behavior":  { "cleanTemps": true, "separateWindow": true, "lockCloseButton": true, "debug": false },
  "console":   { "background": "DarkBlue", "foreground": "Yellow", "font": "Consolas", "fontSize": 18, "windowWidth": 150, "windowHeight": 40 },
  "paths":     { "original": "", "proceso": "", "convertido": "", "logs": "" }
}
```

## `downloads` — catálogo de herramientas

Una entrada por app. Ver el sistema completo en [herramientas.md](herramientas.md).

| Clave | Ejemplo | Significado |
|---|---|---|
| `selected` | `"7.1.1"` | Versión por defecto (la que usa PREPARAR y se congela en el job). |
| `type` | `"zip"` / `"file"` | El paquete es un zip a extraer o un ejecutable directo. |
| `url` | `".../{version}/..."` | URL de descarga; `{version}` se sustituye. |
| `binPath` | `"ffmpeg-{version}-full_build/bin"` | Carpeta dentro del zip donde están los exe. |
| `files` | `["ffmpeg.exe","ffprobe.exe","ffplay.exe"]` | Ejecutables a copiar. |
| `platform` | `"x86_64"` | Plataforma del binario (`x86`/`x64`/`x86_64`, se normaliza). |
| `versionExe` / `versionArgs` / `versionRegex` | `"ffmpeg.exe"` / `["-version"]` / `"ffmpeg version (\\d+...)"` | Cómo leer la versión instalada. |
| `versions` | `{ "7.1.1": "<sha256>" }` | Versiones disponibles y su SHA256. |

## `languages`

| Clave | Ejemplo | Uso |
|---|---|---|
| `audio` | `["es"]` | Idiomas preferidos de audio. |
| `subtitle` | `["spa","es","castellano",...]` | Idiomas preferidos de subtítulos. |

Se normalizan variantes: `es`, `es-ES`, `es_es`, `spa`, `castellano`, `spanish` cuentan como el mismo idioma (`Test-CvLanguage`).

## `encode`

| Clave | Ejemplo | Uso |
|---|---|---|
| `outputExtension` | `"mkv"` | Extensión de la salida. |
| `threads` | `0` | `-threads` (0 = auto). |
| `fps` | `"23.976"` | `-r` en la codificación de vídeo. |
| `audioHz` | `44100` | Samplerate de audio por defecto. |

## `border`

| Clave | Ejemplo | Uso |
|---|---|---|
| `start` | `120` | Segundo donde empieza el muestreo de `cropdetect`. |
| `duration` | `120` | Duración (s) del muestreo. |

## `volume`

| Clave | Valores | Uso |
|---|---|---|
| `method` | `peak` / `loudnorm` / `aacgain` | Método de normalización (ver "Audio" en [comandos.md](comandos.md)). |
| `loudnorm.I` | ej. `-16` | Integrated loudness (LUFS) — solo `loudnorm`. |
| `loudnorm.TP` | ej. `-1.5` | True peak (dBTP). |
| `loudnorm.LRA` | ej. `11` | Loudness range (LU). |

## `behavior`

| Clave | Def. | Uso | Marcador equivalente |
|---|---|---|---|
| `cleanTemps` | `true` | Borra temporales al terminar cada archivo. | `keep_temp` (los conserva) |
| `separateWindow` | `true` | Codifica en ventana aparte minimizada. | `same_window` (todo en la principal) |
| `lockCloseButton` | `true` | Desactiva el botón X durante el proceso. | — |
| `debug` | `false` | Muestra y confirma cada comando; codifica en la principal. | `debug_on` |
| `log` | `true` | Guarda un transcript de la ejecución en `logs\` (un fichero por ventana: fecha + PID). | `no_log` (lo desactiva) |

Los marcadores son ficheros vacíos en la raíz del proyecto que fuerzan el comportamiento sin editar el JSON.

## `console`

| Clave | Ejemplo | Uso |
|---|---|---|
| `background` / `foreground` | `"DarkBlue"` / `"Yellow"` | Colores (nombres de `ConsoleColor`). |
| `font` | `"Consolas"` | Fuente de la consola (`SetCurrentConsoleFontEx`). |
| `fontSize` | `18` | Tamaño de fuente. |
| `windowWidth` / `windowHeight` | `150` / `40` | Tamaño de la ventana (con buffer alto para scroll). |

## `paths` — carpetas de trabajo

Permite ubicar las carpetas fuera de la carpeta del programa. Cada valor admite **ruta absoluta** (`E:\Media\Original`, `\\servidor\share\in`) o **relativa** al programa; **vacío** = por defecto junto al programa. La carpeta se crea sola si no existe.

| Clave | Vacío (por defecto) | Uso |
|---|---|---|
| `original` | `<programa>\Original` | Vídeos de entrada. |
| `proceso` | `<programa>\Proceso` | Jobs, lock y temporales. |
| `convertido` | `<programa>\Convertido` | Salida. |
| `logs` | `<programa>\logs` | Transcript de las ejecuciones. |

> La carpeta `tools\` (binarios) no es configurable: siempre va junto al programa.
