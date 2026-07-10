# CHANGELOG

## VERSION 4.2.3 - 09/07/2026
### UPDATE
  - Perfil **custom** interactivo: cada menú (encoder, perfil de codec, level, control de tasa y bitrate de audio) tiene ahora **valor por defecto** — `[ENTER]` lo acepta, o tecleas otra opción — y todos son **configurables** en la nueva sección `customProfile` de `config.json`: `videoEncoder` (`hevc_nvenc`), `videoProfile` (`main10`), `videoLevel` (`5.0`), `qmin`/`qmax` (`1`/`23`), `crf` (`21`) y `audioBitrate` (`192k`). Antes el bitrate (192k) y el control de tasa (1–23 / CRF 21) estaban **hardcodeados**. `CustomVideoEncoder`/`CustomVideoProfile`/`CustomVideoLevel`/`CustomQmin`/`CustomQmax`/`CustomCrf`/`CustomAudioBitrate` en el contexto.
  - Perfil custom: etiquetas de control de tasa más claras (`CRF (calidad 0-51)`, `QP minimo (0-51)`, `QP maximo (0-51)`) y **validación de rango**: se rechazan valores **> 51** (la escala del QP de H.264/HEVC y del CRF de x264/x265) y se vuelve a preguntar; un valor **negativo (`-1`) = "auto"** (sin `-qmin`/`-qmax` ni `-crf`, decide el encoder). Los defaults de `config.json` siguen la misma regla: `-1` = auto, el resto se acota a 0–51. (`Read-QOrNull -Max`.)
  - Menú *USAR PERFIL*: las etiquetas de los **7 perfiles de serie** ahora se **generan** de sus valores con `Format-CvProfileLabel` (la misma función que ya usaban los perfiles de `config.json`), en vez de una lista de texto hardcodeada en paralelo que había que sincronizar a mano. Fuente única → el menú siempre refleja los valores reales del perfil. (Único cambio visible: el perfil 6 muestra `RESIZE 1920:-1` en vez de `RESIZE 1080P`, que es el valor real.)
  - Perfiles de serie: `Get-CvProfiles` pasa a ser una **lista por grupos** y su número de menú se **genera automáticamente** (1..N, continuo entre grupos), igual que ya ocurría con los de `config.json` (N+1, N+2…). Añadir/quitar/reordenar un perfil de serie ya no obliga a mantener las claves a mano. Los grupos se **separan con una línea en blanco** en el menú. Además se **elimina el campo `Name`** del perfil (era dato muerto: se escribía pero no lo leía nadie); los `.job.json` nuevos ya no lo incluyen (los antiguos se siguen leyendo igual).
  - Menús del perfil custom: **todos** los que tienen valor por defecto marcan la opción con `<= por defecto` (encoder, perfil de codec, level y bitrate de audio), además del `[N]` en el prompt. `Select-FromList` marca la opción por defecto. El menú de **encoder** también se numera automáticamente (1..N desde una lista), sin claves a mano. Si `customProfile.videoEncoder` trae un encoder desconocido (errata en config), el default cae al de la app (`hevc_nvenc`), no a la primera opción. El **encoder**, el **perfil de codec** y el **level** son **obligatorios** (no ofrecen "0. ninguno": hay que elegir uno o cancelar); si el default de config no aplica, caen a la 1ª opción.
  - Menús del perfil custom con **descripción por opción**: encoder (CPU/GPU, rasgo), perfil de codec (`main10` = 10 bits, `high` = 8 bits HD…), level (hint orientativo de resolución/fps, `~1080p30`/`~4K30`…), bitrate de audio (calidad típica) y multipass (ya la tenía). Fuente: la de multipass es literal de ffmpeg; perfil/level salen del **estándar del códec** (la doc de ffmpeg no los describe: remite a "Annex A"/"x264 --fullhelp") y las de level van marcadas como **aproximadas** (`~`). Todos los catálogos del builder (`Get-CvVideoEncoders`, `Get-CvVideoSizes`, `Get-CvCodecOptions`, `Get-CvAudioBitrates`, `Get-CvNvencMultipass`) unifican el formato `@{ Value; Text }` (valor + descripción); `Select-FromList` acepta esas opciones-objeto directamente (o cadenas, como antes) y **alinea la columna de descripción** (rellena el `N. valor` a un ancho común).
  - Selección de audio con **varias pistas del idioma preferido**: ahora se **preselecciona la de mejor calidad** por más **canales** → mejor **códec** (E-AC-3 > AC-3…) → mayor **bitrate** (antes solo miraba 5.1 y cogía la primera). El menú muestra además el **bitrate** de cada pista (leído de `stream.bit_rate` o del tag `BPS` de mkvmerge), y `[ENTER]` acepta la preseleccionada (`*`). (`Select-CvBestAudio`/`Get-CvAudioBitrate`/`Get-CvAudioCodecRank` en `MediaInfo`, `Format-CvAudioLine` en `Audio`.)
  - Worker: la medición de pico del audio (método `peak`, recorre todo el audio con `volumedetect`) ya no es un silencio entre "Resolucion" y "Aplicando ganancia": se muestra como paso `- Analizando volumen... (pico -X dB) ✓`. En debug queda como log (`[OK] - Volumen analizado`).
  - Refactor del builder custom: los catálogos que estaban hardcodeados inline se extraen a funciones (fuente única, fáciles de editar): `Get-CvVideoEncoders`, `Get-CvVideoSizes` (tamaños de resize), `Get-CvCodecOptions` (perfiles/levels válidos por familia de codec) y `Get-CvAudioBitrates`. Los números de menú (encoder y bitrate) se generan de la lista; la opción "custom" del bitrate es `N+1` automática.

  - Nueva opción **`multipass`** (`off` por defecto · `qres` · `fullres`): activa el **2-pass de NVENC** (`-multipass`) en los encoders `hevc_nvenc`/`h264_nvenc` — más calidad a cambio de más tiempo de GPU. No afecta a los encoders de CPU (lo ignoran). Configurable a tres niveles: global (`encode.multipass`), **por perfil** (campo `multipass` en los de `config.json`) y en el **builder custom** (paso "2-pass NVENC", solo si el encoder es NVENC; default de `customProfile.multipass`). El valor del **perfil tiene prioridad** sobre el global. `Multipass` en perfil/contexto; `Get-VideoArgs` lo añade solo en las ramas NVENC. Verificado en GPU: `qres`/`fullres` funcionan (a diferencia de `-b_ref_mode`, no soportado y descartado).
  - Fps de salida configurable: nueva clave `encode.forceFps` (por defecto `true` = comportamiento actual, fuerza `-r <fps>`). Con `false` se **conserva el fps de cada archivo** (no se pasa `-r`), evitando el reajuste (dup/drop) de fuentes con otro fps. `ForceFps` en el contexto; `Get-VideoArgs` añade `-r` solo si está activo.
  - **Códec de audio de salida configurable** por perfil (nuevo campo `audioCodec`; antes fijo a AAC): `aac` (por defecto, comportamiento previo) · `ac3` (Dolby Digital) · `eac3` (Dolby Digital Plus) · `libmp3lame` (MP3) · `flac` (sin pérdida) · `libopus` (Opus). Se elige en el **builder custom** (el menú de audio pasa a dos pasos: **1) SALIDA DE AUDIO** = `copy` o codec, **2) BITRATE** apropiado al codec —presets de sonido envolvente hasta 640k para AC-3/E-AC-3, rango estéreo para AAC/MP3/Opus—; `copy` y FLAC se saltan el bitrate) y en los perfiles de `config.json` (`audioCodec`); el **default es configurable** en `customProfile.audioCodec`. Solo AAC lleva `-aac_coder twoloop`; **FLAC** omite `-b:a` (sin pérdida) y **Opus** se fuerza a `-ar 48000` (no admite 44,1 kHz). El intermedio de audio va en `.m4a` para AAC (compatible con la normalización `aacgain`) y en `.mka` (Matroska) para el resto, que se remultiplexa igual al MKV final; si se pide `aacgain` con un códec no-AAC se usa `peak`. `AudioCodec` en perfil/contexto (`CustomAudioCodec`); `Invoke-AudioRun` y `Invoke-Multiplex` usan el temporal según códec. Verificado E2E (ffmpeg 7.1.1): ac3/eac3/flac a 44,1 kHz y opus a 48 kHz recodifican y se multiplexan al MKV final con el códec correcto. Detalle en [explica-audio.md](docs/explica-audio.md).

### BETA
  - 🧪 **Sincronía con `adelay` en una pasada** (`test.syncAdelay`, por defecto `false`): en vez de generar un WAV `silencio + pista` y luego codificarlo (2 procesos), aplica el retardo con el filtro `adelay=<ms>:all=1` **encadenado con la normalización de volumen** en el mismo encode (1 proceso, sin temporal `_concat.wav`). El método clásico (WAV) sigue siendo el predeterminado. Marcado como BETA en config/contexto/`Invoke-AudioRun` para localizarlo al promover o retirar. Verificado (ffmpeg 7.1.1): mismo resultado que el clásico — códec AAC, silencio inicial correcto y volumen normalizado, los tres a la vez. `SyncAdelay` en el contexto. Detalle en [explica-audio.md](docs/explica-audio.md).

### REFACTOR
  - **Un solo generador de menús**: `Select-FromList` es ahora el único motor de listas. Los dos últimos menús con bucle propio (encoder y bitrate de audio) se migran a él, y se **eliminan** los helpers `Get-CvMenuLines`/`Get-CvOptionValue` (ya no los usa nadie). Para cubrir esos casos, `Select-FromList` gana tres capacidades: (1) atributo **`Position`** por opción (`first` → ocupa la opción `0`, p. ej. `off` en multipass; `end` → va al final, p. ej. `custom` en audio), de modo que un catálogo `@{ Value; Text; Position }` genera el menú completo (opción 0 + numeradas + final) alineado y sin claves a mano; (2) **`-NoNone`** para menús sin opción `0` (el encoder, que siempre exige elegir); (3) **`-DefaultValue`**, que acepta como `[ENTER]` un valor que puede **no estar en la lista** (el `audioBitrate` de `config.json` puede ser un bitrate libre como `224k`) y marca la fila si coincide. Multipass y audio dejan de repartir sus opciones a mano (`off`/`copy`/`custom` salen del propio catálogo vía `Position`). De paso, dos retoques cosméticos en todos los menús: `<= por defecto` se **alinea en columna** (tras el texto de la opción más larga, no pegado a cada línea) y se deja una **línea en blanco** antes de `C / ESC. Cancelar`. Verificado (batería 15/15 + pruebas de cada menú: default, selección por número, opción `first`/`end`, valor libre, y compatibilidad de los menús con opciones-cadena de `setup`/herramientas).

### DOC
  - Nueva nota **explica-audio.md**: diagramas de flujo de la selección de pista de audio (mejor por canales → códec → bitrate) y comparativa de tiempo de los métodos de volumen medida sobre 5 min de audio (`peak` ~14 s, `aacgain` ~18 s, `loudnorm` ~63 s ≈ 4,5× más lento). Enlazada desde `ref-perfiles.md` y `ref-comandos.md`.
  - Nueva nota **explica-control-tasa.md**: qué son CRF, QMIN, QMAX y QP, para qué sirve cada uno, cómo se traducen a argumentos de ffmpeg (`Get-VideoArgs`) y cómo elegir valores (escala 0–51). Enlazada desde `ref-perfiles.md` y `ref-configuracion.md`.

---

## VERSION 4.2.2 - 09/07/2026
### FIX
  - **PREPARAR muy lento** en MKVs grandes con 2+ subtítulos del idioma preferido **sin flag de forzado**: para clasificarlos forzado/completo se contaban los cues con `ffprobe -count_packets`, que **demultiplexa el fichero entero** (≈3,8 s por pista en un MKV de 4,4 GB → varios segundos añadidos a cada archivo). Ahora `Get-CvSubtitleCueCount` lee primero el tag de estadísticas de mkvmerge **`NUMBER_OF_FRAMES`** (= nº de cues), que ya viene en el stream cargado por `Get-MediaInfo` (instantáneo, sin demux) y solo recurre a `-count_packets` si el tag falta. Verificado con un caso real: clasificar sus 2 subtítulos en español pasó de ~7,6 s a **~40 ms**, con idéntico resultado (forzado = el de menos cues). Los MKVs muxeados con mkvmerge/MKVToolNix (la mayoría) traen el tag. (Los que se clasifican por flag/título —p. ej. "Forzados"— nunca contaban cues, por eso ya eran rápidos.)

