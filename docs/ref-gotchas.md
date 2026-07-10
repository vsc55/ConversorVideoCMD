# Trampas y cosas a tener en cuenta

Recopilación de fallos **reales** que ya nos han mordido (con su corrección) y reglas para no repetirlos. Pensado como referencia de desarrollo: **antes de tocar código de estas áreas, revisa la entrada correspondiente**. Cada punto está verificado empíricamente (sesión de pruebas o `changelog.md`).

## PowerShell (tipos y números)

- **`[math]::Max`/`Min` con un entero y un decimal → trunca.** `[math]::Max(0, 0.259)` devuelve **0**: el `0` es `[int]`, PowerShell resuelve el overload `Max(int,int)` y trunca el `0.259`. Mordió en el `%` de recorte del auto-borde (letterbox: el ancho no cambia → `1-cw/iw = 0` entero → 0%; ver `redPct` en `Video.psm1`). **Regla:** si algún argumento puede ser fraccionario, usa `0.0` o castea el otro a `[double]` explícito (`[math]::Max([double]$a,[double]$b)` o `[math]::Max(0.0,$x)`). Ojo: un `[double]$x` **cast explícito** sí liga el overload double, pero un `(expr)` calculado no siempre. Auditadas todas las llamadas del repo: el único fallo activo era `redPct`; `BorderMinCropPct` y `Get-CvSafeStart` (`Context.psm1`) usaban la forma `Max(0, …)` y se **blindaron a `0.0`** (funcionaban, pero para no depender del detalle).
- **`[int]` redondea, no trunca.** `[int]0.9 = 1`. Un vídeo de 0,899 h salía como `1:xx:xx`. **Regla:** para truncar usa `[math]::Floor`. (v4.2.1)
- **Parseo de números sensible al locale.** En ES, `[double]::TryParse("5.758")` interpreta `.` como separador de miles → 5758. **Regla:** parsea con `[System.Globalization.CultureInfo]::InvariantCulture` (`ConvertTo-InvDouble` en Context) y formatea con `InvariantCulture` para los args de ffmpeg. Mordió al generar fixtures de subtítulos.
- **`@(if(){ @(x) })` desenvuelve arrays de un elemento.** Un `@()` con un solo objeto puede colapsar. **Regla:** envolver con `@(...)` en el punto de uso y no asumir `.Count`.
- **`[string]$x = $null` da `''`, no `$null`.** Comprueba con truthiness (`if ($x)`), no con `-ne $null`.
- **Rutas con corchetes (`Peli [1080p].mkv`).** PowerShell trata `[ ]` como comodín en `-Path`/`Test-Path`. **Regla:** usa `-LiteralPath` siempre (todas las funciones de job lo hacen). ffmpeg/ffprobe reciben la ruta como argumento y no globbing, así que ahí no hay problema — pero si el fichero **no existe** (p. ej. renombrado a mitad), ffprobe da salida vacía y `Get-MediaInfo` devuelve `$null`.

## ffmpeg / códecs

- **`scale=W:-1` puede dar altura IMPAR.** `-1` mantiene el aspecto pero no redondea a par; 4:2:0 exige dimensiones pares → **libx264/libx265 abortan** (`height not divisible by 2`); NVENC lo tolera (redondea) pero es frágil. **Regla:** usa `-2` (auto y par). Peor aún combinado con recorte de bordes (cambia el alto).
- **Contenedor intermedio de audio.** `.m4a` (MP4) solo admite **aac/ac3/alac**; **eac3, mp3, flac, opus fallan**. **Regla:** AAC → `.m4a` (compatible con `aacgain`); el resto → `.mka` (Matroska, admite todo).
- **Opus** solo admite 8/12/16/24/**48** kHz → se fuerza `-ar 48000` (44,1 kHz falla). **FLAC** es sin pérdida → no se pasa `-b:a`. **`-aac_coder twoloop`** es exclusivo del AAC nativo.
- **`-movflags +faststart` es solo mov/mp4** → no-op en matroska (se ignora en silencio).
- **HDR mostrado como SDR se ve "lavado".** Fuentes con `color_transfer` = `smpte2084` (PQ) o `arib-std-b67` (HLG) recodificadas sin convertir el color salen grises/planas en SDR. **Regla:** tone-map a BT.709 con **`libplacebo`** (GPU/Vulkan). `zscale`+`tonemap` (zimg) **crashea** (`Illegal instruction`) en el build de ffmpeg incluido. Ver [explica-tonemap-hdr.md](explica-tonemap-hdr.md).
- **`cropdetect` de un solo punto es poco fiable.** Una escena oscura da un recorte disparatado (p. ej. `1440:1088`). **Regla:** escanear en varios puntos y **votar** (`Find-CropDetectSamples`). Además cropdetect casi siempre quita unos píxeles de borde aunque no haya barras (`3824` sobre `3832` = 0,2%) → aplica una **tolerancia** (`border.minCropPct`) antes de considerarlo barra real.

## NVENC / GPU

- **La GTX 1070 (GP104) tiene UN solo motor NVENC**, no dos "cores". El medidor "GPU %" del Administrador de tareas no es el del encoder (mira la gráfica **"Codificación de vídeo"**). Una sola sesión NVENC no satura el motor (~50%); **dos sesiones en paralelo lo llevan a ~100%**. ffmpeg no tiene opción de "usar los dos": el paralelismo es a nivel de proceso (workers). En consumer Pascal el tope práctico son **2 sesiones**.
- **`-b_ref_mode middle` no está soportado** en algunas GPU (la del proyecto: "B frames as references are not supported") → descartado. Verificar en la GPU real antes de añadir flags NVENC.
- **`-multipass qres/fullres`** es el 2-pass **de NVENC** (GPU), no de CPU; una sola invocación de ffmpeg.
- **Recodificar 4K HDR es lento** (decode + seek), aunque NVENC vaya sobrado: el cuello es la decodificación/filtro/memoria, no el encoder.

## Volumen / audio

- **`loudnorm` es ~4,5× más lento que `peak`** (medido: ~63 s vs ~14 s sobre 5 min). No asumir que "una pasada" = rápido.
- **`aacgain` solo procesa AAC/MP3 en MP4** (`.m4a`). Con otro códec de salida (`.mka`) no aplica → se usa `peak`.

## Verificación (obligatorio antes de dar algo por bueno)

- **Lint** de todos los `.ps1`/`.psm1` con `[System.Management.Automation.Language.Parser]::ParseFile` (18 ficheros).
- **Batería**: `test/run-tests.ps1 -Encoder hevc_nvenc` (15 fixtures, root aislado, NVENC real). Debe dar 15/15.
- **Menús interactivos**: alimentar stdin con `printf '...' | powershell -File ...` (`Read-CvLine` cae a `Read-Host` con stdin redirigido). Alimentar muchos prompts seguidos por pipe es frágil (se desincroniza) → probar cada menú por separado.
- **`Get-MediaInfo` devuelve `$null`** si ffprobe falla o el fichero no existe; quien lo llama debe comprobarlo (un `$null` se propaga a datos erróneos / reescaneo del archivo anterior).
- **Datos contrastados, no inventar.** Probar en la GPU/ffmpeg reales y medir; no afirmar tiempos, límites o compatibilidades de memoria.
