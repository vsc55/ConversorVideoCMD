# ConversorVideoCMD

Conversor/recodificador de vídeo por lotes para Windows, escrito en **PowerShell** (5.1), que usa **FFmpeg/FFprobe/FFplay** como motor. Diseño modular en `lib\` y toda la configuración en `config.json`.

> La versión antigua en Batch (CMD + VBScript) se conserva en la rama **`v3.x`**.

***

## Proceso

  1. Copia el archivo original dentro de la carpeta `Original` (admite `.avi`, `.flv`, `.mp4`, `.mov` y `.mkv`).
  2. Ejecuta **`run.cmd`** (doble clic). Primero te preguntará la configuración de todos los archivos (fase **preparar**) y después empezará a codificar sin más preguntas (fase **procesar**).
  3. Cuando termine, tendrás el archivo recodificado en la carpeta `Convertido` (`<nombre>_fix.mkv`).

`run.cmd` solo lanza `LimpiarBorde.ps1` con `-ExecutionPolicy Bypass` (no cambia la política del sistema) y pone la consola en UTF-8.

## Modelo preparar / procesar

Al arrancar decide el modo según el estado de los archivos:

- **Fase PREPARAR** (si hay algún archivo sin `.job` y sin convertir): hace todas las preguntas y detecciones y escribe un fichero `Proceso\<nombre>.job.json` con la configuración resuelta (perfil congelado). Incluye:
  - Menú de perfiles predefinidos (H.265/H.264 por GPU NVIDIA o CPU, copy, resize...) o configuración personalizada.
  - Detección y recorte automático de bandas negras (crop), con previsualización en FFplay.
  - Selección de pista de **audio** y **subtítulos** por idioma (listas configurables), con menú si hay varias del mismo idioma.
  - Corrección del desfase audio/vídeo (añade silencio inicial si el audio empieza más tarde).
- **Fase PROCESAR (worker)**: codifica los preparados sin preguntar, recodifica el audio a AAC con normalización de volumen y multiplexa a **MKV** en `Convertido`. Muestra un resumen al terminar cada archivo.
- **Paralelo**: cuando todos los archivos tienen su `.job`, abre varias ventanas de `run.cmd`; cada una entra como worker y se reparten los archivos mediante un bloqueo atómico (`Proceso\<nombre>.lock`, con `mkdir`).
- **Regla `_`**: si el nombre de un archivo empieza por `_`, se fuerza la detección de bordes aunque el perfil diga "sin bordes".

## Requisitos

- Windows de 64 bits con **PowerShell 5.1** (el que trae Windows).
- `ffmpeg.exe`, `ffprobe.exe` y `ffplay.exe` en `tools\x64\`. Si no están, al arrancar el script se ofrece a **descargarlos automáticamente** (build de [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg), con verificación SHA256). La versión y el hash se fijan en `config.json` (`ffmpegVersion` / `ffmpegSha256`).
- Para los perfiles NVENC hace falta una GPU NVIDIA compatible.

## Configuración (`config.json`)

Todo es editable sin tocar código: idiomas de audio y subtítulos (`audioLanguages` / `subtitleLanguages`, admiten variantes como `es`, `es-ES`, `es_es`, `spa`, `castellano`...), `fps`, `threads`, parámetros de escaneo de bordes, limpieza de temporales, ventana aparte para codificar, modo debug, y apariencia (fuente, colores y tamaño de ventana).

Marcadores rápidos (crea un archivo vacío con ese nombre en la raíz para activar): `debug_on` (modo debug), `keep_temp` (conservar temporales), `same_window` (codificar en la ventana principal).

### Normalización de volumen

El método se elige con `volumeMethod` en `config.json` (uno de tres):

| Método | Qué hace |
|--------|----------|
| `peak` (por defecto) | Mide el pico (`volumedetect`) y lo lleva a 0 dB aplicando la ganancia durante la recodificación. Simple, sin dependencias. |
| `loudnorm` | Normalización de **sonoridad** perceptual EBU R128 (filtro `loudnorm` de ffmpeg). |
| `aacgain` | Codifica sin ajuste y luego aplica la ganancia **sin recodificar** con `aacgain` (ReplayGain, como la versión batch antigua). Requiere `tools\aacgain.exe`. |

Para `loudnorm`, sus parámetros también son configurables:

```json
"volumeMethod": "loudnorm",
"loudnormI": -16,
"loudnormTP": -1.5,
"loudnormLRA": 11
```

- **I** (LUFS) = sonoridad media objetivo. `-16` para streaming/online; `-23` es el estándar de emisión EBU R128 (más bajo).
- **TP** (dBTP) = pico real máximo permitido (margen para no saturar; `-1.5` deja headroom).
- **LRA** (LU) = rango dinámico de sonoridad permitido antes de comprimir.

Se pasan a ffmpeg con punto decimal (formato invariante), independientemente del locale de Windows.

## Estructura de carpetas

| Carpeta      | Uso                                                    |
|--------------|--------------------------------------------------------|
| `Original`   | Vídeos de entrada.                                     |
| `Proceso`    | Temporales y ficheros de trabajo (`*.job.json`).       |
| `Convertido` | Resultado final (`*_fix.mkv`).                         |
| `lib`        | Módulos PowerShell (`*.psm1`).                         |
| `tools`      | Ejecutables (FFmpeg x64).                              |
