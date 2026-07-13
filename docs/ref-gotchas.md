# Trampas y cosas a tener en cuenta

Recopilación de fallos **reales** que ya nos han mordido (con su corrección) y reglas para no repetirlos. Pensado como referencia de desarrollo: **antes de tocar código de estas áreas, revisa la entrada correspondiente**. Cada punto está verificado empíricamente (sesión de pruebas o `changelog.md`).

## PowerShell (tipos y números)

- **`[math]::Max`/`Min` con un entero y un decimal → trunca.** `[math]::Max(0, 0.259)` devuelve **0**: el `0` es `[int]`, PowerShell resuelve el overload `Max(int,int)` y trunca el `0.259`. Mordió en el `%` de recorte del auto-borde (letterbox: el ancho no cambia → `1-cw/iw = 0` entero → 0%; el cálculo está en el `Where-Object` de `Find-CropDetectSamples` en `Video.psm1`, con casts a `[double]`). **Regla:** si algún argumento puede ser fraccionario, usa `0.0` o castea el otro a `[double]` explícito (`[math]::Max([double]$a,[double]$b)` o `[math]::Max(0.0,$x)`). Ojo: un `[double]$x` **cast explícito** sí liga el overload double, pero un `(expr)` calculado no siempre. Auditadas todas las llamadas del repo: el único fallo activo era ese `%` de recorte; `BorderMinCropPct` y `Get-CvSafeStart` (`Context.psm1`) usaban la forma `Max(0, …)` y se **blindaron a `0.0`** (funcionaban, pero para no depender del detalle).
- **`[int]` redondea, no trunca.** `[int]0.9 = 1`. Un vídeo de 0,899 h salía como `1:xx:xx`. **Regla:** para truncar usa `[math]::Floor`. (v4.2.1)
- **Parseo de números sensible al locale.** En ES, `[double]::TryParse("5.758")` interpreta `.` como separador de miles → 5758. **Regla:** parsea con `[System.Globalization.CultureInfo]::InvariantCulture` (`ConvertTo-InvDouble` en Context) y formatea con `InvariantCulture` para los args de ffmpeg. Mordió al generar fixtures de subtítulos.
- **Interpolar un `double` en una cadena de filtro de ffmpeg usa el locale.** `"aevalsrc=0:d=$Sync:..."` con `$Sync = 0.5` en locale ES produce `d=0,5`, y ffmpeg **parte el `-filter_complex` por la coma** (`No option name near '...'`) → el filtro falla. Igual con `volume=`, `loudnorm=`, `pan=`, coeficientes, etc. **Regla:** formatea SIEMPRE con `([double]$x).ToString([CultureInfo]::InvariantCulture)` (o `Format-CvNumber`) antes de meterlo en una cadena de filtro. Mordió en el silencio de sincronía WAV clásico (`Invoke-AudioRun`); lo cazó `feature-tests.ps1`.
- **`@(if(){ @(x) })` desenvuelve arrays de un elemento.** Un `@()` con un solo objeto puede colapsar. **Regla:** envolver con `@(...)` en el punto de uso y no asumir `.Count`.
- **`[string]$x = $null` da `''`, no `$null`.** Comprueba con truthiness (`if ($x)`), no con `-ne $null`.
- **Rutas con corchetes (`Peli [1080p].mkv`).** PowerShell trata `[ ]` como comodín en `-Path`/`Test-Path`. **Regla:** usa `-LiteralPath` siempre (todas las funciones de job lo hacen). ffmpeg/ffprobe reciben la ruta como argumento y no globbing, así que ahí no hay problema — pero si el fichero **no existe** (p. ej. renombrado a mitad), ffprobe da salida vacía y `Get-MediaInfo` devuelve `$null`.

## ffmpeg / códecs

