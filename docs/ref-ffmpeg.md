# Referencia de opciones ffmpeg/ffprobe/ffplay usadas

Glosario de **todas** las opciones, filtros y flags de ffmpeg/ffprobe/ffplay que usa el conversor: qué hace cada una (según la **doc oficial** incluida en `tools\ffmpeg\doc`) y **cómo la usamos** nosotros. Para ver los comandos completos montados, ver [ref-comandos.md](ref-comandos.md).

> **Fuentes.** Descripciones tomadas de `ffmpeg-filters.html`, `ffmpeg-codecs.html`, `ffmpeg-formats.html`, `ffmpeg.html`, `ffprobe.html`, `ffplay.html` (build local). **Aviso:** los encoders **NVENC** (`hevc_nvenc`/`h264_nvenc`) **no** están documentados en esa copia local; sus opciones van marcadas *(probado)* = descrito por comportamiento verificado en la GPU real (no citado de la doc). Verificaciones concretas en [ref-gotchas.md](ref-gotchas.md).

## Opciones generales de ffmpeg

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-hide_banner` | Suprime el banner (copyright, build, versiones de librerías). | En todas las llamadas. |
| `-y` | Sobrescribe la salida sin preguntar. | En todas las de escritura. |
| `-loglevel [flags+]nivel` / `-v` | Nivel de log: `quiet`(-8) nada, `error`(16) errores, `info`(32, def), … | `-loglevel error` en las previews; `-v quiet`/`-v error` en ffprobe. |
| `-nostats` | Desactiva la línea de progreso/estadísticas periódica en `stderr`. | En el modo progreso inline (`Invoke-ToolProgress`), para no ensuciar el `stderr` que se captura. |
| `-progress <url>` | Escribe el progreso **legible por máquina** (bloques `clave=valor`: `out_time_us`, `speed`, `bitrate`, `stream_0_0_q`, `progress=continue\|end`, …) a esa URL. | `-progress pipe:1` (a `stdout`): se parsea para pintar `% + ETA + velocidad + bitrate` (y `q` en vídeo) en la consola (`behavior.progress`). |
| `-threads N` | Nº de hilos del codec (AVOption `threads`); `0`/`auto` = automático. | `-threads <encode.threads>` (0 = todos los núcleos). |
| `-f fmt` | Fuerza el formato de contenedor de entrada/salida. | `-f matroska` (mux/audio intermedio), `-f null` (análisis: cropdetect/volumedetect). |
| `-i <fichero>` | Fichero de entrada. | La fuente. |
| `-map <spec>` | Crea streams en la salida a partir de un input/filtergraph. `-` delante = mapeo negativo (desactiva); `?` al final = opcional; usar `-map` desactiva la selección automática. | `-map 0:<index>` (pista de vídeo/audio elegida por índice absoluto), `-map [a]`/`-map [v]` (salida de filtro). |
| `-an` / `-vn` / `-sn` | Desactivan grabación/mapeo automático de audio / vídeo / subtítulos. | `-an -sn` al codificar solo vídeo; `-vn -sn` al codificar solo audio. |
| `-c[:stream] <codec\|copy>` | Elige encoder (o decoder). `copy` = no recodifica (remux). Gana la última `-c` que coincida. | `-c:v`, `-c:a`, `-c:s copy`, `-c:t copy` (adjuntos), `-c:v copy`/`-c:a copy` en el multiplex. |
| `-ss <pos>` | **Antes de `-i`**: busca en la entrada (no exacto; con `-accurate_seek` —por defecto al transcodificar— decodifica y descarta el sobrante). **Después**: descarta al decodificar hasta `pos`. | `-ss` antes de `-i` en cropdetect (seek rápido) y en previews **solo si** `preview.start` > 0 (o `P N <seg>`). |
| `-t <dur>` | Limita la duración leída (input) o escrita (output). Excluyente con `-to`, y `-t` tiene prioridad. | `-t` para el **modo pruebas** (recorte a N s) y en previews **solo si** `preview.seconds` > 0 (por defecto `0` = sin límite, sin `-t`). |
| `-to <pos>` | Corta la lectura/escritura en `pos`. Excluyente con `-t`. | En el escaneo de bordes (`Find-CropDetect`: `-ss X -to Y`). |
| `-r[:v] <fps>` | Fija el fps. Output: duplica/descarta frames antes de codificar (fps constante). | `-r <encode.video.fps>` solo si `encode.video.forceFps` está activo. |
| `-pix_fmt <fmt>` | Formato de píxel de salida (`-pix_fmts` lista los soportados). Prefijo `+` = error si no se puede. | 10/8 bits según el perfil y el encoder (matriz en [ref-comandos.md](ref-comandos.md) §8); **debe casar** con `-profile:v` o el encoder descarta el perfil. |
| `-metadata[:spec] k=v` | Fija un metadato (global o de stream/capítulo). Valor vacío = borrarlo. Anula lo de `-map_metadata`. | `-metadata title=` (vacía el título), `-metadata:s:v language=und`, `-metadata:s:a language=<lang>`. |
| `-map_metadata <idx>` | Copia metadatos del input `idx`. **`-map_metadata -1` = mapeo ficticio que desactiva la copia automática.** | En el multiplex, `-map_metadata -1` limpia los metadatos heredados; `-map_metadata:s:a:0 0:s:a:0` restaura los del audio en modo copy. |
| `-map_chapters <idx>` | Copia los capítulos del input `idx`; índice negativo los desactiva. | `-map_chapters -1` en el intermedio de vídeo; `-map_chapters <origen>` en el multiplex (conservar capítulos). |
| `-disposition[:stream] v` | Fija la disposición del stream (`+forced`, `+default`, `0`…). Por defecto la copia del input. | Marcar subtítulos (`forced`/`default`) y limpiar la de las pistas recodificadas. |
| `-fflags +bitexact` (formato) / `-bitexact` | Escribe solo datos independientes de plataforma/build/tiempo (checksums reproducibles); pensado para tests. | En el multiplex, evita que ffmpeg escriba su etiqueta `ENCODER` global. |
| `-movflags +faststart` (formato) | Mueve el índice (`moov`) al principio del MP4/MOV para reproducción/streaming progresivo. | Se añade en las ramas de codificación; **no-op en Matroska** (nuestro contenedor final), inofensivo. |
| `-init_hw_device vulkan` | Inicializa un dispositivo hardware (aquí Vulkan; admite índice o subcadena del nombre). | Necesario para el filtro `libplacebo` (tone-mapping HDR→SDR en GPU). |

## Vídeo: codificación

### NVENC (GPU) — *(probado; no en la doc local)*

| Opción | Qué hace | Cómo la usamos |
|---|---|---|
| `-c:v hevc_nvenc` / `h264_nvenc` | Encoder H.265/H.264 por hardware NVIDIA (NVENC). | Perfiles GPU. |
| `-preset slow` | Preset con nombre de mayor calidad del NVENC. *(probado)* | Fijo en las ramas NVENC. |
| `-tier high` | Tier alto de HEVC. *(probado)* | `hevc_nvenc`. |
| `-profile:v main\|main10` | Perfil del códec (`main10` = 10 bits). *(probado)* | `main10` por defecto (con `-pix_fmt p010le`). |
| `-level:v <n>` | Nivel del códec. *(probado)* | Del perfil. |
| `-rc constqp` + `-qp <n>` | Control de tasa por **QP constante**. *(probado)* | Cuando `qmin == qmax` (calidad fija). |
| `-qmin <n>` / `-qmax <n>` | Límites del cuantizador. *(probado)* | Control de tasa NVENC por rango. |
| `-rc-lookahead:v 32` | Frames de *lookahead* del control de tasa. *(probado)* | Fijo (mejora la asignación de bits). |
| `-multipass qres\|fullres` | 2-pass de NVENC: `qres` = 1ª pasada a ¼ de resolución; `fullres` = a resolución completa. *(probado: ambos funcionan)* | Opción `encode.video.multipass`/perfil. `-b_ref_mode middle` **NO** se usa (no soportado en la GTX 1070). |

### CPU (doc oficial: libx264 / libx265)

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-c:v libx264` / `libx265` | Encoders H.264/H.265 por software (x264/x265). | Perfiles CPU / custom. |
| `-crf <n>` | Calidad para el modo de **calidad constante** (CRF). | Control de tasa en CPU. Escala 0–51; ver [explica-control-tasa.md](explica-control-tasa.md). |
| `-preset <p>` | Preset de codificación (compromiso velocidad/compresión). | `slow`. |
| `-tune <t>` | Ajuste fino de los parámetros de codificación. *(la doc no enumera los valores)* | `-tune animation` para animación. |
| `-refs <n>` | Nº de fotogramas de referencia por frame P (x264 0–16 / x265 1–16). | `-refs 4`. |

