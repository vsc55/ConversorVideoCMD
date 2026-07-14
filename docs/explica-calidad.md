# Control de calidad de la salida (SSIM vs VMAF)

Tras recodificar, el conversor puede **medir cuánta calidad se perdió** comparando el vídeo de salida
con el original. Se activa con `encode.video.qualityCheck` en `config.json`:

| Valor | Qué hace |
|---|---|
| `off` | **(por defecto)** No mide. |
| `ssim` | Mide con SSIM. Siempre disponible (no necesita nada extra). |
| `vmaf` | Mide con VMAF. Requiere que el ffmpeg tenga `libvmaf` (los builds de BtbN lo traen). |

> **Por qué viene desactivado:** decodifica los **dos vídeos enteros**, así que en una peli larga **tarda** — SSIM ~5-9× tiempo real (una peli de 95 min ≈ 10-19 min extra) y **VMAF muchísimo más** (~0,06× → puede tardar **horas**). Actívalo puntualmente para comparar perfiles/ajustes, no de continuo.

Es una **pasada extra** de ffmpeg que **decodifica los dos vídeos** (salida y origen) y los compara
frame a frame, así que **añade tiempo** al final de cada archivo (fuera del tiempo de conversión que
sale en el resumen). No se mide en modo `copy` (no hay recodificación, no hay pérdida que medir). El
resultado se registra en el log del worker como una línea `[QC]`; si no se puede medir (p. ej. `vmaf`
sin `libvmaf`), se **avisa y se continúa** (no falla la conversión).

## La diferencia entre SSIM y VMAF

Las dos miden "cuánto se parece la salida al original", pero de forma muy distinta:

### SSIM — *Structural Similarity Index*

- **Qué es:** una fórmula **matemática** clásica que compara la **estructura** de la imagen
  (luminancia, contraste y patrones locales) entre cada par de frames.
- **Escala:** **0 a 1** (1 = idéntico al original). En la práctica: `>0.98` muy bueno, `0.95-0.98`
  bueno, `<0.95` empiezan a notarse pérdidas.
- **Ventajas:** **rápida**, determinista, **siempre disponible** (no necesita modelos ni librerías
  extra), buena para detectar degradación estructural (bloques, desenfoque).
- **Límite:** **no** se corresponde del todo con lo que **percibe el ojo humano**. Un SSIM alto puede
  verse peor de lo que sugiere el número (y viceversa): ignora cómo el cerebro pondera el movimiento,
  las zonas de atención, el banding, etc.

### VMAF — *Video Multi-Method Assessment Fusion* (de Netflix)

- **Qué es:** un **modelo de aprendizaje automático** entrenado con **opiniones de personas reales**
  puntuando vídeos. Combina varias métricas y predice la **calidad percibida** por un espectador.
- **Escala:** **0 a 100**. Interpretación habitual: **≈95-100** indistinguible del original, **80-95**
  bueno (artefactos leves), **60-80** se notan, **<60** mala.
- **Ventajas:** **mucho más fiel a la percepción humana** — es el estándar de la industria para decidir
  bitrates/calidad de streaming.
- **Límite:** **más lento** que SSIM y **requiere `libvmaf`** en el build de ffmpeg (si no está, el
  conversor avisa y sigue). El modelo por defecto está calibrado para contenido tipo "TV/streaming".

### Cuál usar

- **`ssim`** (por defecto): comprobación **rápida y siempre disponible**; suficiente para detectar si un
  perfil está degradando de más.
- **`vmaf`**: cuando quieras una medida **fiel a cómo lo verá una persona** (comparar perfiles, ajustar
  CRF/QP con criterio perceptual), y tu ffmpeg soporte `libvmaf`.

> Ambas comparan **la salida tal cual quedó** (con su resize/crop/tone-mapping/cambio de fps) contra el
> **origen**: la referencia se **escala al tamaño de la salida** y la alineación temporal la resuelve el
> propio *framesync* de la métrica. Si el perfil hizo **tone-mapping HDR→SDR** o **recorte**, la
> puntuación reflejará también ese cambio de contenido (es esperable: la salida **es** distinta), no
> solo la pérdida por compresión.

## Detalles técnicos

- Filtro (fuente única `Get-CvQualityLavfi`, `lib/Video.psm1`):
  `[0:v]format=yuv420p[d0];[1:v]format=yuv420p[r0];[r0][d0]scale2ref[ref][dist];[dist][ref]<ssim|libvmaf>`
  (input 0 = salida, input 1 = origen). **No** usa el filtro `fps` a propósito: la métrica alinea por
  timestamp, y `fps` + 2 inputs dispara una aserción en ffmpeg 7.1.
- La puntuación se extrae con `Get-CvQualityScore` (`All:` en SSIM, `VMAF score:` en VMAF).
- Lo ejecuta el worker con `Measure-CvQuality` tras un multiplexado con éxito; es **fail-soft** (si algo
  va mal devuelve `null` y el worker solo anota que no se pudo medir).
- Muestra **progreso en vivo** (barra + `%` + ETA + velocidad) vía `Invoke-ToolProgress` — como decodifica
  los dos vídeos enteros conviene ver que avanza. La salida va a `NUL` (no a `stdout`) para no chocar con
  `-progress pipe:1`; la puntuación la imprime el filtro por `stderr`, que queda en `$global:CvLastToolError`.
