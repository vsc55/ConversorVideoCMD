# ConversorVideoCMD

Conversor/recodificador de vídeo por lotes para Windows, escrito en Batch (CMD) y VBScript, que usa **FFmpeg** como motor de conversión y **AACGain** para normalizar el volumen del audio.

*Batch video converter/re-encoder for Windows, written in Batch (CMD) and VBScript, using **FFmpeg** as conversion engine and **AACGain** for audio volume normalization.*

***

## Proceso [es]

  1. Copia el archivo original dentro de la carpeta `Original` (admite `.avi`, `.flv`, `.mp4`, `.mov` y `.mkv`).
  2. Ejecuta el script `LimpiarBorde.cmd`. Primero te preguntará la configuración de todos los archivos (fase preparar) y después empezará a codificar sin más preguntas (fase procesar).
  3. Cuando termine el proceso, podrás obtener el archivo recodificado de la carpeta `Convertido`.

### `LimpiarBorde.cmd` — modelo preparar/procesar

Versión modular (el código está en `src\`). Al arrancar decide el modo según el estado de los archivos:

- **Fase PREPARAR** (si hay algún archivo sin configurar): hace todas las preguntas y detecciones y escribe un fichero de trabajo `Proceso\<nombre>.job` con la configuración resuelta. Incluye:
  - Menú de perfiles predefinidos (H.265/H.264 por GPU NVIDIA o CPU, copy, resize...) o configuración personalizada.
  - Detección y recorte automático de bandas negras (crop), con previsualización del resultado en FFplay.
  - Corrección del desfase audio/vídeo (añade silencio inicial si el audio empieza más tarde).
- **Fase PROCESAR (worker)**: codifica los archivos preparados sin preguntar, recodifica el audio a AAC con normalización de volumen (AACGain) y multiplexa el resultado a **MKV** en `Convertido`.
- **Paralelo**: cuando todos los archivos ya tienen su `.job`, puedes abrir varias ventanas de `LimpiarBorde.cmd`; cada una entra directa como worker y se reparten los archivos mediante un bloqueo atómico (`Proceso\<nombre>.lock`, creado con `mkdir`).
- **Regla `_`**: si el nombre de un archivo empieza por `_`, se fuerza la detección de bordes aunque el perfil diga "sin bordes".

### Requisitos

- Windows de 64 bits.
- Los ejecutables necesarios (`ffmpeg`, `ffprobe`, `ffplay`, `aacgain`, `controls`) van incluidos en `tools\`; si falta alguno, el script intenta descargarlo automáticamente desde este repositorio.
- Para los perfiles NVENC hace falta una GPU NVIDIA compatible.

### Estructura de carpetas

| Carpeta      | Uso                                                          |
|--------------|--------------------------------------------------------------|
| `Original`   | Vídeos de entrada.                                           |
| `Proceso`    | Archivos temporales de trabajo.                              |
| `Convertido` | Resultado final (`*_fix.mkv`).                               |
| `src`        | Módulos del script (`process_*`, `select_*`, `fun_*`, VBS).  |
| `tools`      | Ejecutables (FFmpeg x64, AACGain, controls).                 |

### Modo debug

Crea en la raíz un archivo vacío llamado `debug_on` para activar el modo debug de `LimpiarBorde.cmd` (los archivos `_debug_on`, `_debug_stop_a` y `_debug_stop_v` del repositorio son plantillas: renómbralos sin el `_` inicial para activarlos).

***

## Process [en]

 1. Copy the original file into the `Original` folder (supports `.avi`, `.flv`, `.mp4`, `.mov` and `.mkv`).
 2. Run `LimpiarBorde.cmd`. It first asks the configuration for every file (prepare phase) and then starts encoding unattended (process phase).
 3. When the process ends, get the re-encoded file from the `Convertido` folder.

### Features

- **Prepare/process queue**: a prepare phase asks all questions and writes a `Proceso\<name>.job` config file per video; a worker phase then encodes them unattended reading each job.
- **Parallel workers**: once every file has its `.job`, you can open several `LimpiarBorde.cmd` windows; each becomes a worker and they share the workload via an atomic lock (`Proceso\<name>.lock`, created with `mkdir`).
- Predefined encoding profiles (H.265/H.264 via NVIDIA GPU or CPU, copy, resize...) or fully custom setup.
- Automatic black border detection and cropping, with FFplay preview. Files whose name starts with `_` force border detection.
- Audio re-encoding to AAC with volume normalization (AACGain) and audio/video sync fix (prepends silence when audio starts late).
- Final muxing to **MKV** into the `Convertido` folder.
- Required tools are bundled in `tools\`; missing ones are downloaded automatically from this repository.
