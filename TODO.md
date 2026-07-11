# TODO (versión PowerShell)

## Validar la sincronía BETA `adelay` con un archivo real (🧪 beta → estable)

**Estado:** 🧪 SE MANTIENE EN BETA. Validado (11/07/2026) con un vídeo real (vídeo A; pista spa eac3 6ch, desfase real **0,005 s**): beta ≡ clásico a nivel de muestra. PERO ese desfase es muy pequeño (≈media muestra de redondeo), así que **antes de promocionar se quiere repetir con un archivo de MAYOR desfase** para confirmar que la cuantización de `adelay` a ms enteros no introduce nada apreciable frente al clásico (que usa segundos exactos). Buscar un archivo con `start_time`/pts de audio grande (p. ej. decenas o cientos de ms) y repetir la medición PCM de abajo.

**Resultado (ffmpeg 7.1.1, medido a nivel PCM s16le 44,1 kHz, aislando el silencio inicial):**
- beta (`adelay=5:all=1`): **220** muestras insertadas = **4,989 ms**.
- clásico (`aevalsrc d=0.005 + concat`): **221** muestras = **5,011 ms**.
- diferencia: **1 muestra = 0,023 ms** (5 ms = 220,5 muestras; uno redondea a 220 y el otro a 221). Inaudible.
- **Matiz sistemático:** `adelay` solo acepta **ms enteros** (`[int][math]::Round(Sync*1000)`), mientras que el clásico usa segundos exactos en `aevalsrc` → para retardos con fracción de ms pueden diferir hasta ~0,5 ms. Irrelevante para sincronía A/V (tolerancia ~decenas de ms), pero es la única discrepancia real. Si algún día se quisiera precisión sub-ms, `adelay` admite `delays` en muestras con `adelay=...S` o se mide en ms con más cifras.

**Contexto original (por qué estaba bloqueado):** faltaba un archivo con desfase real (`start_time`/pts del audio > 0); ahora sí lo hay.

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

## Validar/afinar el downmix `dialogue` con voz reforzada (🧪 beta → estable)

**Estado:** 🧪 BETA. `encode.downmixMode = "dialogue"` baja 5.1 → estéreo con un filtro `pan` que sube el central (diálogos) y baja los surrounds. **Doble llave:** solo refuerza la voz si además `test.betaDownmix = true`; si no, `dialogue` cae al downmix estándar. El worker marca el modo reforzado con `[beta]`. Al promocionar, quitar el flag `test.betaDownmix` y el `[beta]`.

**Qué falta:** los coeficientes son **provisionales** — `pan=stereo|c0=0.5*c2+0.35*c0+0.15*c4|c1=0.5*c2+0.35*c1+0.15*c5` (central 0,5 · frontal 0,35 · surround 0,15; LFE descartado). Validar de oído y con medidas sobre **varios tipos de mezcla** (cine de acción, diálogo, música) que:

1. Los diálogos destacan sin que el resto quede demasiado bajo (no "karaoke").
2. No hay recorte: los coeficientes suman 1,0 por canal, así que el pico no debería superar al del origen; confirmarlo con `volumedetect` (pico downmix ≤ pico 5.1) en material con surrounds fuertes.
3. Comparar contra el downmix `default` de ffmpeg en los mismos clips.

**Ya hecho:** los coeficientes son **configurables** en `encode.downmixCoeffs` (`center`/`front`/`surround`), así que afinarlos no requiere tocar código.

**Decisión:** si los coeficientes por defecto convencen → promocionar (quitar el flag `test.betaDownmix` y el `[beta]`); si no, ajustar los defaults.

**Archivos:** `lib/Audio.psm1` (`$panDown`), `lib/Config.psm1`/`lib/Context.psm1` (`downmixCoeffs`), `docs/explica-audio.md`.

---

## Audio multipista (conservar varias pistas del idioma preferido) — 🧪 beta → estable

**Estado:** 🧪 IMPLEMENTADO en **v4.4.0 como BETA** (doble llave `encode.multiAudio` + `test.betaMultiAudio`). Con 2+ pistas del idioma preferido se conservan varias y se elige la predeterminada; menú `Select-AudioMulti` (prompt único, `*`=default, preview), un temporal por pista `<name>_aN.*`, multiplex con la predeterminada primero (`-disposition:a:0 default`), idioma + título por pista (para distinguir mismas-idioma); modo `copy` también conserva el set. Job `audio.tracks[]` (compat con `audio.index` antiguo). Verificado E2E sobre fixture 2 pistas spa + tests unitarios + batería 15/15.

**Qué falta para promocionar:**
1. **Validar con archivos reales** variados (varias pistas del mismo idioma: principal + comentarios; mezclas de canales distintos 5.1/2.0) que la selección/orden/default y los títulos salen correctos en reproductores reales (VLC, Plex, TV).
2. Revisar la **sincronía por pista** con material que tenga desfases distintos por pista.
3. Confirmar el comportamiento en **copy** (varias pistas copiadas) en un contenedor real grande.

**Decisión:** si convence → promocionar (quitar `test.betaMultiAudio` y las marcas `[beta]`; dejar `encode.multiAudio` como toggle). Posible mejora futura: extender a **varios idiomas** (hoy solo lista las del idioma preferido).

**Archivos:** `lib/MediaInfo.psm1` (`Select-CvDefaultAudio`), `lib/Audio.psm1` (`Select-AudioMulti`, `Invoke-AudioAsk`/`Invoke-AudioRun -Pos`), `lib/Job.psm1` (`Get-CvJobAudioTracks`/`Get-CvAudioTempPath`), `lib/Multiplex.psm1` (mapeo N pistas), `Convert.ps1` (worker), `docs/explica-audio.md`.

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
