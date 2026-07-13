# TODO (versión PowerShell)

## ✅ Sincronía `adelay` — PROMOCIONADA (13/07/2026)

**Estado:** ✅ VALIDADA y promocionada. El silencio de sincronía con `adelay=<ms>:all=1` en **una sola pasada** (encadenado con el volumen) es ahora el **método por defecto**: `encode.syncAdelay = true` (antes la beta `test.syncAdelay`). Se conservan **los dos modos**: `true` (adelay, por defecto) y `false` (clásico WAV). Comprobado a nivel PCM (11/07: 220 vs 221 muestras para 5 ms, diff 0,023 ms, inaudible) y en uso real. Único matiz: `adelay` cuantiza a ms enteros (documentado en `docs/ref-gotchas.md`). Config `encode.syncAdelay` → `Context.SyncAdelay` → rama en `Invoke-AudioRun`.

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

## ✅ Audio multipista (conservar varias pistas del idioma preferido) — PROMOCIONADA (13/07/2026)

**Estado:** ✅ VALIDADA y promocionada. Se retira la doble llave: la multipista la gobierna solo el toggle **`encode.multiAudio`** (por defecto `true`); eliminado el flag beta `test.betaMultiAudio` y las marcas `[beta]`. Con 2+ pistas del idioma preferido se conservan varias y se elige la predeterminada (menú `Select-AudioMulti`, un temporal por pista `<name>_aN.*`, multiplex con la predeterminada primero, idioma + título por pista; `copy` también conserva el set). Verificado E2E + tests unitarios + batería. **Mejora futura opcional:** extender a **varios idiomas** (hoy solo lista las del idioma preferido).

---

## Probar AV1 por GPU `av1_nvenc` en hardware compatible (`[SIN PROBAR]`)

**Estado:** ⚠️ SIN PROBAR (ya NO es beta). El codec **AV1** llegó en v4.5.0 con dos encoders: `libsvtav1` (CPU, **validado**) y `av1_nvenc` (GPU). Se retiró el flag beta `test.betaAv1` (y `Get-CvBetaEncoders`/`Context.BetaAv1`): `av1_nvenc` **aparece siempre** en el menú `ENCODER DE VIDEO`, etiquetado **`[SIN PROBAR]`**, porque no se ha podido validar — requiere **NVIDIA RTX 40+/Ada** y la GPU de pruebas (GTX 1070) no lo soporta (`No capable devices found`). En esa GPU, la validación por GPU (`Test-CvGpuEncoder`) además lo marca `[NO SOPORTADO]` y lo salta.

**Qué falta:**
1. En una GPU **RTX 40+ (Ada o superior)** con driver reciente: crear un perfil con `av1_nvenc` y **codificar un archivo real** (8 y 10 bits, con y sin tone-mapping HDR→SDR), confirmando salida `av1` correcta y reproducible.
2. Revisar el control de tasa por GPU (`-qmin/-qmax`/multipass) y el `-pix_fmt` (`p010le` en `main10`).
3. Contrastar calidad/velocidad frente a `libsvtav1` (CPU) y `hevc_nvenc`.

**Decisión:** si va bien → quitar la etiqueta `[SIN PROBAR]` de su fila en `Get-CvVideoEncoders`. La validación por GPU (`Test-CvGpuEncoder`) seguirá protegiendo a quien no tenga hardware compatible.

**Archivos:** `lib/Profile.psm1` (`Get-CvVideoEncoders`, `Get-CvCodecOptions`, `Get-VideoArgs` rama `av1_nvenc`), `lib/Tools.psm1` (validación GPU), `docs/ref-perfiles.md`.

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
