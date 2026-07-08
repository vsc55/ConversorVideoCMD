# Flujo de trabajo

El conversor sigue un modelo **productor/consumidor** en dos fases: primero se **prepara** (se pregunta todo y se congela en un job), luego se **procesa** (worker desatendido).

## Visión global

```mermaid
flowchart TD
    A["Convert.cmd"] --> B["Convert.ps1"]
    B --> CTX["New-CvContext (lee config.json)"]
    CTX --> APAR["Set-CvAppearance (colores/fuente/ventana)"]
    APAR --> TOOL{"¿ffmpeg 'selected' instalado?"}
    TOOL -- "no + soportado" --> INST["Select-CvToolVersion + Install-CvTool"]
    TOOL -- "no + no soportado" --> ERR["ERROR: plataforma no soportada / exit"]
    TOOL -- "sí" --> SRC["Get-SourceFiles (Original\\)"]
    INST --> SRC
    SRC --> CLASIF{"¿algún archivo SIN .job y SIN convertir?"}
    CLASIF -- "sí" --> PREP["FASE PREPARAR"]
    CLASIF -- "no" --> WORK["FASE WORKER"]
    PREP --> WORK
    WORK --> END["[END] No quedan archivos libres"]
```

## Parámetros de lanzamiento

`Convert.cmd` (y `setup.cmd`) reenvían sus argumentos a los `.ps1`:

| Parámetro | Vale para | Uso |
|---|---|---|
| `-Config <ruta>` | `Convert` y `setup` | Fichero de configuración a usar en vez de `config.json` junto al programa. Admite ruta **absoluta** o **relativa** al directorio actual. Permite mantener varios perfiles de config (p. ej. `Convert.cmd -Config perfiles\anime.json`). Los workers extra heredan el mismo `-Config`. Si la ruta no existe, se avisa y se usan los valores por defecto. |
| `-WorkerOnly` | `Convert` | Salta la fase PREPARAR y entra directo como worker (lo usan las ventanas extra que se abren al pedir varios workers en paralelo). |

## Clasificación

Al arrancar, tras comprobar herramientas, se recorren los vídeos de `Original\` y se decide si hace falta preparar:

```powershell
foreach ($f in $files) {
    $name = $f.BaseName
    if (Test-Path -LiteralPath (Get-OutputPath $ctx $name)) { continue }   # ya convertido
    if (-not (Test-CvJob -Context $ctx -Name $name)) { $needPrepare = $true; break }
}
```

- Un archivo **necesita prepararse** si NO está convertido (no existe `Convertido\<nombre>_fix.mkv`) **y** no tiene `Proceso\<nombre>.job.json`.
- Si todos tienen job (o están convertidos) → se salta PREPARAR y se entra directo como WORKER. Esto permite abrir **varias ventanas**: la primera prepara, las demás entran como workers.

## Fase PREPARAR

Se elige **un** perfil ([perfiles.md](perfiles.md)) que se aplica a todo el lote, y para cada archivo sin preparar se hacen las preguntas/detecciones y se escribe el job.

```mermaid
flowchart TD
    P0["Select-Profile (una vez para el lote)"] --> P1["Para cada archivo sin .job:"]
    P1 --> P2["Get-MediaInfo (ffprobe)"]
    P2 --> P3["Invoke-VideoAsk: bordes + preview, resize, animación"]
    P3 --> P4["Invoke-AudioAsk: pista, sincronía"]
    P4 --> P5["Select-Subtitles: idioma, forzados"]
    P5 --> P6["Write-CvJob → Proceso\\&lt;nombre&gt;.job.json"]
    P6 --> P1