### UPDATE
  - Subtítulos del idioma preferido: **auto-clasificación forzado/completo sin menú**. Antes, con 2 subtítulos en castellano se preguntaba cuál usar y **se perdía el otro** (problema cuando eran forzado + completo). Ahora se conservan **todos**: se distinguen por flag/título o, si no lo traen, por **tamaño** (nº de cues vía `ffprobe -count_packets`, sin extraer) — el más pequeño es el forzado. El **forzado** sale con disposition `default+forced` y título "Forzados"; el **completo** sin default, sin forced y sin título (también el completo suelto: ya no se marca como default). Orden en el MKV: forzados antes que completos. Si hay 2+ completos, se conservan todos con un aviso. (`Split-CvSubtitlesByRole`, `Get-CvSubtitleCueCount`.)
  - Si hay subtítulos pero **ninguno del idioma preferido**, ahora se **pregunta** cuáles conservar (menú multi-selección con idioma/códec/nº de cues), en vez de descartarlos en silencio. El menú permite **reproducir** el vídeo con un subtítulo (`P N`) y **ver su contenido** (`V N`: extrae la pista de texto a un `.srt` temporal y lo abre con el editor asociado de Windows; las pistas de imagen se avisan). (`Select-SubtitlesKeep`, `Show-SubtitleContent`.)
  - Se **conservan los capítulos** del original. En modo copy ya se mantenían, pero al **recodificar** el vídeo se perdían (el intermedio se crea con `-map_chapters -1`); ahora el multiplex los toma del original (`-map_chapters`).
  - El resumen de conversión ahora muestra el **bitrate del audio**. Como ffprobe no suele reportar `bit_rate` por pista para el AAC en MKV (salía solo `aac 2ch`), cuando falta se usa el bitrate **configurado** en el perfil, marcado como `192k (config)`; si ffprobe sí lo trae, se muestra el medido. En modo `copy` se conserva el comportamiento (solo el medido, si lo hay).
  - El resumen de conversión también incluye los **subtítulos** de la salida (nº + idioma, marcando los forzados) y el nº de **capítulos**.
  - Detección de bordes: `border.samples` por defecto sube de **3 a 9** puntos de escaneo repartidos uniformemente por el vídeo, para una detección más fiable cuando el encuadre no es uniforme (créditos, escenas oscuras, barras intermitentes). Además, `border.duration` pasa a ser el tiempo de escaneo **por punto** (antes era un presupuesto total que se repartía entre los puntos): con `samples=9` son 9 escaneos de `duration` s cada uno, así que cada muestra mantiene su ventana completa (a costa de más tiempo total de análisis). (`Find-CropDetectSamples`.)
  - Detección de bordes: **auto-aceptación por votos**. Antes, en cuanto los puntos discrepaban (aunque fuera 8 contra 1) se paraba a preguntar en un menú. Ahora el recorte más votado se acepta automáticamente si alcanza `border.autoAcceptPct` % (por defecto 60) de los puntos que detectaron borde **y** supera al segundo por `border.autoAcceptMinMargin` votos (por defecto 2), descartando los atípicos; solo se muestra el menú si no hay mayoría fiable. El **margen** (además del %) evita que al bajar `samples` se auto-acepte con evidencia débil (`2/3` = 67% pero solo +1 de margen → pregunta; `6/9` = 67% con +3 → auto). `BorderAutoAcceptPct`/`BorderAutoAcceptMargin` en el contexto.
  - Fixtures de test: los subtítulos sintéticos ahora llevan los cues **repartidos por toda la duración** del vídeo (no agrupados al inicio) y en número **variable por rol** (3–9): forzado con pocos (3), completos con muchos (9 y 7), para ejercitar también la clasificación forzado/completo **por tamaño**. (`generate-fixtures.ps1`/`.sh`; corregido de paso un parseo de `duration` sensible al locale al repartir los cues.)
  - En el resumen de conversión, la **duración** es ahora la del fichero **generado** (antes se mostraba la del original, engañoso en modo pruebas donde la salida es un recorte); en modo pruebas se indica también el origen: `Duracion: 0:05:00 (origen 0:56:19)`. Y la **resolución** solo se muestra a ambos lados (`origen -> destino`) cuando **cambia** (resize); si es la misma, se pone una sola vez para no repetir `1920x1080 -> 1920x1080` (el codec sí se muestra siempre como transición, p. ej. `h264 -> hevc`).
  - Los **workers** no abren más ventanas que archivos hay por procesar: si pides 2 workers y solo queda 1 archivo, se codifica en la ventana actual sin abrir otra (`$cap = nº de archivos pendientes`).
  - Nuevo **modo pruebas** (sección propia `test`: `test.enabled`, por defecto `false`, también con el marcador `test_on`): codifica solo los primeros `test.minutes` minutos (por defecto 5, mínimo 1) de cada archivo. Sirve para validar un perfil/ajuste rápido sin procesar el vídeo entero. Se aplica con `-t` en la codificación de vídeo (`Invoke-VideoRun`), audio (`Invoke-AudioRun`, incluida la medición de pico y el wav de sincronía) y en el multiplex final (`Invoke-Multiplex`), de modo que funciona también con el perfil `copy` (recorta el vídeo copiado del original y los subtítulos/capítulos al mismo tramo). Se avisa al arrancar (`▐ AVISO ▌`) y en el resumen (la salida es un **recorte**, no el archivo completo). `TestLimit` (segundos) en el contexto. Verificado E2E (origen 40 s + límite 8 s → salida 8,0 s en encode y 8,2 s en copy). Además, en modo pruebas se muestra un **resumen del origen** antes de procesar cada archivo (`Write-SourceSummary`): pista(s) de vídeo (resolución/codec/fps), **todas** las de audio (codec/canales/idioma/título), **todas** las de subtítulo (tipo/idioma/forzado/default/nº de cues/título) y nº de capítulos.

### DOC
  - Nueva nota **explica-deteccion-bordes.md**: cómo funciona la detección de bordes (escaneo multipunto, reparto por el vídeo, votos y auto-aceptación por % + margen) con matriz de decisión; enlazada desde `ref-configuracion.md`/`ref-comandos.md`/`ref-perfiles.md`.
  - Nueva nota **caso-rendimiento-subtitulos.md**: diagnóstico detallado de la lentitud de PREPARAR con subtítulos y su solución (tag `NUMBER_OF_FRAMES`), con las mediciones antes/después.
  - **Convención de nombres de la documentación**: el prefijo indica el **tipo** de documento — `ref-` (referencia), `explica-` (explicación de un mecanismo), `caso-` (nota de problema→solución) — y el tema va en el resto del nombre. Se renombraron los 8 documentos de referencia (`arquitectura.md` → `ref-arquitectura.md`, etc.) y se actualizaron todos los enlaces cruzados, el índice `docs/README.md` (con la tabla de la convención) y las referencias en `README`/`setup.ps1`/`generate-fixtures`.

---

## VERSION 4.2.1 - 09/07/2026
### FIX
  - Duración mal formateada en vídeos de menos de 1 hora: `Get-DurationText` usaba `[int]$ts.TotalHours`, pero en PowerShell `[int]` **redondea** (0,9 h → 1), así que un vídeo de 53:56 (0,899 h) se mostraba como `1:53:56`. Ahora se trunca con `[math]::Floor`. Verificado (53:56 → `0:53:56`; 59:59 → `0:59:59`, antes `1:00:59`).

---