## Vídeo: filtros (`-vf` / `-filter_complex`)

| Filtro | Qué hace (doc) | Cómo lo usamos |
|---|---|---|
| `crop=w:h:x:y` | Recorta a las dimensiones dadas; `x`/`y` por defecto centran (`(in-out)/2`). | Quitar barras negras (recorte detectado/elegido). |
| `scale=w:h` | Redimensiona (libswscale). `0` = usa la dimensión de entrada; **`-1`** mantiene el aspecto **sin** restricción de divisibilidad; **`-2`** además fuerza divisible por 2. | Reescalado (`changeSize`/`maxWidth`); usamos `-2` (4:2:0 exige dimensiones pares). |
| `cropdetect` | Auto-detecta el recorte de la zona no-negra e imprime los parámetros. `limit` (umbral de negro, **def 24**), `round` (divisor de las dimensiones, **def 16**; el offset se centra solo), `skip` (frames iniciales omitidos, **def 2**), `reset` (**def 0** = nunca reinicia, devuelve la mayor área). | Detección de bordes multipunto (`Find-CropDetectSamples`). |
| `libplacebo` | Filtro GPU (librería libplacebo); por defecto preserva colorimetría/tamaño y aplica metadatos Dolby Vision. `w`/`h` (def `iw`/`ih`), `tonemapping` (def `auto`; p. ej. `bt.2390`), `colorspace`/`color_primaries`/`color_trc`/`range` (def `auto`; otro valor fuerza conversión). | Tone-mapping **HDR→SDR** (BT.2020/PQ → BT.709) en GPU. |
| `format=pix_fmts` | Convierte a uno de los formatos de píxel indicados (lista con `\|`). | Fijar `p010le`/`yuv420p` tras el tonemap. |