```

El job **congela**: el perfil completo, las respuestas del usuario (índice de vídeo, recorte, resize, animación, índice de audio, sincronía, subtítulos) y **las versiones de ffmpeg/aacgain** en uso. Es autosuficiente: el worker no depende de la config global. Ver [jobs.md](jobs.md).

**Salida por archivo:** en uso normal, PREPARAR imprime primero el **nombre del archivo** como cabecera (`- <nombre>`) y, **debajo e indentadas**, las preguntas interactivas (selección de pista de vídeo/audio/subtítulo, bordes, animación, sincronía) — así siempre se sabe de qué archivo son. Al terminar, una línea de estado: `Preparado ✓` (verde), `Preparado (seleccion manual) ✓` (amarillo, si hubo **cualquier** pregunta) o `No se pudo preparar ✗` (rojo, si ffprobe no puede leerlo). Los avisos (p. ej. **varias pistas de vídeo** o **audio sin idioma preferido**) salen como *badge* `▐ AVISO - … ▌`. En **modo debug** (`behavior.debug` / marcador `debug_on`) se ve el detalle completo (marco, tamaño/duración, y los `[INFO]` de audio/subtítulo/vídeo).

### Workers en paralelo

Al terminar PREPARAR, se pregunta **cuántos workers codificarán en paralelo** (contando esta ventana; ENTER usa el valor por defecto `behavior.workers`, 2). Si se piden N, esta ventana codifica y se abren **N−1 ventanas nuevas** (`Convert.cmd -WorkerOnly`): como ya está todo preparado, entran directas a codificar sin preguntar y se reparten los archivos por el lock. Con `-WorkerOnly` una ventana **salta PREPARAR** y va directa a la fase WORKER.

Con **0** solo se prepara y se **sale** sin codificar: los `.job.json` quedan listos y la conversión se lanza después abriendo `Convert.cmd` (una o varias ventanas) cuando se quiera.

### Regla del prefijo `_`

Si el nombre del archivo empieza por `_`, se **fuerza** la detección de bordes aunque el perfil (o la respuesta) diga "sin bordes". Pensado para marcar archivos con bordes que hay que limpiar sí o sí.

## Fase WORKER

Bucle que recorre los archivos preparados y codifica el siguiente libre, reclamándolo con un lock.

```mermaid
flowchart TD
    W0["while (hubo trabajo)"] --> W1["Para cada archivo de Original\\:"]
    W1 --> W2{"¿ya convertido? ¿tiene .job? ¿marcado skip?"}
    W2 -- "no procesable" --> W1
    W2 -- "ok" --> W3{"Enter-Lock (fichero .lock, atómico)"}
    W3 -- "lo tiene otro worker" --> W1
    W3 -- "reclamado" --> W4["Read-CvJob"]
    W4 --> W5["Confirm-CvTool: instala la versión del job si falta"]
    W5 --> W6["New-CvToolContext: contexto con esa versión"]
    W6 --> INFO["[INFO] Resolución + Duración del archivo"]
    INFO --> A["Invoke-AudioRun"]
    A --> V["Invoke-VideoRun"]
    V --> M["Invoke-Multiplex → Convertido\\&lt;nombre&gt;_fix.mkv (+ mkvpropedit)"]
    M --> OK{"¿salida creada?"}
    OK -- "sí" --> CLEAN["Remove-CvTemps + Remove-CvJob + resumen"]
    OK -- "no" --> RETRY["se reintentará"]
    CLEAN --> UNLOCK["Exit-Lock (finally)"]
    RETRY --> UNLOCK
    UNLOCK --> W1
```

Al iniciar cada archivo, el worker muestra su **resolución y duración** (útil para estimar cuánto durará la codificación). En **uso normal**, cada paso se muestra como una línea compacta `- <acción>... ✓` (o `✗` en rojo si falla), y el resumen final va enmarcado con guiones. En **modo debug** se ven los logs detallados por sección, los comandos exactos y las confirmaciones.

Orden de codificación por archivo: **audio → vídeo → multiplexado**. El audio se recodifica a un `.m4a` temporal, el vídeo a un `.mkv` temporal, y el multiplexado los une con los **subtítulos** y los **adjuntos** conservados del original en `Convertido\<nombre>_fix.mkv`; después limpia los metadatos heredados y quita las etiquetas `DURATION` con **mkvpropedit**.

Ver los comandos exactos en [comandos.md](comandos.md).

## Paralelismo y lock

- El reclamo de cada archivo es un **fichero-lock** `Proceso\<nombre>.lock` creado con `FileMode.CreateNew` (falla atómicamente si ya existe). Solo un worker gana.
- Se pueden lanzar **varias ventanas** (`Convert.cmd`) a la vez: cuando todos los archivos tienen `.job`, cada ventana entra como worker y se reparten los archivos por el lock.
- El lock se libera siempre en el `finally`, incluso si la codificación falla. Si un worker muere a mitad, otro puede **robar el lock caducado** (guarda `PID`+equipo; ver [jobs.md](jobs.md)).
- **Reintentos con límite**: un archivo que falla se reintenta hasta un máximo (`behavior.retries`, por defecto 2); superado, se **abandona** (se marca en `skip`). Los ilegibles se descartan y un error inesperado se captura por archivo (no aborta el lote). Esto evita el bucle infinito con inputs corruptos o ffmpeg que no arranca.
- La codificación de audio/vídeo debe terminar con éxito (ffmpeg código 0 + salida no vacía) para que se multiplexe; si no, el archivo cuenta como fallo (no se genera un MKV con vídeo sin recodificar).

## Protección de la ventana

Durante el proceso se **desactiva el botón X** de la consola (API nativa de Windows, sustituye al antiguo `controls.exe`) para no cerrarla por error. Un `trap` y el final del script garantizan reactivarlo. Configurable con `behavior.lockCloseButton`.