## VERSION 4.2 - 08/07/2026
### NEW
  - PICO OBJETIVO DE LA NORMALIZACION `peak` CONFIGURABLE (`volume.peakTarget`, POR DEFECTO `0` dBFS): CON `-1` SE DEJA MARGEN (*HEADROOM*) CONTRA EL CLIPPING INTER-SAMPLE DEL AAC. SOLO AMPLIFICA (SI EL PICO YA SUPERA EL OBJETIVO NO ATENUA) Y SE LIMITA A <= 0. `PeakTarget` EN EL CONTEXTO; VERIFICADO E2E (CON `-1`, EL PICO DE SALIDA MEDIDO ES -1.0 dB).
  - EXTENSIONES DE ENTRADA CONFIGURABLES (`encode.extensions`, ANTES FIJAS `avi/flv/mp4/mov/mkv`): AHORA SE PUEDEN AÑADIR `ts`, `webm`, `m4v`, `mpg`... (SE NORMALIZAN A `*.ext`, TOLERANDO `.ext`/`*.ext`).
  - CANALES DEL AUDIO RECODIFICADO CONFIGURABLES (`encode.audioChannels`, ANTES FIJO EN 2/ESTEREO): `2`/`6`/`8` (ESTEREO/5.1/7.1); AFECTA A `-ac` Y AL LAYOUT DE LA RUTA DE SINCRONIA (`Get-CvChannelLayout`). NO APLICA A `audioEncoder: copy`.
  - DETECCION DE BORDES EN VARIOS PUNTOS (`border.samples`, POR DEFECTO 3): EN VEZ DE ESCANEAR SOLO AL INICIO, `cropdetect` SE APLICA EN N PUNTOS REPARTIDOS ENTRE `border.start` Y EL FINAL, REPARTIENDO EL PRESUPUESTO `border.duration` ENTRE ELLOS (NO TARDA MAS). LOS RECORTES SE AGRUPAN POR **VOTOS**: SI TODOS COINCIDEN -> PREVIEW + CONFIRMAR (COMO ANTES); SI DISCREPAN -> `[AVISO]` Y MENU DE RECORTES ORDENADO POR VOTOS PARA ELEGIR CUAL PROBAR. `border.samples=1` (O DURACION DESCONOCIDA) = ESCANEO UNICO CLASICO. NUEVA `Find-CropDetectSamples` EN `lib\Video.psm1`; `BorderSamples` EN EL CONTEXTO. ADEMAS, SI EL VIDEO ES MAS CORTO QUE `border.start`/`preview.start` (P. EJ. <120s), EL INICIO DE SCAN Y PREVIEWS SE **AJUSTA** A ~10% DE LA DURACION (ANTES CAIA FUERA DEL FINAL Y NO DETECTABA/REPRODUCIA NADA). NUEVA `Get-CvSafeStart`.
  - MARCAS ASCII OPCIONALES (`behavior.asciiMarks`, POR DEFECTO `false`): USA `[OK]`/`[ERROR]` Y CORCHETES `[ ]` EN LOS AVISOS EN VEZ DE LOS SIMBOLOS `✓`/`✗` Y EL BADGE `▐ … ▌`, PARA CONSOLAS/FUENTES QUE NO TENGAN ESOS GLIFOS. `Set-CvMarkStyle` EN `lib\Log.psm1` (SE FIJA AL ARRANCAR DESDE EL CONTEXTO); `Get-CvMark` Y `Write-CvLog` LO RESPETAN.
  - FIXTURE DE TEST `pistas-video-multiple.mkv` (2 PISTAS DE VIDEO 640x480 + 320x240 + AUDIO spa): LA BATERIA VERIFICA QUE SE CODIFICA LA **1a PISTA DE VIDEO** (ANCHO DE SALIDA 640, NO 320), EJERCITANDO EL MAPEO `0:<index>` CONGELADO EN EL JOB. AÑADIDO A LOS GENERADORES (`.ps1`/`.sh`) Y A `docs\ref-pruebas.md` (AHORA 15 MUESTRAS).
  - PREVIEWS (ffplay) CONFIGURABLES: NUEVA SECCION `preview` EN `config.json` CON `start` (SEGUNDO DE INICIO, ANTES FIJO EN `border.start`) Y `seconds` (DURACION DE LA MUESTRA, ANTES HARDCODEADA EN 15-20; DEFECTO AMPLIADO A 30). APLICA A LAS PREVIEWS DE PISTA DE AUDIO, PISTA DE VIDEO Y BORDES. ADEMAS, EN LOS MENUS DE SELECCION DE PISTA SE PUEDE INDICAR UN SEGUNDO DE INICIO PUNTUAL: `P N <seg>` / `A N <seg>` (P. EJ. `A 2 300`), PARA BUSCAR DIALOGO CUANDO EN EL PUNTO POR DEFECTO NO HAY VOCES Y NO SE SABE EL IDIOMA. `PreviewStart`/`PreviewSeconds` EN EL CONTEXTO.
  - SELECCION DE PISTA DE VIDEO (VARIAS PISTAS DE VIDEO): SI EL ARCHIVO TIENE 2+ PISTAS DE VIDEO REALES, EN PREPARAR SE MUESTRA UN MENU PARA ELEGIR CUAL, CON REPRODUCCION FFPLAY (`P N`) PARA CONFIRMARLA. EL INDICE ELEGIDO SE CONGELA EN EL `.job.json` (`video.index`) Y SE USA TANTO AL CODIFICAR (`Invoke-VideoRun` MAPEA `0:<indice>`) COMO AL COPIAR/MULTIPLEXAR (`Invoke-Multiplex -VideoIndex`), EN VEZ DEL `0:v:0` FIJO. ADEMAS SE **EXCLUYEN LAS CARATULAS** INCRUSTADAS (`attached_pic` Y CODECS DE IMAGEN mjpeg/png/...), QUE ffprobe LISTA COMO VIDEO: ANTES `0:v:0` PODIA COLAR LA PORTADA SI IBA ANTES DEL VIDEO REAL. LA DETECCION DE BORDES/PREVIEW TAMBIEN APUNTAN A LA PISTA ELEGIDA (`Find-CropDetect -Index`, `Show-Preview -VideoPos`). NUEVAS `Get-VideoStreams`/`Get-VideoStreamPos` (MediaInfo), `Select-VideoInteractive`/`Show-VideoPreview` (Video). SOLO EN LA FASE PREPARAR.
  - AUDIO SIN IDIOMA PREFERIDO: SELECCION MANUAL CON REPRODUCCION. CUANDO NINGUNA PISTA ESTA EN EL IDIOMA PREFERIDO, EN VEZ DE UN SIMPLE AVISO SE MUESTRA LA LISTA DE PISTAS Y SE PUEDE **REPRODUCIR** CADA UNA CON FFPLAY (`P N` = VIDEO+AUDIO, `A N` = SOLO AUDIO) PARA CONFIRMAR CUAL ES ANTES DE ELEGIRLA. TRAS ELEGIRLA SE PREGUNTA QUE **IDIOMA ASIGNAR**: EL QUE TRAE LA PISTA (ENTER), OTRO CODIGO (`O`, O TECLEARLO DIRECTAMENTE) O `und` (`U`), PORQUE EL TAG DE IDIOMA PUEDE SER UNA ERRATA. `Select-AudioFallback`/`Show-AudioPreview` EN `lib\Audio.psm1` (SELECCION DE PISTA CON `-ast a:N`). SOLO EN LA FASE PREPARAR.
  - PERFILES DE CODIFICACION PROPIOS EN `config.json` (SECCION `profiles`): UN ARRAY DE OBJETOS (EN `camelCase`: `videoEncoder`, `crf`, `qmin`, `changeSize`, `detectBorder`, `label`...) QUE SE **ANADEN** A LOS 7 DE SERIE EN EL MENU *USAR PERFIL* (NUMERADOS DESDE EL 8; NO LOS SUSTITUYEN). ETIQUETA `label` OPCIONAL (SI FALTA SE GENERA UN RESUMEN). `ConvertTo-CvProfile`/`Format-CvProfileLabel` EN `lib\Profile.psm1`; `Select-Profile -Extra $ctx.Profiles`. EL EDITOR DE `setup` LOS MUESTRA PERO REMITE A EDITARLOS A MANO (ES UN ARRAY DE OBJETOS).
  - PARAMETRO `-Config <ruta>` EN `Convert.cmd` Y `setup.cmd`: USA/EDITA OTRO FICHERO DE CONFIGURACION EN VEZ DE `config.json` (RUTA ABSOLUTA O RELATIVA AL DIRECTORIO ACTUAL). PERMITE VARIOS JUEGOS DE AJUSTES/PERFILES. LAS VENTANAS DE WORKER EXTRA HEREDAN EL MISMO `-Config`. `Get-CvConfig`/`New-CvContext` ACEPTAN `-Path`/`-ConfigPath`; EL CONTEXTO EXPONE `ConfigPath`.
  - DEPENDENCIAS ENTRE HERRAMIENTAS DECLARADAS (CAMPO `dependsOn` EN EL DESCRIPTOR DEL CATALOGO): `Install-CvTool` ASEGURA LAS DEPENDENCIAS ANTES DE INSTALAR/EXTRAER, DE FORMA GENERICA (ANTES ESTABA HARDCODEADO EN LA RAMA `7z`). P. EJ. `mkvtoolnix` DECLARA `dependsOn: ['sevenzip']` (7zr PARA EXTRAER SU `.7z`).
  - CHECK DE SINTAXIS EN CI (`.github\workflows\lint.yml`): EN CADA PUSH/PR SE VALIDA CON EL PARSER DE POWERSHELL 5.1 QUE TODOS LOS `.ps1`/`.psm1` COMPILAN (CAZA TYPOS/PARENTESIS ANTES DE EJECUTAR).
  - REINTENTOS POR ARCHIVO CONFIGURABLES (`behavior.retries`, POR DEFECTO 2): CUANTAS VECES SE REINTENTA UN ARCHIVO SI SU CODIFICACION FALLA ANTES DE ABANDONARLO (ANTES ESTABA FIJO EN 2). NO CONFUNDIR CON `behavior.workers` (VENTANAS EN PARALELO).

