# Perfiles de codificación

En la fase PREPARAR se elige **un** perfil que se aplica a todo el lote y se **congela** dentro de cada `.job.json`. Definidos en `lib\Profile.psm1`.

## Perfiles predefinidos

Menú (`Select-Profile`):

| # | Audio | Vídeo | Detección bordes | Resize |
|---|---|---|---|---|
| **1** | 192k AAC | `copy` (no recodifica vídeo) | — | — |
| **2** | 192k AAC | hevc_nvenc, main10, L5, Q 1–23 | no | no |
| **3** | 192k AAC | hevc_nvenc, main10, L5, Q 1–23 | **sí** | no |
| **4** | 192k AAC | hevc_nvenc, main10, L5, Q auto | no | no |
| **5** | 192k AAC | hevc_nvenc, main10, L5, Q auto | **sí** | no |
| **6** | 192k AAC | hevc_nvenc, main10, L5, Q 1–23 | no | **1920:-1** |
| **7** | 192k AAC | h264_nvenc, L5, Q 1–23 | no | no |
| **0** | — | **Custom** (interactivo) | — | — |

- "Q 1–23" = `-qmin 1 -qmax 23`. "Q auto" = sin `qmin`/`qmax` (el encoder decide).
- Todos usan encoder NVENC (GPU) salvo el 1 (copy). Para CPU (libx264/libx265), usar el custom.

## Campos de un perfil

`New-CvProfile` define la estructura (valores por defecto entre paréntesis):

| Campo | Valores | Uso |
|---|---|---|
| `VideoEncoder` | `copy` / `hevc_nvenc` / `libx265` / `h264_nvenc` / `libx264` | Codec de vídeo. |
| `VideoProfile` | `main10` / `main` / `''` | `-profile:v`. `main10` → `-pix_fmt p010le`. |
| `VideoLevel` | ej. `5`, `4.1`, `''` | `-level:v`. |
| `Qmin`, `Qmax` | 0–51 / `null` | NVENC: `-qmin`/`-qmax`. Si `Qmin == Qmax` → `-rc constqp -qp`. |
| `Crf` | 0–51 / `null` | CPU (libx264/libx265): `-crf`. |
| `DetectBorder` | `true`/`false` | Activa la detección de bordes por archivo. |
| `ChangeSize` | ej. `1920:-1`, `''` | `scale=` (altura `-1` = automático manteniendo aspecto). |
| `AudioEncoder` | `aac_coder` / `copy` | Recodifica a AAC o copia la pista. |
| `AudioBitrate` | ej. `192k` | `-b:a`. |
| `AudioHz` | ej. `44100` | `-ar`. |

Cómo se traducen estos campos a argumentos de ffmpeg: ver "Vídeo: codificación" en [comandos.md](comandos.md).

## Perfil custom (`New-CustomProfile`)

Construcción interactiva:

1. **Encoder de vídeo**: libx264 / h264_nvenc / libx265 / hevc_nvenc / copy.
2. Si no es `copy`:
   - ¿Detectar bordes en cada archivo? (s/N)
   - ¿Cambiar el tamaño? → menú de tamaños de referencia (360p…4K) o valor libre (`W:H`, altura `-1` = auto).
   - **Perfil** y **Level** del codec (selectores; opciones distintas para H.264 vs H.265).
   - **Control de tasa**: CRF (CPU) o QMIN/QMAX (NVENC).
3. **Bitrate de audio**: copy / 128k / 160k / 192k / 256k / 320k / custom.

## Preguntas por archivo en PREPARAR

Aunque el perfil es común al lote, en PREPARAR se pregunta/detecta por archivo:

- **Bordes** (si el perfil los activa o el nombre empieza por `_`): scan + preview del original y del recorte; opciones: usar / re-detectar (otro tramo) / valor manual / sin recorte.
- **Animación** (solo `libx264`/`libx265`): añade `-tune animation`.
- **Audio**: si hay 2+ pistas del idioma preferido, menú para elegir; detección de sincronía (silencio a añadir).
- **Subtítulos**: selección por idioma (completo + forzados).
