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

El job **congela**: el perfil completo, las respuestas del usuario (recorte, resize, animación, índice de audio, sincronía, subtítulos) y **las versiones de ffmpeg/aacgain** en uso. Es autosuficiente: el worker no depende de la config global. Ver [jobs.md](jobs.md).

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
    W6 --> A["Invoke-AudioRun"]
    A --> V["Invoke-VideoRun"]
    V --> M["Invoke-Multiplex → Convertido\\&lt;nombre&gt;_fix.mkv"]
    M --> OK{"¿salida creada?"}
    OK -- "sí" --> CLEAN["Remove-CvTemps + Remove-CvJob + resumen"]
    OK -- "no" --> RETRY["se reintentará"]
    CLEAN --> UNLOCK["Exit-Lock (finally)"]
    RETRY --> UNLOCK
    UNLOCK --> W1
```

Orden de codificación por archivo: **audio → vídeo → multiplexado**. El audio se recodifica a un `.m4a` temporal, el vídeo a un `.mkv` temporal, y el multiplexado los une (con los subtítulos del original) en `Convertido\<nombre>_fix.mkv`.

Ver los comandos exactos en [comandos.md](comandos.md).

## Paralelismo y lock

- El reclamo de cada archivo es un **fichero-lock** `Proceso\<nombre>.lock` creado con `FileMode.CreateNew` (falla atómicamente si ya existe). Solo un worker gana.
- Se pueden lanzar **varias ventanas** (`Convert.cmd`) a la vez: cuando todos los archivos tienen `.job`, cada ventana entra como worker y se reparten los archivos por el lock.
- El lock se libera siempre en el `finally`, incluso si la codificación falla.
- Si un archivo no se puede procesar (p. ej. su ffmpeg no se puede instalar), se marca en un conjunto `skip` para no reintentarlo en bucle.

## Protección de la ventana

Durante el proceso se **desactiva el botón X** de la consola (API nativa de Windows, sustituye al antiguo `controls.exe`) para no cerrarla por error. Un `trap` y el final del script garantizan reactivarlo. Configurable con `behavior.lockCloseButton`.