### UPDATE
  - REPRODUCCION EN **TODOS** LOS MENUS DE SELECCION DE PISTA: EL MENU DE AUDIO CON 2+ PISTAS DEL IDIOMA PREFERIDO (`P N` = VIDEO+AUDIO / `A N` = SOLO AUDIO) Y EL DE SUBTITULOS CON 2+ COMPLETOS (`P N` = VIDEO CON ESE SUBTITULO SUPERPUESTO, VIA ffplay `-sst s:N`; UTIL PARA DISTINGUIR NORMAL VS SDH), IGUAL QUE YA TENIAN EL FALLBACK DE AUDIO Y EL MENU DE VIDEO. TODOS ADMITEN SEGUNDO DE INICIO OPCIONAL (`P N <seg>`). NUEVAS `Show-SubtitlePreview` (Subtitle) Y HELPERS `Get-MediaDuration`/`Get-SubtitleStreamPos` (MediaInfo).
  - COLISION DE NOMBRES: SI DOS ENTRADAS DE `Original\` COMPARTEN `BaseName` CON DISTINTA EXTENSION (`peli.mp4` + `peli.mkv`), COMPARTEN JOB/SALIDA/LOCK; AHORA SE MUESTRA `▐ AVISO - Nombre duplicado... se IGNORAN ▌` Y SE **IGNORAN TODOS** LOS ARCHIVOS DEL GRUPO (PARA NO PROCESAR EL EQUIVOCADO; RENOMBRA O QUITA UNO). `Get-ProcessableFiles` EN `Convert.ps1`; EL WORKER APLICA LA MISMA EXCLUSION EN CADA RE-ESCANEO SIN REPETIR EL AVISO.
  - AVISOS/ERRORES COMO "BADGE" RESALTADO CON EXTREMOS DE MEDIO BLOQUE (`▐ TEXTO ▌`): EL INTERIOR (CON PADDING) LLEVA FONDO DE COLOR (ROJO PARA ERR, AMARILLO PARA AVISO/WARN/NO SOPORTADO) Y LOS CAPS `▐`/`▌` VAN COLOREADOS COMO EL FONDO SOBRE COLOR NORMAL, DANDO ASPECTO DE ETIQUETA SOLIDA. EL ULTIMO CARACTER (`▌`) SE PINTA CON FONDO NORMAL, ASI LA ULTIMA CELDA DE LA LINEA NO LLEVA FONDO Y NO SE REPRODUCE EL BUG DE WINDOWS DE QUE EL FONDO SE "ESTIRA" HASTA EL BORDE AL REDIMENSIONAR. ADEMAS SE QUITA LA REDUNDANCIA `[TAG] [AVISO]` (P. EJ. `[AUDIO] [AVISO] - x` -> `▐ AVISO - x ▌`). SE AÑADE UN AVISO AL DETECTAR **VARIAS PISTAS DE VIDEO** (COMO EL DE AUDIO SIN IDIOMA PREFERIDO).
  - INDICADORES DE ESTADO CON SIMBOLOS `✓`/`✗` (U+2713/U+2717, MONOCROMOS) EN VEZ DE `[OK]`/`[ERROR]`, EN TODA LA APP: PASOS DEL WORKER (`Stop-CvStep`), ESTADO POR ARCHIVO EN PREPARAR (`Write-PrepareStatus`) Y MENU *ESTADO* DE `setup` (DIRECTORIOS Y HERRAMIENTAS). HELPER `Get-CvMark` EN `lib\Log.psm1`. SE ELIGIERON SIMBOLOS DE TEXTO (NO EMOJI A COLOR) PORQUE LA CONSOLA CLASICA SI LOS RENDERIZA CON `Cascadia Code`. LOS PREFIJOS DE LOG `[OK] -`/`[ERR] -`/`[AVISO] -` NO CAMBIAN (SON SEMANTICA DE LOG CON COLOREADO DE FONDO).
  - FUENTE DE CONSOLA POR DEFECTO: `Cascadia Code` EN VEZ DE `Consolas` (`console.font`). SI EL EQUIPO NO LA TIENE, CONHOST HACE FALLBACK A SU FUENTE; SE PUEDE VOLVER A `Consolas` EN `config.json` (VIENE EN TODO WINDOWS). NECESARIA PARA QUE SE VEAN LOS SIMBOLOS `✓`/`✗`.
  - FASE WORKER: SALIDA COMPACTA EN USO NORMAL CON UNA LINEA POR PASO (`- <accion>... ✓` / `✗` EN COLOR) EN VEZ DE LOS LOGS POR SECCION, Y EL RESUMEN CON MARCO DE GUIONES. EL DETALLE COMPLETO (LOGS `[SECTION]`, COMANDOS Y CONFIRMACIONES) SIGUE EN MODO DEBUG. HELPERS `Start-CvStep`/`Stop-CvStep`/`Write-CvInfoStep` EN `lib\Log.psm1`.
  - FASE PREPARAR: TODAS LAS PREGUNTAS INTERACTIVAS (SINCRONIA, DETECCION DE BORDES, MENUS DE AUDIO/SUBTITULO, ANIMACION, SELECCION DE PISTA DE VIDEO) SE MUESTRAN INDENTADAS BAJO SU ARCHIVO Y CON UNA LINEA EN BLANCO DESPUES (`Write-CvLog` Y `Show-Menu` TIENEN AHORA `-Indent`, ASI LOS LOGS SE SIGUEN REGISTRANDO Y CONSERVAN EL RESALTADO). LA CABECERA/ESTADO POR ARCHIVO SE DESCRIBE EN LA SECCION FIX.
  - PROMPT DE WORKERS EN PARALELO: LA OPCION **0** SOLO PREPARA Y SALE SIN CODIFICAR (LOS JOBS QUEDAN LISTOS PARA LANZAR LA CONVERSION DESPUES); ANTES EL MINIMO ERA 1.
  - `mkvtoolnix` (mkvpropedit) SE ASEGURA AL ARRANCAR (COMO ffmpeg), NO EN MEDIO DE LA CODIFICACION DEL PRIMER ARCHIVO, SI `postprocess.stripTags` ESTA ACTIVO Y NO SE FIJO UNA RUTA PROPIA.

### FIX
  - FILTRO DE ENTRADA: `Get-ChildItem -Filter '*.mp4'` HEREDA EL COMODIN 8.3 DE WINDOWS Y TAMBIEN CASABA EXTENSIONES MAS LARGAS (`.mp4v`, `.avix`...), QUE SE INTENTABAN CODIFICAR SIN ESTAR EN LA LISTA. `Get-SourceFiles` AHORA RE-FILTRA POR EXTENSION **EXACTA** Y DEDUPLICA (POR SI DOS PATRONES DE `encode.extensions` SOLAPAN).
  - BADGE DE AVISO/ERROR CON EL TOKEN EQUIVOCADO: EN MENSAJES DONDE EL NIVEL NO ERA EL PRIMER TOKEN (`[FFMPEG] - [ERR] - x`) SE RECORTABAN LOS CORCHETES DEL PRIMERO Y EL NIVEL QUEDABA CON CORCHETES DENTRO DEL BADGE. AHORA SE QUITAN LOS CORCHETES DE **TODOS** LOS TOKENS INICIALES (`▐ FFMPEG - ERR - x ▌`).
  - FASE PREPARAR (MODO NORMAL): SE PERDIA LA CABECERA CON EL NOMBRE DEL ARCHIVO. EL ESTADO `[OK]` CON EL NOMBRE SE IMPRIMIA AL FINAL, ASI QUE LOS MENUS INTERACTIVOS (SELECCION DE PISTA DE VIDEO/AUDIO, BORDES...) APARECIAN SIN SABER DE QUE ARCHIVO ERAN. AHORA EL NOMBRE SE IMPRIME COMO CABECERA **ANTES** DE LAS PREGUNTAS (`Write-PrepareHeader`) Y TODO LO INTERACTIVO QUEDA INDENTADO DEBAJO (IGUAL QUE EL PROMPT DE SINCRONIA). EL ESTADO FINAL ES UNA LINEA CON ETIQUETA (`Preparado ✓`), NO UN SIMBOLO SUELTO. SI HUBO **CUALQUIER PREGUNTA INTERACTIVA** (SELECCION DE PISTA DE VIDEO/AUDIO/SUBTITULO, DETECCION DE BORDES, ANIMACION O SINCRONIA DE AUDIO) SE MARCA EN AMARILLO COMO `Preparado (seleccion manual) ✓`; FALLO DE LECTURA -> `No se pudo preparar ✗`. LOS ASK DEVUELVEN UN CAMPO `Manual` Y `Select-Subtitles` LO SEÑALA CON `-Manual [ref]`.
  - `Test-CvLanguage` NO RECONOCIA VARIANTES DEL MISMO IDIOMA SI LA LISTA DE PREFERIDOS SOLO TENIA UNA: CON `languages.audio = ["es"]` UNA PISTA `spa` SE TRATABA COMO "NO PREFERIDA" (SALTABA EL MENU DE DESCARTE SIN MOTIVO). AHORA SE CANONICALIZAN AMBOS LADOS (`Get-CvLangCanon`: `es`/`spa`/`esp`/`castellano`/`spanish`/`es-ES` -> `es`, IGUAL PARA `en`/`fr`/`de`/`it`/`pt`/`ja`/`zh`/`ko`/`ru`/`ca`/`gl`/`eu`), ASI BASTA UN CODIGO EN LA LISTA PARA RECONOCER CUALQUIER VARIANTE. EL EJEMPLO DE CODIGO AL ASIGNAR IDIOMA AHORA SUGIERE ISO 639-2 (`spa`, `eng`, `fre`).
  - IDIOMA DE AUDIO FIJADO A `spa` EN EL MULTIPLEX AUNQUE LA PISTA ELEGIDA FUERA OTRA: SI UN ARCHIVO NO TENIA AUDIO EN EL IDIOMA PREFERIDO Y CAIA AL DESCARTE (eng/und), LA SALIDA QUEDABA MAL ETIQUETADA COMO `spa`. AHORA EL IDIOMA DE LA PISTA ELEGIDA SE CONGELA EN EL `.job.json` (`audio.lang`) Y EL MULTIPLEX LO USA. ADEMAS, SI NO HAY NINGUNA PISTA EN EL IDIOMA PREFERIDO SE MUESTRA UN `[AVISO]`.

### REFACTOR
  - DEDUPLICACION DE CODIGO: (1) `ConvertFrom-CvPlayCommand` (Console) UNIFICA EL PARSER DE `P N [seg]`/`A N [seg]` QUE ESTABA REPETIDO EN LOS 4 MENUS DE SELECCION DE PISTA; (2) `Invoke-CvPreview` (Exec) UNIFICA LA CONSTRUCCION DE ARGS DE ffplay (`-ss/-t/-autoexit` + CLAMP DE INICIO) DE LAS 4 PREVIEWS (BORDES/VIDEO/AUDIO/SUBTITULO); (3) `Resolve-CvConfigPathArg` (Config) UNIFICA LA RESOLUCION DEL ARGUMENTO `-Config` DE `Convert.ps1` Y `setup.ps1`; (4) `Get-MediaDuration` (MediaInfo) YA HABIA ELIMINADO EL BLOQUE DE DURACION REPETIDO.
  - PARAMETRO `-Profile` DE LAS FUNCIONES DE VIDEO/AUDIO/PERFIL RENOMBRADO A `-Prof` PARA NO PISAR LA VARIABLE AUTOMATICA `$PROFILE` DE POWERSHELL (EVITA AVISOS DEL LINTER Y CONFUSIONES).
  - `test\run-tests.ps1` USA UN ROOT AISLADO (JUNCTIONS A `lib\`/`tools\` + SU PROPIO `config.json` Y COPIA DE `Convert.ps1`) EN VEZ DE INTERCAMBIAR EL `config.json` REAL: LA BATERIA YA NO TOCA NADA DEL PROYECTO. LAS JUNCTIONS SE BORRAN DE FORMA SEGURA (SOLO EL ENLACE, NO EL DESTINO).

### DOC
  - DOCUMENTACION ACTUALIZADA A TODAS LAS NOVEDADES DE v4.2 (SELECCION DE PISTA DE VIDEO, AUDIO SIN IDIOMA PREFERIDO, BORDES MULTIPUNTO, `profiles`, `preview`, `-Config`, `dependsOn`, `asciiMarks`, EXTENSIONES/CANALES CONFIGURABLES, SIMBOLOS `✓`/`✗` Y BADGE `▐ ▌`, FUENTE `Cascadia Code`).
  - DIAGRAMAS DE FLUJO (MERMAID) EN **TODOS** LOS DOCUMENTOS: NUEVOS EN `arquitectura` (CAPAS/DEPENDENCIAS DE MODULOS), `flujo` (CLASIFICACION Y PIPELINE INTERNO POR ARCHIVO), `comandos` (HERRAMIENTA POR FASE), `configuracion` (FUSION/EDICION DE CONFIG), `perfiles` (SELECCION DE PERFIL) Y `pruebas` (FLUJO DE LA BATERIA). CLASIFICACION DE ENTRADA DETALLADA EN `ref-flujo.md` (CARPETA+EXTENSION, IDENTIDAD POR `BaseName`, COLISION DE NOMBRES). `ref-jobs.md` AL DIA (`video.index`/`audio.lang`).

---

## VERSION 4.1 - 08/07/2026
### NEW
  - WORKERS EN PARALELO BAJO DEMANDA: AL TERMINAR PREPARAR SE PREGUNTA CUANTOS WORKERS CODIFICARAN A LA VEZ (CONTANDO ESTA VENTANA; ENTER USA EL DEFAULT `behavior.workers`, CONFIGURABLE, 2). SE ABREN N-1 VENTANAS NUEVAS CON `Convert.cmd -WorkerOnly`, QUE SALTAN PREPARAR Y ENTRAN DIRECTAS A CODIFICAR, REPARTIENDOSE LOS ARCHIVOS POR EL LOCK. NUEVO FLAG `-WorkerOnly` EN `Convert.ps1`.
  - CONSERVACION DE ADJUNTOS (ATTACHMENTS) DEL ORIGINAL, CONFIGURABLE Y POR CATEGORIA (NUEVO MODULO `lib\Attachment.psm1`). POR DEFECTO NO SE CONSERVA NINGUNO; CON `postprocess.attachments.keep = true` SE PUEDEN PERMITIR/EXCLUIR **FUENTES** (`fonts`, P. EJ. PARA SUBTITULOS ASS/SSA), **CARATULAS** (`covers`) Y **OTROS** (`other`). EL MULTIPLEX MAPEA LOS ELEGIDOS POR SU INDICE Y RE-FIJA `filename`/`mimetype` (EL `-map_metadata -1` LOS BORRABA Y EL MUXER DE MATROSKA EXIGE `filename`).
  - LIMPIEZA AUTOMATICA DE LAS ETIQUETAS `DURATION` DEL MKV FINAL CON `mkvpropedit` (MKVToolNix). EL MUXER DE FFMPEG ESCRIBE UN TAG `DURATION` POR PISTA AL CERRAR EL FICHERO (NO HAY FLAG PARA OMITIRLO SIN PERDER LOS CUES/DURACION); TRAS MULTIPLEXAR SE EJECUTA `mkvpropedit <out> --tags all:` QUE LOS BORRA IN SITU CONSERVANDO CUES, DURACION Y DISPOSITIONS. CONTROLABLE EN `config.json` (`postprocess.stripTags` / `postprocess.mkvpropedit`).
  - DOS HERRAMIENTAS NUEVAS EN EL CATALOGO `downloads`, CON AUTO-DESCARGA: `mkvtoolnix` (SOLO SE USA `mkvpropedit.exe`) Y `sevenzip` (`7zr.exe`, EL EXTRACTOR "BOOTSTRAP" QUE HACE FALTA PORQUE MKVTOOLNIX SE DISTRIBUYE COMO `.7z`/LZMA, QUE NO ABREN NI `Expand-Archive` NI EL `tar` DE WINDOWS). NUEVO TIPO DE DESCARGA `7z` EN `Install-CvTool` (EXTRAE CON `7zr`, ASEGURANDOLO ANTES).
  - INFRAESTRUCTURA DE TESTS EN `test\`: MUESTRAS RENOMBRADAS POR LO QUE PRUEBAN + FIXTURES MULTIPISTA GENERADAS (`generate-fixtures.ps1`/`.sh`), Y UNA BATERIA (`run-tests.ps1`) QUE LANZA EL `Convert.ps1` REAL (FASE WORKER) CON UN PERFIL TEST EN UN AREA AISLADA Y VERIFICA CADA SALIDA (CODEC, RESIZE, SELECCION DE AUDIO/SUBS, SUBTITULO FORZADO CON `default`, Y CERO ETIQUETAS). LANZADORES DE VS CODE EN `.vscode\` (`launch.json` / `tasks.json`). DOCUMENTADO EN `docs\ref-pruebas.md`.
  - CABECERA AL ARRANCAR (APP + VERSION) EN EL CONVERSOR Y EN `setup` (`Show-CvHeader`). LA VERSION SE DEFINE EN UN SOLO SITIO (`Get-CvVersion`, EXPUESTA COMO `$ctx.Version`).
  - OPCION `X. SALIR` EN EL MENU DE PERFILES: CIERRE LIMPIO DEL CONVERSOR (ANTES NO HABIA SALIDA).
  - AL CONFIGURAR UN PERFIL CUSTOM SE PUEDE CANCELAR EN CUALQUIER PREGUNTA CON `C` O LA TECLA `ESC` (VUELVE AL MENU DE PERFILES Y LIMPIA LA PANTALLA); AL FINAL, `[R]` PARA REHACER. LA CAPTURA DE `ESC` USA UN LECTOR DE LINEA PROPIO (`Read-CvLine`, CON FALLBACK A `Read-Host` SI NO HAY CONSOLA).

### UPDATE
  - FASE PREPARAR MAS COMPACTA EN USO NORMAL: UNA SOLA LINEA POR ARCHIVO CON EL NOMBRE Y UN BADGE DE ESTADO DE COLOR (` OK ` VERDE / ` ERROR ` ROJO, ASCII PARA QUE SE VEA SIEMPRE; LOS SIMBOLOS UNICODE ✓/✗ NO LOS RENDERIZA LA FUENTE DE LA CONSOLA). LOS `[INFO]` PASIVOS DE CADA MODULO (AUDIO/SUB/VIDEO) Y EL MARCO SOLO SE MUESTRAN EN MODO DEBUG (`behavior.debug` / MARCADOR `debug_on`), QUE SIGUE DANDO EL DETALLE COMPLETO. LAS PREGUNTAS INTERACTIVAS (BORDES, SINCRONIA, MENUS) SE SIGUEN VIENDO EN AMBOS MODOS.
  - EL WORKER MUESTRA AL INICIAR CADA ARCHIVO SU RESOLUCION Y DURACION (`[WORKER] [INFO] - Resolucion: 1920x1080  Duracion: 0:24:03`), UTIL PARA SABER CUANTO DURARA LA CODIFICACION.
  - MENU DE `setup` MAS CORTO: LA GESTION DE HERRAMIENTAS (UNA ENTRADA POR APP + REINSTALAR TODO) SE MUEVE A UN SUBMENU, ASI EL MENU PRINCIPAL NO CRECE AL AÑADIR APPS.
  - EL EDITOR DE CONFIGURACION DE `setup` YA NO REESCRIBE TODO `config.json`: SOLO TOCA LOS VALORES EDITADOS. LO QUE SE FIJA DISTINTO DEL DEFAULT SE GUARDA; LO QUE SE DEJA IGUAL AL DEFAULT SE ELIMINA DEL FICHERO (Y SE PODAN LAS SECCIONES QUE QUEDAN VACIAS). ASI `config.json` SOLO CONTIENE LO QUE DIFIERE DE LOS DEFAULTS. "RESTABLECER" SIGUE GENERANDO EL CONFIG COMPLETO.
  - FIX: `Get-CvNodeKeys` DABA UNA CLAVE FANTASMA `""` PARA OBJETOS SIN PROPIEDADES (`@($null)`), LO QUE ESCRIBIA `{"": null}` Y ROMPIA EL PODADO DE SECCIONES VACIAS AL GUARDAR CONFIG. AHORA UN OBJETO VACIO DA 0 CLAVES Y SE SERIALIZA `{}`.
  - DISEÑO DE MENUS: DE CUADRO DE DOBLE LINEA A SEPARADORES DE GUIONES (`----`), QUE ADEMAS NO TRUNCAN LAS LINEAS LARGAS. EL CUADRO SE CONSERVA EN `Show-CvBox` PARA MENSAJES DESTACADOS (AVISOS/ERRORES, CON COLOR OPCIONAL).
  - LOS MENUS DE OPCIONES SE GENERAN DESDE EL MAPA DE OPCIONES (`Get-CvMenuLines` / `Get-CvOptionValue`) PARA NO DUPLICAR DATOS Y TEXTO (EL TEXTO DESCRIPTIVO ES OPCIONAL POR OPCION).
  - VEREDICTO DE COMPATIBILIDAD GPU COMO BADGE DE COLOR (`COMPATIBLE` VERDE / `NO COMPATIBLE` ROJO) Y LA CAUSA EN LINEAS LEGIBLES: SE PRIORIZA LA LINEA INFORMATIVA DE FFMPEG (P.EJ. "Driver does not support the required nvenc API version...") IGNORANDO EL RUIDO DE TERMINACION.

### FIX
  - LA VENTANA APARTE DE CODIFICACION (`behavior.separateWindow`) ROBABA EL FOCO AL ABRIRSE AUNQUE QUEDARA MINIMIZADA: `Start-Process -WindowStyle Minimized` USA `SW_SHOWMINIMIZED`, QUE **ACTIVA** LA VENTANA. AHORA SE LANZA CON `CreateProcess` + `SW_SHOWMINNOACTIVE` (HELPER NATIVO `CvProc` EN `lib\Exec.psm1`): LA CONSOLA NUEVA APARECE MINIMIZADA **SIN ROBAR EL FOCO**. SI LA API FALLARA, CAE AL METODO CLASICO.
  - BUCLE INFINITO EN EL WORKER: UN ARCHIVO QUE FALLABA SIEMPRE (INPUT CORRUPTO, PERFIL MALO, FFMPEG QUE NO ARRANCA) SE REINTENTABA SIN FIN. AHORA HAY LIMITE DE REINTENTOS POR ARCHIVO (SE ABANDONA TRAS N FALLOS) Y LOS ILEGIBLES SE DESCARTAN.
  - EL WORKER YA NO SE ABORTA POR COMPLETO ANTE UN ERROR INESPERADO EN UN ARCHIVO: SE CAPTURA POR ARCHIVO (`try/catch`), SE REGISTRA Y SE PASA AL SIGUIENTE.
  - LOS PASOS DE CODIFICACION (AUDIO/VIDEO/MULTIPLEX) DABAN POR BUENA UNA SALIDA PARCIAL AUNQUE FFMPEG FALLARA (CODIGO != 0). AHORA EXIGEN CODIGO 0 + SALIDA NO VACIA Y BORRAN LA PARCIAL; EL WORKER NO MULTIPLEXA SI LA CODIFICACION DE AUDIO O VIDEO FALLO (ANTES PODIA GENERAR UN MKV CON EL VIDEO SIN RECODIFICAR).
  - LOCKS HUERFANOS: SI UN WORKER MUERE A MITAD, SU `.lock` BLOQUEABA EL ARCHIVO PARA SIEMPRE. AHORA EL LOCK GUARDA `PID`+EQUIPO Y OTRO WORKER ROBA EL LOCK SI EL PROCESO DUEÑO YA NO EXISTE (SOLO EN EL MISMO EQUIPO).
  - DESCARGA DE HERRAMIENTAS CON REINTENTOS (3) ANTE FALLOS DE RED TRANSITORIOS.
  - SUBTITULO FORZADO QUE PERDIA EL FLAG "PISTA PREDEFINIDA" (`default`) AL CONVERTIR: EN LA SELECCION SOLO SE MARCABA `default` AL SUBTITULO COMPLETO ELEGIDO Y A LOS FORZADOS SE LES PONIA `default=0` SIEMPRE, IGNORANDO SU VALOR ORIGINAL. AHORA `ConvertTo-SubSel` CONSERVA EL FLAG `default` ORIGINAL DE LA PISTA CUANDO NO SE FUERZA EXPLICITAMENTE (`Test-SubDefault`), ASI UN FORZADO QUE YA ERA PREDEFINIDO LO SIGUE SIENDO EN EL MKV FINAL.
  - ETIQUETAS (TAGS) BASURA EN EL MKV FINAL QUE NO ESTABAN EN EL ORIGINAL: AL RECODIFICAR, FFMPEG COPIABA AL VIDEO LAS ESTADISTICAS OBSOLETAS DEL ORIGEN (`_STATISTICS_*`, `BPS`) Y SU PROPIA ETIQUETA `ENCODER`; EL CONTENEDOR `.m4a` INTERMEDIO AÑADIA `VENDOR_ID`/`HANDLER_NAME` AL AUDIO; Y SE ESCRIBIA UNA ETIQUETA `ENCODER` GLOBAL. EL MULTIPLEX AHORA LIMPIA TODOS LOS METADATOS HEREDADOS (`-map_metadata -1`, QUE VACIA TAMBIEN LOS TAGS DE CADA PISTA) + `-fflags +bitexact` (EVITA LA `ENCODER` GLOBAL) Y RE-FIJA SOLO LO QUE QUEREMOS (TITULO/IDIOMA/DISPOSITION). EL AUDIO EN MODO `copy` (PERFIL 1) RESTAURA SUS METADATOS ORIGINALES (`-map_metadata:s:a:0 0:s:a:0`) PARA NO PERDER IDIOMA/TITULO. EL TAG `DURATION` POR PISTA QUE AÑADE EL MUXER SE ELIMINA DESPUES CON `mkvpropedit` (VER NEW).
  - CODIFICACION DE VIDEO CON MAPEO FRAGIL `-map 0:0` (PRIMER STREAM): SI EL CONTENEDOR TRAIA ANTES UN SUBTITULO O AUDIO, `Invoke-VideoRun` MAPEABA ESA PISTA Y, CON `-an -sn`, FFMPEG ABORTABA CON "Output file does not contain any stream". CORREGIDO A `-map 0:v:0` (LA PISTA DE VIDEO, SEA CUAL SEA SU POSICION). LO DETECTO LA FIXTURE DE ORDEN ALEATORIO DE PISTAS.

---

## VERSION 4.0 - 08/07/2026
### NEW
  - REESCRITURA COMPLETA A POWERSHELL 5.1, DISENO MODULAR EN `lib\` Y CONFIGURACION EN `config.json`. EL BATCH (`LimpiarBorde.cmd` + `src\` + TOOLS `aacgain`/`controls`/`AtomicParsley`/`x86`) SE RETIRA DE `master` Y SE CONSERVA EN LA RAMA `v3.x`.
  - NUEVA ESTRUCTURA:
    - `Convert.ps1` -> ORQUESTACION (CLASIFICAR / PREPARAR / WORKER CON MUTEX).
    - `Convert.cmd` -> LANZADOR (`-ExecutionPolicy Bypass` + `chcp 65001` PARA UTF-8).
    - `config.json` -> TODA LA CONFIGURACION, SE CARGA AL ARRANCAR.
    - `lib\Common.psm1` (contexto, config, jobs JSON, lock, consola), `lib\Tools.psm1` (apps/versiones/descargas), `lib\MediaInfo.psm1` (ffprobe JSON), `lib\Profile.psm1`, `lib\Video.psm1`, `lib\Audio.psm1`, `lib\Subtitle.psm1`, `lib\Multiplex.psm1`.
    - `setup.ps1` + `setup.cmd` -> UTILIDAD DE GESTION (HERRAMIENTAS Y CONFIGURACION).
  - INFO DE STREAMS CON FFPROBE EN JSON: SUSTITUYE A LOS SCRIPTS `.vbs` Y A LOS PARSEOS CON `findstr`.
  - SELECCION DE AUDIO Y SUBTITULOS POR IDIOMA, CON LISTAS SEPARADAS EN `config.json` (`audioLanguages` / `subtitleLanguages`) Y NORMALIZACION DE VARIANTES (`es_es`, `es-ES`, `es`, `spa`, `castellano`...). MENU SI HAY VARIAS PISTAS DEL MISMO IDIOMA.
  - GESTION DE SUBTITULOS POR IDIOMA: MANTIENE EL COMPLETO + LOS FORZADOS DEL IDIOMA PREFERIDO, CON SUS METADATOS (`language`, `default`, `forced`). EL TITULO DE LA PISTA SE PONE A `Forzados` EN LAS FORZADAS Y EN BLANCO EN LAS COMPLETAS.
  - DESCARGA AUTOMATICA DE HERRAMIENTAS: SI FALTA `ffmpeg`/`ffprobe`/`ffplay` (O `aacgain` SI SE USA ESE METODO DE VOLUMEN) SE OFRECE DESCARGARLO. SISTEMA GENERICO MULTI-APP/MULTI-VERSION DESCRITO EN `config.json` (`downloads`), CON VERIFICACION `SHA256`, SOPORTE `zip`/`file` Y LECTURA DE LA VERSION REALMENTE INSTALADA DESDE LA PROPIA APP.
  - NORMALIZACION DE VOLUMEN CON 3 METODOS SELECCIONABLES EN `config.json` (`volume.method`): `peak` (PICO CON `volumedetect`, POR DEFECTO), `loudnorm` (EBU R128 CON `I`/`TP`/`LRA` CONFIGURABLES) Y `aacgain` (REPLAYGAIN SIN PERDIDA SOBRE EL M4A).
  - `config.json` ORGANIZADO POR SECCIONES: `downloads`, `languages`, `encode`, `border`, `volume`, `behavior`, `console`, `paths` (FUSION PROFUNDA CON LOS VALORES POR DEFECTO, AMPLIABLE SIN ROMPER CONFIGS EXISTENTES).
  - CARPETAS DE TRABAJO CONFIGURABLES EN `config.json` (`paths`): `original`, `proceso`, `convertido` Y `logs` PUEDEN APUNTAR A OTRA RUTA (ABSOLUTA O RELATIVA); VACIO = JUNTO AL PROGRAMA. SE CREAN SOLAS. `tools\` SIGUE JUNTO AL PROGRAMA.
  - RESUMEN ENMARCADO AL TERMINAR CADA ARCHIVO: TAMANO ORIGEN -> FINAL (CON % DE AHORRO), RESOLUCION, CODECS, DURACION Y TIEMPO DE PROCESO.
  - CODIFICACIONES EN VENTANA APARTE MINIMIZADA (LA PRINCIPAL QUEDA LIMPIA); LA PREVISUALIZACION DE BORDES SE VE EN LA PRINCIPAL. MARCADOR `same_window` PARA FORZAR TODO EN LA PRINCIPAL.
  - MENUS CON CUADRO DE DOBLE LINEA UNIFICADO (`Show-Menu`).
  - BLOQUEO DEL BOTON X DE LA VENTANA DURANTE EL PROCESO (NATIVO VIA API DE WINDOWS, SUSTITUYE A `controls.exe`), CON REACTIVACION GARANTIZADA (TRAP/FINALLY).
  - APARIENCIA CONFIGURABLE EN `config.json`: FUENTE (`SetCurrentConsoleFontEx`), TAMANO DE FUENTE, COLORES Y TAMANO DE VENTANA (CON BUFFER DE SCROLL).
  - PERFIL CUSTOM CON SELECTORES (ENCODER, PERFIL Y LEVEL POR CODEC, TAMANOS, BITRATE).
  - LIMPIEZA DE TEMPORALES AL TERMINAR (MARCADOR `keep_temp` PARA CONSERVARLOS).
  - MODO DEBUG DESDE `config.json` O MARCADOR `debug_on`: MUESTRA CADA COMANDO (ANALISIS Y CODIFICACION), PIDE CONFIRMACION Y CODIFICA EN LA MISMA VENTANA.
  - HERRAMIENTAS VERSIONADAS EN DISCO: `tools\<app>\<version>\<plataforma>`. VARIAS VERSIONES DE FFMPEG CONVIVEN Y EL SELECTOR LAS ORDENA DE MAS NUEVA A MAS ANTIGUA. CADA APP DECLARA SU `platform` EN `config.json` (`x86`/`x64`/`x86_64`, NORMALIZADA); SI NO HAY BUILD PARA LA PLATAFORMA DEL EQUIPO SE AVISA `[NO SOPORTADO]`.
  - LOS JOBS CONGELAN LA VERSION DE FFMPEG (Y `aacgain` SI PROCEDE) USADA AL PREPARAR. EL WORKER CODIFICA CON ESA VERSION Y, SI FALTA EN EL EQUIPO, LA DESCARGA E INSTALA SOLO. DISTINTOS JOBS PUEDEN USAR DISTINTAS VERSIONES.
  - VALIDACION DE COMPATIBILIDAD GPU AL INSTALAR FFMPEG: SE CODIFICA UN CLIP MINIMO CON `hevc_nvenc`/`h264_nvenc` (`Test-CvNvenc`) Y, SI LA CODIFICACION POR GPU NO FUNCIONA CON ESA VERSION Y EL DRIVER NVIDIA DEL EQUIPO, SE AVISA CON LA CAUSA (P.EJ. FFMPEG 8 EXIGE NVENC 13.1 Y EL DRIVER SOLO DA 13.0) Y SE SUGIERE PERFIL CPU / OTRA VERSION / ACTUALIZAR DRIVER.
  - UTILIDAD `setup.ps1` (+ `setup.cmd`, LANZADOR CON BYPASS), CON MENU AGRUPADO POR BLOQUES (INSTALACION / ESTADO / COMPATIBILIDAD / CONFIGURACION / LIMPIEZA):
    - GESTION DE HERRAMIENTAS: INSTALAR / CAMBIAR VERSION, REINSTALAR (POR CARPETA DE VERSION), REINSTALAR TODO, Y "VER ESTADO" (BAJO DEMANDA) CON LAS VERSIONES REALMENTE INSTALADAS POR PLATAFORMA Y EL CHECKLIST DE DIRECTORIOS.
    - COMPROBAR COMPATIBILIDAD GPU (NVENC) DE LAS VERSIONES DE FFMPEG INSTALADAS.
    - EDITAR TODO `config.json` SIN TOCARLO A MANO (SELECTORES DE COLOR/METODO/BOOLEANOS, EDITOR DE LISTAS), CON GUARDADO PROPIO QUE CONSERVA VALORES, TIPOS, ARRAYS Y FORMATO (4 ESPACIOS, CRLF).
    - RESTABLECER `config.json` A LOS VALORES POR DEFECTO (CONSERVANDO EL CATALOGO DE HERRAMIENTAS Y CON COPIA `.bak`).
    - LIMPIAR `Proceso` (JOBS / BLOQUEOS / TEMPORALES) Y LA CARPETA `logs\`, CON CONFIRMACION.
    - CREA LOS DIRECTORIOS DE TRABAJO QUE FALTEN.
  - LOG DE CADA EJECUCION (TRANSCRIPT) EN `logs\` (UN FICHERO POR VENTANA: FECHA + PID), TANTO DEL CONVERSOR COMO DE `setup`. CONFIGURABLE CON `behavior.log` O EL MARCADOR `no_log`.
  - RESALTADO DE LOG POR COLOR: LAS LINEAS `[ERR]` SALEN CON FONDO ROJO Y `[AVISO]`/`[NO SOPORTADO]` CON FONDO AMARILLO (EN TODO EL PROCESO: WORKER, VIDEO, AUDIO, MULTIPLEX, HERRAMIENTAS). EL VEREDICTO DE COMPATIBILIDAD GPU SE MUESTRA COMO BADGE `COMPATIBLE` (VERDE) / `NO COMPATIBLE` (ROJO), CON LA CAUSA EN LINEAS LEGIBLES.
  - DOCUMENTACION DETALLADA EN `docs\`: ARQUITECTURA, FLUJO CON DIAGRAMAS, COMANDOS EXACTOS DE LAS HERRAMIENTAS POR FASE, PERFILES, REFERENCIA DE `config.json`, HERRAMIENTAS/VERSIONES Y JOBS. EL `README.md` GENERAL LA REFERENCIA.
  - WORKFLOW DE GITHUB ACTIONS: AL PUBLICAR UN TAG `v*` EMPAQUETA EL PROYECTO (`git archive` A `ConversorVideoCMD-<tag>.zip`) Y CREA LA RELEASE CON EL ZIP. VIA `.gitattributes` (`export-ignore`) EL PAQUETE EXCLUYE `tools\`, `logs\`, `docs\`, `README.md`, `TODO.md` Y LOS FICHEROS DE CI.

### UPDATE
  - LA SINCRONIA (SILENCIO AL INICIO CUANDO EL AUDIO NO EMPIEZA A LA VEZ QUE EL VIDEO) Y LA NORMALIZACION DE VOLUMEN SE MANTIENEN; EL VOLUMEN SE MIDE CON `volumedetect` (INDEPENDIENTE DEL LOCALE) Y SE APLICA GANANCIA AL RECODIFICAR.
  - LA DETECCION DE BORDES CONSERVA LA PREVISUALIZACION CON FFPLAY (ORIGINAL Y RECORTADO) Y LA RE-DETECCION; REGLA DEL PREFIJO `_` MANTENIDA.

### FIX
  - COLISION DE NOMBRES: LAS FUNCIONES DE JOB (`Write-Job`/`Read-Job`/`Remove-Job`...) CHOCABAN CON LOS CMDLETS NATIVOS `*-Job` DE POWERSHELL, Y AL ESCRIBIR EL JOB FFMPEG... (EN REALIDAD LA RESOLUCION IBA A UN COMANDO CON `-Encoding` Y FALLABA CON "No se encuentra ningun parametro ... 'Encoding'"). RENOMBRADAS TODAS A `*-CvJob`.
  - NOMBRES DE ARCHIVO CON CORCHETES `[...]`: POWERSHELL LOS INTERPRETA COMO COMODINES EN `-Path`, ASI QUE EL `.job.json` SE QUEDABA COMO `.tmp` (EL `Move-Item` FALLABA EN SILENCIO) Y EL WORKER NO ENCONTRABA LOS JOBS (`Test-Path` DEVOLVIA FALSO). AHORA SE USA `-LiteralPath` Y OPERACIONES `.NET` LITERALES (`[IO.File]::Move/Delete`) EN TODAS LAS OPERACIONES DE FICHERO (JOBS, TEMPORALES, SALIDA, LOCK) DE TODOS LOS MODULOS.
  - LOCK ATOMICO ENTRE WORKERS PASADO DE DIRECTORIO (`mkdir`) A FICHERO CON `FileMode.CreateNew` (SIGUE SIENDO ATOMICO -FALLA SI YA EXISTE- Y ES COMPATIBLE CON NOMBRES CON CORCHETES).

### REFACTOR
  - DISENO MODULAR AFINADO: `Common.psm1` SE REPARTE POR RESPONSABILIDAD EN `lib\Log` (LOG + TRANSCRIPT), `lib\Config` (DEFAULTS / CARGA / FUSION / RESET / SERIALIZACION DE `config.json`), `lib\Context` (CONTEXTO `$ctx`), `lib\Console` (APARIENCIA / VENTANA NATIVA / MENUS / PROMPTS), `lib\Exec` (EJECUCION DE PROCESOS) Y `lib\Job` (JOBS / LOCK / TEMPORALES / SALIDA). LA GESTION DE APPS/VERSIONES/DESCARGAS ESTA EN `lib\Tools`.
  - ELIMINACION DE CODIGO DUPLICADO CON FUENTES UNICAS DE VERDAD: `Get-CvWorkDirs` (CARPETAS DE TRABAJO), `Get-CvAppDescriptor` (DESCRIPTOR DE APP), `New-CvToolContext` (RUTAS Y NOMBRES DE EXE), `Get-CvToolDir` (CARPETA VERSION/PLATAFORMA), `Get-CvConfigDefaults` (DEFAULTS DE CONFIG) Y `Get-CvTempPaths` (RUTAS DE FICHEROS TEMPORALES).

### PENDIENTE
  - AUDIO MULTIPISTA (MANTENER VARIAS PISTAS DE AUDIO POR IDIOMA) QUEDA EN `TODO.md`.

---

## VERSION 3.2 - 07/07/2026
### NEW
  - `LimpiarBorde.cmd` PASA A UN MODELO DE COLA PREPARAR/PROCESAR (PRODUCTOR/CONSUMIDOR):
    - AL ARRANCAR, SI HAY ALGUN ARCHIVO SIN `.job` (Y SIN CONVERTIR) -> FASE PREPARAR: HACE TODAS LAS PREGUNTAS Y DETECCIONES (BORDES + PREVIEW, RESIZE, ANIMACION, SINCRONIA) Y ESCRIBE UN FICHERO `Proceso\<nombre>.job` CON LA CONFIGURACION RESUELTA (PERFIL CONGELADO).
    - DESPUES, EN LA MISMA VENTANA -> FASE WORKER: CODIFICA LOS ARCHIVOS PREPARADOS SIN PREGUNTAR NADA, LEYENDO SU `.job`.
    - SE PUEDEN ABRIR VARIAS VENTANAS: CUANDO TODOS TIENEN `.job`, CADA UNA ENTRA DIRECTA COMO WORKER Y SE REPARTEN LOS ARCHIVOS.
  - BLOQUEO ATOMICO ENTRE WORKERS CON `mkdir Proceso\<nombre>.lock` (mkdir FALLA SI YA EXISTE = MUTEX REAL DE UNA SOLA OPERACION), SUSTITUYE AL ANTIGUO `_lock.txt` CON `type NUL` (QUE NO ERA ATOMICO). EL LOCK SE LIBERA AL TERMINAR.
  - REGLA DEL PREFIJO `_`: SI EL NOMBRE DEL ARCHIVO EMPIEZA POR `_`, SE FUERZA LA DETECCION DE BORDES AUNQUE EL PERFIL O LA RESPUESTA DIGAN "SIN BORDES".
  - EL JOB ES AUTOSUFICIENTE (LLEVA EL PERFIL CONGELADO), ASI QUE UN WORKER NO DEPENDE DE LA CONFIGURACION GLOBAL Y SE PUEDE INSPECCIONAR/EDITAR A MANO.

### UPDATE
  - `process_video.cmd` Y `process_audio.cmd` SE DIVIDEN EN DOS ENTRADAS: `ASK` (PREGUNTAS/DETECCION -> ESCRIBE AL JOB) Y `RUN` (SOLO CODIFICACION, LEYENDO DEL JOB). LAS PREGUNTAS SE AGRUPAN AL INICIO Y LA CODIFICACION QUEDA DESATENDIDA.

### FIX
  - CLASIFICACION DE ESTADOS: `( set _need_prepare=1 )` GUARDABA UN ESPACIO FINAL (`1 `) Y LA COMPARACION `== "1"` FALLABA; LA FASE PREPARAR NO ARRANCABA. CORREGIDO CON `set "_need_prepare=1"`.

---

## VERSION 3.1 - 07/07/2026
### UPDATE
  - LA PREGUNTA "ES UN VIDEO DE ANIMACION" SOLO SE HACE CON `libx264`/`libx265`; CON LOS ENCODERS NVENC SE OMITE, YA QUE NO SOPORTAN `-tune animation` (ANTES ADEMAS FFMPEG DABA ERROR).
  - ROBUSTECER `AudioGetInitTimeOld.vbs`: VALIDAR ARGUMENTOS, NO CRASHEAR CON TOKENS VACIOS (DOBLES ESPACIOS) Y DEVOLVER EL PRIMER `pts_time`.
  - `AudioGetID.vbs` AHORA SOPORTA EL FORMATO MPEG-TS `Stream #0:2[0x1100](spa)` Y NO CRASHEA CON LINEAS INESPERADAS.
  - `AudioGetMaxVol.vbs` DETECTA EL SEPARADOR DECIMAL DEL LOCALE DE WINDOWS. EN UN WINDOWS EN INGLES APLICABA +50 dB EN VEZ DE +5 dB.

