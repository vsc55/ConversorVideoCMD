# Comandos de las herramientas por fase

Comandos de **ffmpeg / ffprobe / ffplay / aacgain** que se lanzan en cada fase. Todos se ejecutan con las herramientas de la versión en uso (`$ctx.FFmpeg`, `$ctx.FFprobe`, `$ctx.FFplay`, `$ctx.AacGain`), que apuntan a `tools\<app>\<version>\<plataforma>\`. Los placeholders (`<...>`) provienen del contexto/perfil/job.

Leyenda de placeholders comunes:
- `<file>` = ruta del vídeo original (`Original\...`).
- `<N>` = `$ctx.Threads` (`encode.threads`, 0 = auto).
- `<fps>` = `$ctx.Fps` (`encode.fps`).
- `<hz>` = bitrate/samplerate de audio (`Profile.AudioHz` o `encode.audioHz`).
- `<start>`/`<dur>` = `border.start` / `border.duration`.

---

## 1. Análisis de streams (ffprobe)

`Get-MediaInfo` — obtiene todo en JSON (sustituye a los `.vbs`/`findstr` antiguos):

```
ffprobe -v quiet -print_format json -show_streams -show_format <file>
```

El JSON resultante alimenta la selección de vídeo/audio/subtítulos y el resumen final.

---

## 2. Detección de bordes negros (`Find-CropDetect`)

Escanea un tramo con `cropdetect` y se queda con el recorte más frecuente (`W:H:X:Y`):

```
ffmpeg -hide_banner -ss <start> -to <start+dur> -i <file> -vf cropdetect -f null -
```

De la salida (`stderr`) se extraen las líneas `crop=W:H:X:Y` y se agrupan; gana la más repetida.

---

## 3. Previsualización de bordes (`Show-Preview`, ffplay)

Reproduce un tramo para revisar visualmente. Primero el original, luego con el recorte aplicado:

```
# Original
ffplay -hide_banner -loglevel error -ss <start> -t <seg> -autoexit -window_title "ORIGINAL" <file>

# Con recorte
ffplay -hide_banner -loglevel error -ss <start> -t <seg> -autoexit -vf "crop=<W:H:X:Y>" -window_title "RECORTADO <crop>" <file>
```

La preview se ejecuta en la consola principal (no en ventana aparte).

---

## 4. Sincronía: desfase inicial del audio (`Get-AudioInitDelay`)

Lee el `pts_time` del primer frame de la pista de audio seleccionada (índice `<i>`):

```
ffmpeg -hide_banner -i <file> -map 0:<i> -af ashowinfo -f alaw -frames:a 1 -y NUL
```

Si `pts_time > 0`, el audio empieza más tarde que el vídeo y se ofrece añadir ese silencio al inicio.

---

## 5. Audio: generar silencio + pista (solo si hay sincronía)

Cuando hay que compensar `<sync>` segundos, se genera un WAV estéreo (silencio + audio) para recodificarlo después. Evita un bug del AAC que desincroniza al concatenar:

```
ffmpeg -hide_banner -y -i <file> -filter_complex \
  "[0:<i>]aformat=channel_layouts=stereo[a2];aevalsrc=0:d=<sync>:sample_rate=<hz>:channel_layout=stereo[sil];[sil][a2]concat=n=2:v=0:a=1[out]" \
  -map "[out]" <name>_concat.wav
```

> Nota: se referencia `[0:<i>]` (índice concreto), no `[0:a]` (que sería la primera pista y podría no ser la seleccionada).

---

## 6. Audio: medición de volumen (`Get-MaxVolume`, método `peak`)

Mide el pico (`max_volume`, en dB) independiente del locale:

```
ffmpeg -hide_banner <input> -af volumedetect -f null -
```

Donde `<input>` es `-i <file> -map 0:<i> ...` o `-i <name>_concat.wav -map 0:a` si hubo sincronía.

---

## 7. Audio: codificación a AAC con normalización de volumen (`Invoke-AudioRun`)

Base común del comando (la fuente es `<file>` o el WAV sincronizado):

```
ffmpeg -hide_banner -y -threads <N> -i <fuente> <VOLUMEN> -c:a aac -aac_coder twoloop -ac 2 -ar <hz> [-b:a <bitrate>] <name>.m4a
```

La parte `<VOLUMEN>` depende de `volume.method` (`$ctx.VolumeMethod`):

### peak (por defecto)
Mide el pico y lo lleva a 0 dB con el filtro `volume`:
```
-filter_complex "[<label>]volume=<gain>dB:precision=fixed[a]" -map "[a]"
```
`<gain> = -max_volume` (redondeado). Si el pico ya es 0 no se aplica filtro.

### loudnorm (EBU R128)
Normalización de sonoridad con `I`/`TP`/`LRA` de `config.volume.loudnorm`:
```
-filter_complex "[<label>]loudnorm=I=<I>:TP=<TP>:LRA=<LRA>[a]" -map "[a]"
```

### aacgain (ReplayGain, sin pérdida)
Se codifica **sin** ajuste y luego se aplica la ganancia sobre el `.m4a` ya codificado, sin recodificar:
```
aacgain /r /c /q <name>.m4a
```

`<label>` es `0:a` si venimos del WAV sincronizado, o `0:<i>` en caso normal.

---

## 8. Vídeo: codificación (`Invoke-VideoRun` + `Get-VideoArgs`)

Comando completo (sin audio ni subtítulos; se añaden en el multiplexado):

```
ffmpeg -hide_banner -y -threads <N> -i <file> -an -sn -map_chapters -1 \
  -metadata title= -metadata:s:v title= -metadata:s:v language=und \
  [-vf "<filtros>"] <ARGS_ENCODER> -map 0:0 -f matroska <name>.mkv