## Audio: codificación

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-c:a aac` | Encoder AAC nativo de ffmpeg. | Códec de audio por defecto. |
| `-aac_coder <m>` | Método del encoder AAC: **`twoloop`** (def, *Two Loop Searching*, mayor calidad), `fast` (cuantizador constante, más rápido a bitrate alto), `anmr` (experimental, no recomendado). | `-aac_coder twoloop` (solo con AAC). |
| `-c:a ac3` / `eac3` / `libmp3lame` / `flac` / `libopus` / `copy` | Otros códecs de salida (Dolby Digital, DD+, MP3, FLAC, Opus) o copiar sin recodificar. | Códec configurable por perfil (`audioCodec`). Ver [explica-audio.md](explica-audio.md). |
| `-b:a <r>` / `b` | Bitrate de audio en bit/s (AAC nativo por defecto 128k; la opción genérica `b` por defecto 200k). | `-b:a <audioBitrate>` (se omite en FLAC, sin pérdida). |
| `-ac <n>` | Nº de canales de audio (output: por defecto el del input). | `-ac <encode.audio.channels>` (downmix/upmix). |
| `-ar <hz>` | Frecuencia de muestreo (output: por defecto la del input). | `-ar <audioHz>`; Opus se fuerza a 48000. |

## Audio: filtros

| Filtro | Qué hace (doc) | Cómo lo usamos |
|---|---|---|
| `pan=stereo\|c0=…\|c1=…` | Remezcla canales con coeficientes explícitos (por nombre o por índice `c0..cN`); cada canal de salida = suma ponderada de los de entrada. | Downmix 5.1→estéreo con **voz reforzada** (`downmixMode: dialogue`): sube el central, baja surrounds. |
| `volume=<expr>dB:precision=fixed` | `salida = volume × entrada` (recorta al máximo). `precision=fixed` = punto fijo de 8 bits (limita la entrada a U8/S16/S32). | Aplicar la ganancia calculada (método `peak`). |
| `volumedetect` | Sin parámetros; al final imprime `mean_volume` (RMS) y `max_volume` (por muestra), en dB relativos al PCM máximo. | Medir el pico (`max_volume`) para la normalización `peak`. |
| `loudnorm=I=..:TP=..:LRA=..` | Normalización de sonoridad **EBU R128**. `I` (integrated, def -24, rango -70..-5), `LRA` (rango de sonoridad, def 7, 1..50), `TP` (true peak máx, def -2, -9..0). Simple o doble pasada. | Método de volumen `loudnorm` (una pasada). |
| `adelay=<ms>:all=1` | Retrasa canales de audio rellenando con silencio; `delays` en **milisegundos** (sufijo `s` = segundos, `S` = muestras). `all=1` aplica el último retardo a **todos** los canales. | Sincronía en una pasada (por defecto, `encode.audio.syncAdelay`): prepende el silencio inicial. |
| `aformat=channel_layouts=<cl>` | Restringe el formato de salida (channel layouts / sample fmts / rates); el framework negocia para minimizar conversiones. | Fijar el layout en la ruta de sincronía por WAV. |
| `aevalsrc=0:d=<s>:sample_rate=<hz>:channel_layout=<cl>` | Genera audio por expresión (aquí `0` = silencio). `d`/`duration` (duración), `sample_rate` (def 44100), `channel_layout`. | Generar el **silencio inicial** (sincronía clásica por WAV). |
| `concat=n=2:v=0:a=1` | Concatena segmentos de audio/vídeo (todos empiezan en 0). `n` segmentos (def 2), `v` streams de vídeo (def 1), `a` de audio (def 0). | Unir `silencio + pista` en la sincronía clásica. |

## Color / HDR (etiquetas de salida)

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-color_primaries <e>` | Primarias de color (enum: `bt709`, `bt2020`, …). | Etiquetar la salida SDR (`bt709`) tras el tonemap. |
| `-color_trc <e>` | Curva de transferencia (enum: `bt709`, `smpte2084` (PQ), `arib-std-b67` (HLG), …). | Detección HDR (leemos `color_transfer`) y etiqueta de salida (`bt709`). |
| `-colorspace <e>` | Espacio de color / coeficientes de matriz (enum: `bt709`, `bt2020nc`, …). | Etiqueta de salida (`bt709`). |
| `-color_range <e>` | Rango: `tv`/`mpeg`/`limited` o `pc`/`jpeg`/`full`. | `tv` en la salida tonemapeada. |

