# Referencia de `config.json`

Se carga al arrancar (`Get-CvConfig`) y se **fusiona en profundidad** con los valores por defecto (`Get-CvConfigDefaults`, la fuente única): puedes tener un `config.json` parcial y se completan las claves que falten, sin romper al añadir opciones nuevas.

Por eso el `config.json` distribuido es **mínimo**: solo lleva lo que se **sobrescribe** respecto a los defaults (p. ej. la versión de ffmpeg, el idioma de audio o el tamaño de ventana). Todo lo demás —incluido el catálogo completo de `downloads` (`ffmpeg`, `aacgain`, `sevenzip`, `mkvtoolnix`) y la sección `postprocess`— sale de los defaults. Un `config.json` vacío (`{}`) también es válido.

La forma cómoda de editarlo es `setup.cmd` → **Editar configuración** (ver [herramientas.md](herramientas.md)), que carga el config **fusionado** (así ves y editas TODAS las opciones aunque el fichero sea mínimo) pero al guardar aplica **solo los valores que cambiaste** sobre el `config.json` actual, sin reescribir el resto: un fichero mínimo sigue mínimo (+ lo editado) y uno completo sigue completo. Para (re)generar un `config.json` **completo** con todos los valores por defecto, usa **Restablecer config.json**.

## Estructura

Esquema completo (tras la fusión con los defaults):

```json
{
  "downloads":   { "ffmpeg": {...}, "aacgain": {...}, "sevenzip": {...}, "mkvtoolnix": {...} },
  "languages":   { "audio": [...], "subtitle": [...] },
  "encode":      { "outputExtension": "mkv", "threads": 0, "fps": "23.976", "audioHz": 44100 },
  "border":      { "start": 120, "duration": 120 },
  "preview":     { "start": 120, "seconds": 30 },
  "volume":      { "method": "peak", "loudnorm": { "I": -16, "TP": -1.5, "LRA": 11 } },
  "postprocess": { "stripTags": true, "mkvpropedit": "", "attachments": { "keep": false, "fonts": true, "covers": false, "other": false } },
  "behavior":    { "cleanTemps": true, "separateWindow": true, "lockCloseButton": true, "debug": false, "log": true, "workers": 2, "retries": 2 },
  "console":     { "background": "DarkBlue", "foreground": "Yellow", "font": "Cascadia Code", "fontSize": 18, "windowWidth": 150, "windowHeight": 40 },
  "paths":       { "original": "", "proceso": "", "convertido": "", "logs": "" },
  "profiles":    [ { "label": "...", "videoEncoder": "...", "crf": 18, ... } ]
}
```

## `downloads` — catálogo de herramientas

Una entrada por app. Ver el sistema completo en [herramientas.md](herramientas.md).

| Clave | Ejemplo | Significado |
|---|---|---|
| `selected` | `"7.1.1"` | Versión por defecto (la que usa PREPARAR y se congela en el job). |
| `type` | `"zip"` / `"7z"` / `"file"` | Paquete zip (se extrae), `.7z` (se extrae con `7zr`) o ejecutable directo. |
| `url` | `".../{version}/..."` | URL de descarga; `{version}` se sustituye. |
| `binPath` | `"ffmpeg-{version}-full_build/bin"` | Carpeta dentro del zip donde están los exe. |
| `files` | `["ffmpeg.exe","ffprobe.exe","ffplay.exe"]` | Ejecutables a copiar. |
| `platform` | `"x86_64"` | Plataforma del binario (`x86`/`x64`/`x86_64`, se normaliza). |
| `versionExe` / `versionArgs` / `versionRegex` | `"ffmpeg.exe"` / `["-version"]` / `"ffmpeg version (\\d+...)"` | Cómo leer la versión instalada. |
| `versions` | `{ "7.1.1": "<sha256>" }` | Versiones disponibles y su SHA256. |
| `dependsOn` | `["sevenzip"]` | (Opcional) Otras apps del catálogo que se aseguran **antes** de instalar esta. P. ej. `mkvtoolnix` necesita `sevenzip` (7zr) para extraer su `.7z`. |

## `languages`