```

`<filtros>` combina recorte y escalado si aplican: `crop=<W:H:X:Y>,scale=<resize>`.

`<ARGS_ENCODER>` según el encoder del perfil ([perfiles.md](perfiles.md)):

### hevc_nvenc (H.265 GPU)
```
-c:v hevc_nvenc -tier high -pix_fmt <p010le|yuv420p> -preset slow
[-profile:v <profile>] [-level:v <level>]
<-rc constqp -qp <q>  |  -qmin <qmin> -qmax <qmax>>
-rc-lookahead:v 32 -r <fps> -movflags +faststart
```
`p010le` si el profile es `main10`, si no `yuv420p`. **No** se pasa `-refs` (muchas GPUs abortan con "No capable devices found").

### h264_nvenc (H.264 GPU)
```
-c:v h264_nvenc -pix_fmt yuv420p -preset slow
<-rc constqp -qp <q>  |  -qmin <qmin> -qmax <qmax>>
-rc-lookahead:v 32 -r <fps> -movflags +faststart
```

### libx264 (H.264 CPU)
```
-c:v libx264 -pix_fmt yuv420p [-crf <crf>] -preset slow [-tune animation] -refs 4 -r <fps> -movflags +faststart
```

### libx265 (H.265 CPU)
```
-c:v libx265 -pix_fmt yuv420p [-crf <crf>] -preset slow [-profile:v <p>] [-level:v <l>] [-tune animation] -refs 4 -r <fps> -movflags +faststart
```

Notas:
- `-tune animation` solo se añade si en PREPARAR se respondió que el vídeo es animación (solo se pregunta con `libx264`/`libx265`).
- `constqp` se usa cuando `qmin == qmax`; si no, `-qmin`/`-qmax`.

---

## 9. Multiplexado final (`Invoke-Multiplex`)

Une vídeo (temporal recodificado, o el original si es `copy`) + audio (`.m4a`, o el del original si es `copy`) + subtítulos seleccionados, copiando streams (sin recodificar):

```
ffmpeg -hide_banner -y -threads <N> \
  -i <video>            # input 0 (temporal .mkv o el original)
  [-i <name>.m4a]       # input 1 (audio recodificado, si existe)
  [-i <file>]           # input N (para los subtítulos del original)
  -metadata title= -metadata:s:v title= -metadata:s:v language=und \
  -map 0:v:0 \
  <-map 1:a:0 -metadata:s:a title= -metadata:s:a language=spa  |  -map 0:a:0> \
  # por cada subtítulo seleccionado:
  -map <sub_input>:<idx>? -metadata:s:s:<n> language=<lang> -metadata:s:s:<n> title=<"Forzados"|""> -disposition:s:<n> <default+forced|0> \
  -c:v copy -c:a copy [-c:s copy] -f matroska <name>_fix.mkv
```

Subtítulos: se mantiene el completo + los forzados del idioma preferido; el título de la pista se pone a `Forzados` en las forzadas y en blanco en las completas.

---

## 10. Lectura de versión instalada (`Get-CvToolInstalledVersion`)

Para confirmar qué versión hay en una carpeta se ejecuta la propia app:

```
ffmpeg.exe -version      # regex: ffmpeg version (\d+\.\d+(?:\.\d+)?)
aacgain.exe /v           # regex: [Vv]ersion (\d+\.\d+(?:\.\d+)?)
```

---

## Modo debug

Con `behavior.debug = true` o el marcador `debug_on`, antes de cada ejecución se **imprime el comando completo** y se pide ENTER para continuar; además las codificaciones van a la ventana principal (no a una aparte).