### FIX
  - `process_video.cmd`: NO PASAR `-refs` A LOS ENCODERS NVENC. MUCHAS GPUS NO SOPORTAN MULTIPLES FRAMES DE REFERENCIA Y FFMPEG ABORTABA CON "No capable devices found", DEJANDO EL VIDEO SIN CODIFICAR (`libx264`/`libx265` LO SIGUEN USANDO).
  - `process_video.cmd`: FALTABA EL `!` DE CIERRE EN `!tSizeReal_crop!`, POR LO QUE SIEMPRE SE DESACTIVABA EL RESIZE AL ELEGIR DETECCION DE BORDES AUNQUE NO SE DETECTARA NADA.
  - `process_video.cmd`: LA COMBINACION CROP+SCALE GENERABA UN `-vf` INVALIDO POR UN ESPACIO DESPUES DE LA COMA.
  - `process_video.cmd`: LA PREGUNTA DE TAMAÑO POR ARCHIVO LLAMABA A `src\opt_encoder.cmd`, QUE YA NO EXISTE (RENOMBRADO A `select_encoder_video.cmd`).
  - `process_audio.cmd`: LA RAMA `all_a_encoder=copy` NO HACIA `GOTO :eof` Y CAIA EN EL BLOQUE SIGUIENTE (PODIA PREGUNTAR REPROCESAR Y ACABAR EN ERROR).
  - `process_audio.cmd`: SI NO SE LOCALIZABA `pts_time`, LA COMPROBACION DE SINCRONIA ERA UN ERROR DE SINTAXIS QUE ABORTABA TODO EL SCRIPT.
  - `process_audio.cmd`: FILTERGRAPH DEL SILENCIO CORREGIDO (`aevalsrc=0|:` -> `aevalsrc=0:` Y `concat ... a=1` EN VEZ DEL ID DE PISTA).
  - `process_audio.cmd`: SE USABA EL ID DE PISTA COMO NUMERO DE FRAMES EN `-frames:a`; AHORA SE LEE SOLO EL PRIMER FRAME.
  - `process_multiplex.cmd`: EL CONTEO DE SUBTITULOS SE GUARDABA EN `_count_subtit` PERO SE LEIA `_count_steam_sub` (NUNCA DEFINIDA).
  - `process_multiplex.cmd`: EL CALCULO DEL TAMAÑO EN MB DABA "Missing operand" CON ARCHIVOS DE MENOS DE 1000 BYTES.
  - `gen_func.cmd`: FALTABA UN `)` EN `RUN_SUB_EXE` Y LA OPCION `MAX` ABRIA LA VENTANA MINIMIZADA CON UN ERROR "else NO SE RECONOCE".
  - `gen_func.cmd`: `%ERRORLEVEL%` DENTRO DE BLOQUES `( )` SE EXPANDIA ANTES DE EJECUTAR `mkdir`/`del`, DEVOLVIENDO RESULTADOS ANTIGUOS.
  - `gen_func.cmd` Y `fun_ffmpeg.cmd`: RUTAS SIN COMILLAS. CON UN PATH CON ESPACIOS `CHECK_FILE_AND_FIX` DABA FALSO "EXISTE" Y `COUNT_STREAM` DEVOLVIA 0.
  - `select_*.cmd`: LAS VARIABLES DE `set /p` NO SE LIMPIABAN; AL PULSAR ENTER SE REUTILIZABA EN SILENCIO LA RESPUESTA DEL ARCHIVO ANTERIOR.
  - `select_profile.cmd`: EN EL PERFIL CUSTOM, DEJAR EL TAMAÑO EN BLANCO VUELVE A SIGNIFICAR "PREGUNTAR EN CADA ARCHIVO" (SE CONVERTIA SIEMPRE A `NO`).
  - `AudioGetInitTime.vbs`: DEVOLVIA EL ULTIMO `pts_time` DEL LOG EN VEZ DEL PRIMERO, CALCULANDO MAL EL DESFASE AUDIO/VIDEO.
  - `Conversor.cmd`: DOS `else (` EN LINEA PROPIA (SINTAXIS INVALIDA) TRUNCABAN EL BUCLE PRINCIPAL; LA PASADA 2/2 Y EL GUARDADO A `Convertido` NO SE EJECUTABAN POR ARCHIVO.
  - `Conversor.cmd`: DOS `)` DE MAS CERRABAN ANTES DE TIEMPO LOS BLOQUES DE AUDIO Y VIDEO (EL ERROR DE AUDIO SALIA JUSTO CUANDO NO HABIA ERROR Y SE PROCESABAN ARCHIVOS YA CONVERTIDOS).
  - `Conversor.cmd`: TYPO `hvec_nvenc` -> `hevc_nvenc` (FFMPEG DABA "Unknown encoder").
  - `Conversor.cmd`: UN `set OutputVideoSize=1920:-1` OLVIDADO DE DEBUG MACHACABA TODOS LOS TAMAÑOS FULLHD Y `-s` NO ACEPTA ESE FORMATO.
  - `Conversor.cmd`: ELIMINAR `echo` + `pause` DE DEBUG QUE PARABAN CADA CODIFICACION H264 DE 2 PASADAS.
  - `Conversor.cmd`: LAS RAMAS NVENC USABAN `-x265-params` (OPCION EXCLUSIVA DE `libx265`); AHORA NVENC CODIFICA EN UNA SOLA PASADA.
  - `Conversor.cmd`: EL VALOR INICIAL `"0"` CON COMILLAS Y LAS COMPARACIONES SIN COMILLAS DEL DESFASE DE AUDIO Y DEL AJUSTE DE VOLUMEN PODIAN ABORTAR EL SCRIPT.
  - `Conversor.cmd`: LOS DEL DE `.info5`/`.info6` COMPROBABAN LA EXISTENCIA DEL ARCHIVO EQUIVOCADO (`.info3`).