| Clave | Ejemplo | Uso |
|---|---|---|
| `audio` | `["es"]` | Idiomas preferidos de audio. |
| `subtitle` | `["spa","es","castellano",...]` | Idiomas preferidos de subtítulos. |

Se **canonicalizan** las variantes (`Get-CvLangCanon`): `es`, `es-ES`, `es_es`, `spa`, `esp`, `castellano`, `spanish` cuentan como el mismo idioma, así que **basta un código** en la lista para reconocer cualquier variante (p. ej. `["es"]` ya reconoce una pista etiquetada `spa`). Lo mismo para `en`/`fr`/`de`/`it`/`pt`/`ja`/`zh`/`ko`/`ru`/`ca`/`gl`/`eu`. La comparación la hace `Test-CvLanguage`.

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
| `start` | `120` | Segundo donde empieza el muestreo de `cropdetect` (primer punto). Si el vídeo es más corto, se ajusta solo a ~10% de su duración. |
| `duration` | `120` | Presupuesto **total** (s) de escaneo; se reparte entre los `samples` puntos. |
| `samples` | `3` | Nº de puntos repartidos del vídeo donde se escanean bordes (`1` = solo al inicio, clásico). Con 2+, si los puntos discrepan se avisa y se ofrece un menú de recortes ordenado por votos. |

## `preview`

Reproducción con ffplay en PREPARAR (previews de **pista de audio**, **pista de vídeo** y **bordes**). Independiente de `border` (que es el análisis de `cropdetect`).

| Clave | Def. | Uso |
|---|---|---|
| `start` | `120` | Segundo donde **empieza** la muestra (para saltar intros/negros). Si el vídeo es **más corto**, el inicio se ajusta solo a ~10% de su duración (no se queda fuera). |
| `seconds` | `30` | **Duración** (s) de la muestra; luego se cierra sola (o antes con ESC/Q). |

> En los menús de selección de pista (audio/vídeo) se puede indicar un **segundo de inicio puntual** sin tocar el config: `P N <seg>` (p. ej. `A 2 300` reproduce la pista 2 solo-audio desde el segundo 300) — útil para buscar diálogo cuando en el punto por defecto no hay voces.

## `volume`

| Clave | Valores | Uso |
|---|---|---|
| `method` | `peak` / `loudnorm` / `aacgain` | Método de normalización (ver "Audio" en [comandos.md](comandos.md)). |
| `loudnorm.I` | ej. `-16` | Integrated loudness (LUFS) — solo `loudnorm`. |
| `loudnorm.TP` | ej. `-1.5` | True peak (dBTP). |
| `loudnorm.LRA` | ej. `11` | Loudness range (LU). |

## `postprocess`

Limpieza del MKV final tras multiplexar (ver "Tag DURATION y limpieza con mkvpropedit" en [comandos.md](comandos.md)).

| Clave | Def. | Uso |
|---|---|---|
| `stripTags` | `true` | Ejecuta `mkvpropedit <out> --tags all:` para quitar las etiquetas `DURATION` por pista que añade el muxer de ffmpeg (conservando Cues, duración y dispositions). |
| `mkvpropedit` | `""` | Ruta a `mkvpropedit.exe`. **Vacío** = usar la versión descargada en `tools\mkvtoolnix\<ver>\<plataforma>` (se auto-descarga la 1ª vez). Se puede fijar una ruta propia para usar otra instalación. |
| `attachments.keep` | `false` | Interruptor maestro: conservar adjuntos del original (fuentes, carátulas…). Por defecto **no** se conserva ninguno. |
| `attachments.fonts` | `true` | Si `keep`, permite las **fuentes** (`.ttf`/`.otf`, `font/*`) — útiles para subtítulos ASS/SSA. |
| `attachments.covers` | `false` | Si `keep`, permite las **carátulas/imágenes** (`image/*`, `cover*`…). |
| `attachments.other` | `false` | Si `keep`, permite el **resto** de adjuntos. |

## `behavior`