- **`scale=W:-1` puede dar altura IMPAR.** `-1` mantiene el aspecto pero no redondea a par; 4:2:0 exige dimensiones pares → **libx264/libx265 abortan** (`height not divisible by 2`); NVENC lo tolera (redondea) pero es frágil. **Regla:** usa `-2` (auto y par). Peor aún combinado con recorte de bordes (cambia el alto).
- **Vídeo anamórfico: el ancho ALMACENADO no es el que se ve.** Con **SAR ≠ 1:1** (píxeles no cuadrados) el ancho mostrado = `ancho_almacenado × SAR`. Ejemplo real: `1920x1072` con `SAR 115:87` se **muestra** a ~`2538px` (DAR `4600:1943`). **Consecuencias:** (a) `ffplay` abre la ventana al tamaño **mostrado** (se sale de la pantalla — es correcto, así se ve el vídeo); (b) comparar `maxWidth` contra el ancho almacenado **no detecta** que el vídeo es más ancho de lo que parece. **Regla:** para decisiones de tamaño usa el **ancho mostrado** (`Get-CvDisplayWidth`). Como `scale` **conserva el DAR** (no el SAR: al escalar recalcula el SAR de salida), para capar el ancho mostrado a `MaxWidth` basta escalar el almacenamiento a `MaxWidth/SAR` (`Get-CvMaxWidthResize`); así se mantiene el aspecto del original sin deformarlo. El tratamiento —conservar el SAR (`keep`) o **cuadrar a píxeles cuadrados** (`square`/`squareheight`, `scale=W:H,setsar=1`)— es configurable con `encode.anamorphic` y se centraliza en `Get-CvResize`. **Ojo:** quitar el SAR SIN rescalar (`setsar=1` dejando las mismas dimensiones) **deforma** la imagen; hay que hornear la proporción en píxeles (`scale` a las dimensiones cuadradas correctas + `setsar=1`). Explicación completa (síntomas, modos y verificación): [explica-anamorfico.md](explica-anamorfico.md).
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
- **`adelay` cuantiza a milisegundos ENTEROS.** La sincronía por defecto (`encode.syncAdelay`) usa `adelay=<ms>:all=1` con `<ms> = [int][math]::Round($Sync*1000)`, mientras que el método clásico (WAV `aevalsrc`, `encode.syncAdelay: false`) usa segundos exactos → pueden diferir hasta ~0,5 ms. Inaudible para A/V (tolerancia ~decenas de ms), pero es la única discrepancia sistemática entre ambos métodos.

## Consola / rendering (fuentes y foco)

- **No todas las fuentes tienen la cruz Dingbats `✗` (U+2717).** Cascadia Code (la fuente por defecto) pinta el check `✓` (U+2713) pero la cruz U+2717 sale como cuadro/tofu. **Regla:** para la marca de error se usa **`×` (U+00D7)**, del bloque Latin-1, presente en cualquier fuente que ya dibuje el check (`Get-CvMark`). No asumir que un glifo Unicode "bonito" existe en conhost.
- **`SetForegroundWindow` falla en silencio por el _foreground lock_ de Windows.** Si el proceso que llama no es el de primer plano, el SO no cambia el foco (la ventana solo parpadea en la barra). Mordió al traer la preview de ffplay al frente. **Regla:** enganchar la cola de entrada del hilo de la ventana de primer plano actual con **`AttachThreadInput`** antes del `SetForegroundWindow` (y desengancharla después); es el método fiable (`CvWin::ToForeground` en `Exec.psm1`).

## Verificación (obligatorio antes de dar algo por bueno)

- **Lint** de todos los `.ps1`/`.psm1` con `[System.Management.Automation.Language.Parser]::ParseFile` (18 ficheros).
- **Batería**: `test/run-tests.ps1 -Encoder hevc_nvenc` (15 fixtures, root aislado, NVENC real). Debe dar 15/15.
- **Menús interactivos**: alimentar stdin con `printf '...' | powershell -File ...` (`Read-CvLine` cae a `Read-Host` con stdin redirigido). Alimentar muchos prompts seguidos por pipe es frágil (se desincroniza) → probar cada menú por separado.
- **`Get-MediaInfo` devuelve `$null`** si ffprobe falla o el fichero no existe; quien lo llama debe comprobarlo (un `$null` se propaga a datos erróneos / reescaneo del archivo anterior).
- **Datos contrastados, no inventar.** Probar en la GPU/ffmpeg reales y medir; no afirmar tiempos, límites o compatibilidades de memoria.
