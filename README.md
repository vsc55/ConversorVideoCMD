# ConversorVideoCMD

Conversor/recodificador de vídeo por lotes para Windows, escrito en Batch (CMD) y VBScript, que usa **FFmpeg** como motor de conversión y **AACGain** para normalizar el volumen del audio.

*Batch video converter/re-encoder for Windows, written in Batch (CMD) and VBScript, using **FFmpeg** as conversion engine and **AACGain** for audio volume normalization.*

***

## Proceso [es]

  1. Copia el archivo original dentro de la carpeta `Original` (admite `.avi`, `.flv`, `.mp4`, `.mov` y `.mkv`).
  2. Ejecuta el script `LimpiarBorde.cmd` (o el clásico `Conversor.cmd`) y ajusta los valores de configuración que deseas.
  3. Cuando termine el proceso, podrás obtener el archivo recodificado de la carpeta `Convertido`.

> `LimpiarBorde.cmd` es la versión moderna y recomendada.

### Scripts

- **`LimpiarBorde.cmd`** — Versión modular (el código está en `src\`). Procesa por lotes todos los vídeos de `Original`:
  - Menú de perfiles predefinidos (H.265/H.264 por GPU NVIDIA o CPU, copy, resize...) o configuración personalizada.
  - Detección y recorte automático de bandas negras (crop), con posibilidad de previsualizar el resultado con FFplay.
  - Recodificación de audio a AAC con normalización de volumen (AACGain) y corrección del desfase audio/vídeo (añade silencio inicial si el audio empieza más tarde).
  - Multiplexado final a **MKV** en la carpeta `Convertido`.
  - Crea archivos de bloqueo (`*_lock.txt` en `Proceso`) para no procesar dos veces el mismo archivo.
- **`Conversor.cmd`** — Versión clásica monolítica. Menús para elegir códec (h264/h265, CPU/GPU), bitrate, resolución, relación de aspecto y FPS. Codificación en 2 pasadas con libx264/libx265 (con NVENC en una sola pasada).

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
 2. Run `LimpiarBorde.cmd` (or the classic `Conversor.cmd`) and select your settings.
 3. When the process ends, get the re-encoded file from the `Convertido` folder.

> `LimpiarBorde.cmd` is the modern, recommended version.

### Features

- Predefined encoding profiles (H.265/H.264 via NVIDIA GPU or CPU, copy, resize...) or fully custom setup.
- Automatic black border detection and cropping, with FFplay preview.
- Audio re-encoding to AAC with volume normalization (AACGain) and audio/video sync fix (prepends silence when audio starts late).
- Final muxing to **MKV** into the `Convertido` folder.
- Lock files (`*_lock.txt` in `Proceso`) prevent processing the same file twice.
- Required tools are bundled in `tools\`; missing ones are downloaded automatically from this repository.