---

## VERSION 3.0 - XX/12/2019
### NEW
  - CREAR `fun_ffmpeg.cmd` Y `fun_ffprobe.cmd` PARA FUNCIONES GENERICAS DE CADA PROGRAMA.
  - AÑADIR OPCION COPY EN EL PROCESO DE RECODIFICACION DEL AUDIO, SE CREA VARIABLE GENERAL `all_a_encoder`.
  - CREAR NUEVA FUNCION `RUN_SUB_EXE` EN `gen_fun.cmd` PARA IR ELIMINANDO LA ANTIGUA `RUN_EXE`. ESTA FUNCION TIENE SOPORTE PARA ESPECIFICAR QUEREMOS RETORNAR LOS DATOS CAPUTRADOS O ESPECIFICAR SI EL PROGRAMA QUE EJECUTAMOS SE VE EN PANTALLA COMPLETA O MINIMIZADA.
  - CREAR TOOL CONTROLS.EXE PARA PODER DESACTIVAR EL BOTON X DE LA VENTANA Y EVITAR QUE SE PUEDA CERRAR.

### UPDATE
  - LIMPIAR Y REORGANIZAR CODIGO.
  - MOVER `*.VBS` AL DIRECTORIO `\SRC`.
  - MOVER CHANGELOG FUERA DEL SCRIPT A `CHANGELOG.MD`
  - SEPARAR EL PROCESADO DEL AUDIO DEL CMD PRINCIPAL A `process_audio.cmd` Y SEGMENTAR EL CODIGO.
  - SEPARAR EL PROCESADO DEL SUBTITULOS DEL CMD PRINCIPAL A `process_sub.cmd.` Y SEGMENTAR EL CODIGO.
  - SEPARAR EL PROCESADO DEL VIDEO DEL CMD PRINCIPAL A `process_video.cmd.` Y SEGMENTAR EL CODIGO.
  - SEPARAR EL PROCESADO DE MULTIPLEXACION DE LAS PISTAS DEL CMD PRINCIPAL A `process_multiplex.cmd.` Y SEGMENTAR EL CODIGO.
  - REMPLAZAR VARIABLE `ffmpeg_cv` POR `all_v_encoder`.