| Clave | Def. | Uso | Marcador equivalente |
|---|---|---|---|
| `cleanTemps` | `true` | Borra temporales al terminar cada archivo. | `keep_temp` (los conserva) |
| `separateWindow` | `true` | Codifica en ventana aparte minimizada **sin robar el foco** (`SW_SHOWMINNOACTIVE`). | `same_window` (todo en la principal) |
| `lockCloseButton` | `true` | Desactiva el botón X durante el proceso. | — |
| `debug` | `false` | Muestra y confirma cada comando; codifica en la principal. | `debug_on` |
| `log` | `true` | Guarda un transcript de la ejecución en `logs\` (un fichero por ventana: fecha + PID). | `no_log` (lo desactiva) |
| `workers` | `2` | Nº de workers en paralelo propuesto al terminar PREPARAR (esta ventana + N−1 nuevas). Es el valor por defecto del prompt; se puede cambiar en el momento (**0** = solo preparar y salir, sin codificar). | — |
| `retries` | `2` | Reintentos por archivo si su codificación falla, antes de abandonarlo. (Distinto de `workers`.) | — |
| `asciiMarks` | `false` | Usa marcas ASCII (`[OK]`/`[ERROR]`) y corchetes `[ ]` en los avisos, en vez de los símbolos `✓`/`✗` y el badge `▐ … ▌`. Útil si la consola/fuente no tiene esos glifos (se verían como cuadros). | — |

Los marcadores son ficheros vacíos en la raíz del proyecto que fuerzan el comportamiento sin editar el JSON.

## `console`

| Clave | Ejemplo | Uso |
|---|---|---|
| `background` / `foreground` | `"DarkBlue"` / `"Yellow"` | Colores (nombres de `ConsoleColor`). |
| `font` | `"Cascadia Code"` | Fuente de la consola (`SetCurrentConsoleFontEx`). Por defecto `Cascadia Code`; si el equipo no la tiene, conhost hace fallback a su fuente (puedes poner `Consolas`, que viene en todo Windows). |
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

## `profiles` — perfiles de codificación propios

Array **opcional** de perfiles que se **añaden** a los 7 de serie en el menú *USAR PERFIL* (numerados desde el **8**); no los sustituyen. Cada objeto usa los campos de un perfil en `camelCase`, todos opcionales:

```json
"profiles": [
  { "label": "Anime 1080p", "videoEncoder": "libx265", "crf": 18, "changeSize": "1920:-1" },
  { "videoEncoder": "hevc_nvenc", "videoProfile": "main10", "videoLevel": "5", "qmin": 1, "qmax": 20, "detectBorder": true }
]
```

| Clave | Ejemplo | Uso |
|---|---|---|
| `label` | `"Anime 1080p"` | Texto del menú. Si se omite, se genera un resumen automático. |
| `videoEncoder` | `"libx265"` | `copy` / `hevc_nvenc` / `libx265` / `h264_nvenc` / `libx264`. |
| `videoProfile` / `videoLevel` | `"main10"` / `"5"` | `-profile:v` / `-level:v`. |
| `qmin` / `qmax` | `1` / `20` | NVENC. Ausentes = calidad automática. |
| `crf` | `18` | CPU (libx264/libx265). |
| `detectBorder` | `true` | Detección de bordes por archivo. |
| `changeSize` | `"1920:-1"` | `scale=` (altura `-1` = auto). |
| `audioEncoder` / `audioBitrate` / `audioHz` | `"aac_coder"` / `"192k"` / `44100` | Audio. |

Se editan **a mano** en el JSON (el editor navegable de `setup` los muestra pero remite a este documento, para no corromper el array de objetos). Ver [perfiles.md](perfiles.md).

## Fichero de config alternativo (`-Config`)

`Convert.cmd` y `setup.cmd` aceptan `-Config <ruta>` para usar/editar **otro** fichero de configuración en vez de `config.json` (ruta absoluta o relativa al directorio actual). Útil para mantener varios juegos de ajustes/perfiles:

```bat
Convert.cmd -Config perfiles\anime.json
setup.cmd   -Config perfiles\anime.json
```

Las ventanas de worker extra heredan el mismo `-Config`. Si la ruta no existe, se avisa y se usan los valores por defecto.
