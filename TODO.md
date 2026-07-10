# TODO (versión PowerShell)

## Validar la sincronía BETA `adelay` con un archivo real (🧪 beta → estable)

**Estado:** pendiente — falta un archivo con desfase real (`pts_time > 0` en el audio); ahora no hay ninguno.

**Qué es:** modo beta `test.syncAdelay` que aplica el silencio de sincronía con el filtro
`adelay=<ms>:all=1` **en una sola pasada** (encadenado con la normalización de volumen), en vez
del método clásico (WAV `silencio + pista` y luego codificar). Código en `Invoke-AudioRun`
(`lib/Audio.psm1`), flag `test.syncAdelay` (`lib/Config.psm1`) → `SyncAdelay` (`lib/Context.psm1`).
Todo marcado con comentarios `BETA`; doc en `docs/explica-audio.md` §3.

**Ya verificado (con audio sintético):** códec AAC + silencio inicial correcto + volumen
normalizado, los tres a la vez, misma duración que el clásico (ffmpeg 7.1.1). **Falta:** confirmar
la **alineación A/V real** con un archivo desfasado de verdad.

**Cómo validar cuando haya archivo** (yo, al retomar):
1. Detectar el desfase: `Get-AudioInitDelay` (o `ffprobe -select_streams a:0 -show_entries stream=start_time`). Si es 0, el archivo NO sirve como caso de prueba.
2. Codificar el audio por los **dos** caminos con el mismo `-Index`/`-Sync` y perfil:
   - clásico: `test.syncAdelay=false`
   - beta: `test.syncAdelay=true`
3. Comparar las dos salidas `.m4a`: duración, `silencedetect` (silencio inicial) y el **primer instante de audio real**; idealmente coinciden al milisegundo.
4. (Opcional) Multiplexar con el vídeo en ambos modos y comprobar el arranque del audio frente al vídeo.

**Criterio de éxito:** beta ≡ clásico → **promocionar** (hacerlo el método por defecto o sacar el
flag de `test`). Si discrepa → se queda en beta y se anota qué falla.

**Prompt listo para pedírmelo:** ver `TODO.txt` (versión copiar/pegar con la ruta del archivo).

---

## Audio multipista (mantener varias pistas por idioma)

**Estado:** pendiente.

**Qué:** que `audioLanguages` del `config.json` signifique "mantener TODAS las pistas de
audio de estos idiomas" (p. ej. `["es","eng"]` → 2 pistas en el MKV final), en vez de
elegir una sola. Sería simétrico con cómo se tratan hoy los subtítulos.

**Situación actual:** el audio selecciona **una única** pista (la mejor según el orden de
`audioLanguages`, y dentro del idioma prefiere 5.1). El pipeline asume una sola pista
(un `.m4a`, un `-map`).

**Trabajo estimado (medio):**
- Selección: quedarse con todas las pistas cuyo idioma esté en la lista.
- Codificación: un temporal por pista (`<name>_aN.m4a`), cada una con su sincronía y volumen.
- Multiplex: mapear todas con su metadato de idioma y marcar una como `default`.

**Decisiones a confirmar cuando se retome:**
1. ¿Multipista (todas las de la lista) o mantener el modo "una sola por preferencia"?
2. Si hay 2+ pistas del MISMO idioma: ¿preguntar cuál (menú), mantener todas, o la mejor de cada idioma?

**Archivos que tocaría:** `lib/MediaInfo.psm1` (selección), `lib/Audio.psm1` (ASK/RUN),
`lib/Multiplex.psm1` (mapeo), `Convert.ps1` (job con lista de pistas de audio).

---

## Sistema de ejecución única (todo en un solo ffmpeg)

**Estado:** pendiente (idea validada, sin implementar).

**Qué:** fundir las tres etapas actuales (audio → vídeo → multiplexado, cada una un proceso ffmpeg
con temporales `.m4a`/`.mka` y `.mkv`) en **una sola llamada a ffmpeg** que haga a la vez: reencodar
vídeo (con `crop`/`scale`), filtrar y recodificar audio (silencio `adelay` + normalización de volumen),
copiar/mapear subtítulos con sus disposiciones, conservar capítulos y limpiar/fijar metadatos, escribiendo
directamente `Convertido\<nombre>_fix.mkv`. Ahorraría los temporales intermedios y dos arranques de ffmpeg.

**Ya verificado (empíricamente, ffmpeg 7.1.1, sin tocar el proyecto):** un único comando con
`-filter_complex "[0:v]crop,scale[v];[0:a]adelay=<ms>:all=1,loudnorm=…[a]"`, más los `-map [v] -map [a] -map 0:s:0`,
`-map_chapters 0` y `-c:v hevc_nvenc … -c:a aac -c:s copy`, produce el MKV final correcto: vídeo HEVC
recortado/escalado (10 bits), audio AAC con el silencio inicial y el volumen normalizado, subtítulo y capítulos.
Funciona con **CPU** (`libx264`) y con **GPU** (`hevc_nvenc`): el filtro de vídeo corre en CPU y NVENC codifica.

**Límite conocido (bloqueante para el one-pass total):** el método de volumen **`peak`** (mide el pico con
`volumedetect` **antes** de codificar) y **`aacgain`** (aplica la ganancia **después** del encode) obligan a
una pasada extra por diseño. La ejecución única solo es posible con volumen **`loudnorm`** (una pasada) y
sincronía **`adelay`**. La detección de bordes (`cropdetect`) no estorba: ya se resuelve en PREPARAR y el
recorte va congelado en el job.

**Decisiones a confirmar cuando se retome:**
1. ¿Convivir con el pipeline actual (nuevo modo, p. ej. solo cuando `volume=loudnorm` y sincronía `adelay`)
   o sustituirlo? Los métodos `peak`/`aacgain` seguirían necesitando el flujo por etapas.
2. Encaje con **audio multipista** (varias pistas → varias ramas de audio en el mismo `-filter_complex`).
3. Manejo de errores y reintentos: hoy cada etapa valida por separado; en one-pass un fallo tira todo el archivo.
4. Modo pruebas (`-t`), `copy` de vídeo/audio y perfiles `copy` (¿siguen por la vía actual?).

**Archivos que tocaría:** `lib/Video.psm1` + `lib/Audio.psm1` + `lib/Multiplex.psm1` (unificar la
construcción de args en un solo comando), el worker (`Convert.ps1`) y `lib/Job.psm1` (temporales).