### FIX
  - FUNCION `GetWidthByResolution` NO PROCESA BIEN LOS DATOS, NO RETORNA NUNCA NADA, SOLUCIONADO.
  - SOLUCIONAR PROBLEMA POR EL QUE SI PASAMOS A UNA FUNCION UN STRING CON EL SIMBOLO `!` SE PIERDE DICHO SIMBOLO.
    > ## EJEMPLO
    > PASAMOS > "ERROR: Algo ^(x68^)^^^^^^^!"<br/>
    > RECIVIMOS > "ERROR: Algo ^(x68^)^^"<br/>
    > SOLUCION OBTENIDA DE > https://superuser.com/questions/1292476/call-subroutine-where-parameter-contains-ampersand-in-batch-file
  - REMPLAZAR `::` POR `REM` YA QUE LOS PUNTOS DAN ERRORES EXTRAÑOS.

---

## VERSION 2.2 - 02/12/2019
### NEW
  - CREAR FUNCION `CHECK_DIR_AND_CREATE` COMPROBAR SI EXISTEN LOS DIRECTORIO Y CREARLOS SI NO EXISTEN.
  - CREAR FUNCION `CHECK_FILE_AND_FIX` PARA ELIMINAR CODIGO DUPLICADO.

### UPDATE
  - IMPLEMENTAR `CHECK_DIR_AND_CREATE` Y `CHECK_FILE_AND_FIX` PARA LIMPIAR CODIGO.

---

## VERSION 2.1 - 01/12/2019
### NEW
  - CREAR FUNCION PARA DESCARGAR ARCHIVOS DE INTERNET.
  - AL ARRANCAR COMPRUEBA SI EXISTEN LOS EJECUTABLES NECESARIOS Y SI ALGUNO NO EXISTE LO DESCARGA DE INTERNET.

---

## VERSION 2.0 - 28/11/2019
### NEW
  - AÑADIR MENU CON PERFILES PREDEFINIDOS DE LOS AJUSTES DE CODIFICACION, SE CREA UNA NUEVA VARIABLE `all_profile` DONDE SE ESPECIFICA QUE PERFIL SE HA CARGADO.
  - CREAR NUEVA VARIABLE all_a_hz PARA LA RECODIFICACION DEL ADUIO.

### UPDATE
  - SEGMENTAR EL CODIGO EN DISTINTOS ARCHIVOS PARA UN MEJOR MANTENIMIENTO.

---

## VERSION 1.9 - 18/04/2019
### NEW
  - AÑADIR A LA CODIFICAION DE VIDEO EL PARAMETOR DE `fps`.
  - AÑADIR INFORMACION DE DURACION DE VIDEO AL INICIAR EL PROCESO.
  - AÑADIR A `libx265` LA OPCION DE PROFILE Y LEVEL.
  - AÑADIR A LA FUNCION RUN_EXE LA OPOCION DE CAPTURAR STDOUT, STDERR O LAS DOS.
  - AÑADIR FUNCION FUN_FILE_DELETE_FILE PARA BORRAR ARCHIVOS.
  - AÑADIR MENSAJE PARA PODER ELIMINAR LA PISTA DE AUDIO O VIDEO QUE YA ESTA CODIFICADA Y PODER RECODIFICARLA OTRA VEZ.
  - AÑADIR MENSAJE PARA PODER DECIR SI EL VIDEO DE DE ANIMACION O NO PARA ESPECIFICAR ESE TUNE.