## Análisis: ffprobe

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-v quiet` / `-v error` | Nivel de log. | `Get-MediaInfo` usa `-v quiet`; conteos, `-v error`. |
| `-print_format` / `-of <writer>` | Formato de salida: `json`; `default` (con `nk`/`nw`); `csv`/`compact` (con `p`, `s`). `nw=1` quita los `[SECTION]`; `p=0` quita el prefijo de sección. | `-print_format json` (info completa); `-of default=nw=1:nk=1` / `csv=p=0` (valores sueltos). |
| `-show_streams` | Info de cada stream (sección STREAM). | Info completa del archivo. |
| `-show_format` | Info del contenedor (sección FORMAT). | Duración, etc. |
| `-show_entries <sel>` | Lista de entradas a mostrar (`stream=…`, `format=…`, `stream_tags=…`, `frame_side_data=…`). | Consultas concretas (dimensiones, bitrate, tags, side-data). |
| `-select_streams <spec>` | Filtra a los streams indicados (`v`/`a`/`s`, `v:0`, o índice absoluto). | Seleccionar la pista concreta a analizar. |
| `-show_chapters` | Info de capítulos (sección CHAPTER). | Contar capítulos. |
| `-show_frames` + `-read_intervals %+#1` | Info por frame / subtítulo; `%+#1` = leer 1 paquete tras el seek. | Leer el *side-data* del primer frame (detección Dolby Vision/HDR10+). |
| `-count_packets` | Cuenta los paquetes por stream. *(la doc no describe el coste; nosotros medimos que **demultiplexa el fichero entero** → lento; por eso es solo respaldo)* | Respaldo para contar cues de subtítulo si falta el tag `NUMBER_OF_FRAMES`. Ver [caso-rendimiento-subtitulos.md](caso-rendimiento-subtitulos.md). |

## Previsualización: ffplay

| Opción | Qué hace (doc) | Cómo la usamos |
|---|---|---|
| `-autoexit` | Sale al terminar la reproducción. | Todas las previews (por defecto reproducen todo el vídeo; se cierran al acabar o antes con `q`/ESC). |
| `-ss <pos>` / `-t <dur>` | Seek (no exacto) / duración. | Preview: `-ss` desde `preview.start` (o `P N <seg>`) solo si > 0; `-t` desde `preview.seconds` solo si > 0. Por defecto (`0`/`0`) sin `-ss` ni `-t` (todo el vídeo desde el principio). |
| `-nodisp` | Sin ventana gráfica. | Preview solo-audio (`A N`). |
| `-window_title <t>` | Título de la ventana. | Etiqueta de la preview. |
| `-vst` / `-ast` / `-sst <spec>` | Selecciona el stream de vídeo / audio / subtítulo (admite índice). | Reproducir la pista/subtítulo concreto en los menús de selección. |

---

Los comandos completos (con el orden real de los argumentos) están en [ref-comandos.md](ref-comandos.md). Detalle de mecanismos: [explica-audio.md](explica-audio.md), [explica-tonemap-hdr.md](explica-tonemap-hdr.md), [explica-control-tasa.md](explica-control-tasa.md), [explica-deteccion-bordes.md](explica-deteccion-bordes.md). Errores a evitar: [ref-gotchas.md](ref-gotchas.md).