### UPDATE
  - MODIFICAR `libx265` PARA QUE EN VEZ DE USAR UN CFR FIJADO EN EL cmd USE EL QMIN QUE SE CONFIGURA EL INICIO DEL PROCESO.
  - MODIFICACIONES MENOS DE ALGUNOS TEXTOS INFORMATIVOS.
  - MODIFICAR EN `VideoSizeReal_Crop_ClearLog` PARA QUE RETORNE LA LISTA DE RESOLUCIONES DETECTADAS Y EL NUMERO DE VECES QUE SE HA DETECTADO CADA UNA. AHORA EL LISTADO DE RESOLUCIONES TAMBIEN SALE EL NUMERO DE VECES QUE SE HA DETECTADO ELIMINADO LAS QUE NO SE REPITEN MAS DE 5 VECES.
  - REDISEÑAR LA OBTENCION DE DATOS DE QMIN Y QMAX.
  - ACTUALIZAR ALGUNOS TEXTOS DE MENSAJES.

### FIX
  - BUG CODEC AAC, SI USAMOS EL CODEC ACC PARA CREAR ELSILENCIO Y UNIRLO A LA PISTA DE AUDIO ESTE AÑADE UNOS SEGUNDOS ENTRE LAS DOS PISTAS (SILENCIO + AUDIO) HACIENDO QUE SE EL. VIDEO Y EL AUDIO SE DESINCRONICE, SE USA UN ARTICHIO TEMPORAL WAv PARA AÑADIR EL SILENCIO Y ESE ARCHIVO ES EL QUE LUEGO SE RECODIFICA, CUANO SE SOLUCIONE EL BUG SE ELIMINARA ESE PROCESO TEMPORAL.
    > https://trac.ffmpeg.org/ticket/7846
  - CORREGUIR EN LA FUNCION FUN_CLEAR_TRIM_COMILLAS PARA QUE BORRE TODAS LAS COMILLAS AL COMIENZO Y AL FINAL CUANDO HAY MAS DE UNA.
  - CORREGUIR EN RUN_EXE EL REENVIO DE STDOUT Y STDERR CON EL COMANDO START.

### DEL
  - ELIMINAR EL PARAMETOR `-dn` DE LAS EJECUCIONES DE FFMPEG.

---

## VERSION 1.8 - 16/04/2019
### NEW
  - SEPARAR LA CODIFICACION DEL VIDEO Y LA CREACION DEL ARCHIVO FINAL EN DOS PROCESOS DISTINTOS `ProcessVideoFix` SIGUE ENCARGANDOSE DE PREPARAR LA PISTA DE VIDEO Y `ProcessMultiplexFiles` SE ENCARGA DE UNIR LA PISTA DE VIDEO+AUDIO+SUB.

### FIX
  - AÑADIR `^` A LOS SIMBOLOS ESPECIALES COMO LAS ADMIRACIONES `!`.
  - SOLUCIONAR PROBLEMA EN LA PISTA DE AUDIO YA QUE ADEMAS DEL AUDIO COPIABA TAMBIEN LOS CAPITULOS DEL MKV, AHORA YA SOLO SE COPIA LA PISTA DE AUDIO.

---

## VERSION 1.7 - 06/04/2019
### NEW
  - AÑADIR EN LA SECCION SELECT_ENCODE LA DETECCION SI ES H264 O H265 PARA PODER MODIFICAR LOS PARAMETROS DE CONFIGURACION SEGUN EL CODEC.
  - CREAR UN ARCHIVO DE DE PROCESADO NUEVO `_info_stream.txt` DONDE SE GUARDARAN TODAS LAS STREAMS QUE TIENGA EL ARCHIVO.
  - CREAR UNA NUEVA FUNCION FUN_CLEAR_TRIM_COMILLAS PARA ELIMINAR LAS COMILLAS A LA DRECHA HE IZQUIERDA, POR EJEMPLO EJEMPLO EN UN ARCHIVO "OUT.MKV" SE QUEDARIA OUT.MKV.

### UPDATE
  - ACTUALICAR ETIQUETAS DE POSICION EN LA SECCION SELECT.
  - ACTUALICAR LOS ECHO CON LA SECCION EN LA QUE SE ESTA EJECUTANDO [GLOBAL], [AUDIO], [VIDEO].
  - AHORA LAS STREAM DE CADA TIPO SE OBTIENE DE `_info_stream.txt` EN VEZ DE  `_info_ffmpeg.txt`.
  - IMPLEMENTAR RUN_EXE EN UNOS CUANTOS PROCESOS DE LA SECCION VIDEO.

### FIX
  - APLICAR ESTANDAR PARAMETROS INTERNOS.
  - ELIMINAR TODOS LOS `()` DE LOS ECHO Y CAMBIARLOS POR `[]` PARA EVITAR ERRORES.
  - MODIFICAR TANTO EN AUDIO COMO EN VIDIO UNOS IF AL COMIENZO QUE TE HACIAN UN EXIT SUB SIN EJECUTAR ENDLOCAL, AHORA ESOS IF SE EJECUTAN ANTES DE SETLOCAL.

---

## VERSION 1.6 - 04/04/2019
### NEW
  - CREAR AUDIOGETMAXVOL.VBS PARA COMPROBAR SI EL VOLUMEN ES CORRECTO O HAY QUE CORREGIRLO.
  - AÑADIR FUNCION DEBUG EN LOS ARCHIVOS `*.VBS`.
  - AÑADIR SOPORTE PARA LA CORRECCION DEL VOLUMEN DE LOS ARCHIVOS CON AACGAIN. PARA CAMBIAR ENTRE FFMPGE Y AACGAIN HAY QUE MODIFICAR LA VARIABLE `default_a_process`, DEFINIENDOLA COMO `set default_a_process=ACCGAIN` PARA ACCGAIN Y `set default_a_process=FFMPGE` PARA FFMPEG.
  - AÑADIR CONFIGURACION DEFAUL `default_a_hz` PARA LOS HZ EN LA RECODIFICACION DEL AUDIO.
  - AÑADIR LA DETECCION DE SI EL ARCHIVO TIENE PISTAS DE VIDEO, AUDIO O SUBTITULOS.

### UPDATE
  - ACTUALIZAR `AUDIOGETINITTIME.VBS` PARA QUE SE ENCARGE DE LEER EL LOG DE FFMPG Y OBTENER LOS SEGUNDOS DE DESFASE ENTRE AUDIO Y VIDEO.
  - UNIR LA RECODIFICACION DEL AUDIO Y EL AJUSTE DEL VOLUMEN EN EL MISMO PROCESO.
  - ELIMINAR LA DETECCION DE LA PISTA DE AUDIO DEL CMD, AHORA LA OBTIENE `AUDIOGETID.VBS`.
  - AÑADIR A LA FUNCION `RUN_EXE` LA OPCION DE QUE DATOS DESEAMOS CAPTURAR. SI QUEREMOS USAR `RUN > FILE` O `RUN 2> FILE`. 
POR DEFECTO SI NO SE PASA NADA SE USAR `2>` PARA USAR `>` TENDREMOS QUE PASARLE EL PAREMETRO `1` DE ESTA FORMA `RUN_EXE !FileOut! 1`.

### FIX
  - SOLUCIONAR ERROR QUE SE PRODUCIA SI EL ARCHIVO NO TENIA SUBTITULOS.

### DEL
  - ELIMINAR COMENTARIO NO NECESARIOS.

---

## VERSION 1.5 - 01/04/2019
### NEW
  - CREAR NUEVA FUNCION RUN_EXE PARA EJECUTAR PROGRAMA EXTERNOS Y CONTRLAR EL DEBUG.
  - AÑADIR RECODIFICACION Y CONTROL DEL VOLUMEN EN LA PISTA DE AUDIO.
  - AÑADIR MENU PARA PODER DEFINIR EL NUEVO BITRATE PARA LA PISTA DE AUDIO.
  - AÑADIR NUEVA OPCION DE ENCODE DE VIDEO LLAMADA COPY, DE ESTE MODO LA PISTA DE VIDEO SOLO SE COPIARA NO SE EFECTUARA NINGUNA MODIFICACION. ESTO PUEDE USARSE SI SOLO SE QUIERE RECODIFICAR LA PISTA DE AUDIO.

### UPDATE
  - ETIQUETAR PROCESOS DE VIDEO Y AUDIO.
  - IMPLEMENTAR NUEVA FUNCION `RUN_EXE` EN TODAS LAS EJECUCIONES EXTERNAS.
  - ELIMINAR DEBUGMODE `yesSTOP` Y CREAR 2 NUEVOS PARA `STOP AUDIO` Y `STOP VIDEO`.

### FIX
  - SOLUCIONAR PROBLEMA QUE PRODUCIA QUE NO SE COPIASEN LOS SUBTITULOS.

### DEL
  - ELIMINAR CODIGO OBSOLETO O NO NECESARIO.

---

## VERSION 1.4 - 31/03/2019
### NEW
  - AÑADIR PARAMETROS DE CONFIGURACION DE VALORES POR DEFECTO.
  - ACTUALIZAR SISTEMA DE DETECCION DE BORDES NUEVOS, AHORA SE ELIMINAN LAS RESOLUCIONES DUPLICADAS Y DEFINIMOS EL SEGUDO DONDE DESEAMOS INICIAR EL MUESTRESO Y LA DURACION DE DICHO MUESTREO.
  - AÑADOR SOPORTE PARA QMIN Y QMAX (DINAMICO) O UNA Q ESTATICA TANTO EN X264 COM X265.
  - AÑADIR -pix_fmt.
  - AÑADIR CONFIGURACIONES GLOBALES COMO SI DESEASMOS OMITIR LA DETECCION DE BORDE A TODOS LOS ARCHIVOS, O EL CAMBIO DE TAMAÑO.

### UPDATE
  - MOVER LOS CUADROS DE CONFIGURACION (CAMBIO TAMAÑO, PERFIL, ETC) A SUB FUNCIONES.
  - AHORA DEFINIMOS SI ESTAMOS EN MODO DEBUG CREANDO UN ARCHIVO EN EL DIRECTORIO DONDE ESTA EL SCRIPT `debug_on`.

---

## VERSION 1.3 - 03/02/2019
### NEW:
  - AÑADIR SOPORTE H265 - GPU.
  - AÑADIR SOPORTE H264 Y H265 - CPU.
  - AÑADIR SOPORTE PARA CAMBIAR DE TAMAÑO EL VIDEO.
  - AÑADIR OPCION DE SOLO RECODIFICAR SIN DETECTAR BORDE.
  - AÑADIR SECCION PARA RECODIFICAR AUDIO, AUNQUE NO HACE NADA AUN.
  - CREAR FUNCION `GetWidthByResolution` PARA OBTENER LA ANCHURA DESDE UNA RESOLUCION.

### UPDATE
  - LA VAR `!RunFunction!` SE HA ELIMINADO DE CADA ENCODER Y SE EJECUTA AL FINAL.
  - CADA ENCODER AJUSTAR LAS NUEVAS VAR `!video_f!`, `!video_e!`, `!audio_f!`, `!audio_e!`, QUE SE USARAN LUEGO AL EJECUTAR FFMPEG.

### DEL
  - ELIMINAR CODIGO QUE USA BITRATE MANUAL.

---

## VERSION 1.2 - 03/02/2019
### NEW
  - AÑADIR OPCION DEBUG PARA MOSTRAR MAS INFO `no/yes/yesSTOP`.
  - AÑADIR SOPORTE PARA ENCODING POR CPU `libx264`.
  - SI NO SE OBTIENE EL BITRATE CON `ffprobe` SE LLAMA A `MediaInfo` PARA OBTENER INFO DEL BITRATE.

### UPDATE
  - REORGANIZAR CODIGO.

### FIX
  - ELIMINAR LAS DOS PASADAS CON CODIFICADOR NVIDIA YA QUE NO LO SOPORTA, AÑADIR SOPORTE.

---

## VERSION 1.1 - 28/01/2019
### NEW
  - AÑADIR OPACION PARA PODER EFECTUAR UN NUEVO MUESTRESO DE BORDES CON PARAMETROS DISTINTOS.

---

## VERSION 1.0 - 19/01/2019
### NEW
  - CREAR SCRIPT, SOPORTE UNICAMENTE A GPU `h264_nvenc`.
