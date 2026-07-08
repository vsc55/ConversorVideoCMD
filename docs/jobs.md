# Jobs, lock y temporales

Todo el estado de trabajo vive en `Proceso\`.

## El job (`Proceso\<nombre>.job.json`)

En PREPARAR se escribe un job **autosuficiente** por archivo: lleva el perfil congelado, las respuestas del usuario y las versiones de herramientas. El worker no depende de la config global para procesarlo.

Ejemplo:

```json
{
  "file": "D:\\...\\Original\\Video [01].mkv",
  "profile": { "Name": "3", "VideoEncoder": "hevc_nvenc", "VideoProfile": "main10", "VideoLevel": "5", "Qmin": 1, "Qmax": 23, "DetectBorder": true, "ChangeSize": "", "AudioEncoder": "aac_coder", "AudioBitrate": "192k", "AudioHz": 44100 },
  "ffmpegVersion": "7.1.1",
  "aacgainVersion": "2.0.0",
  "video": { "skip": false, "crop": "1920:800:0:140", "resize": "", "anim": false },
  "audio": { "skip": false, "index": 1, "is51": true, "sync": 0 },
  "subtitles": [ { "Index": 3, "Lang": "spa", "Default": false, "Forced": true } ]
}
```

| Campo | Origen | Uso en el worker |
|---|---|---|
| `file` | ruta absoluta | Entrada de ffmpeg. |
| `profile` | perfil elegido | Argumentos de codec/audio. |
| `ffmpegVersion` / `aacgainVersion` | `selected` al preparar | Versión a usar (se instala si falta). |
| `video` | `Invoke-VideoAsk` | `crop`, `resize`, `anim`, o `skip` (copy). |
| `audio` | `Invoke-AudioAsk` | `index` de pista, `sync` (silencio), o `skip`. |
| `subtitles` | `Select-Subtitles` | Pistas a mapear con idioma/disposición/título. |

### Escritura atómica

`Write-CvJob` escribe primero un `.tmp` (UTF-8 **sin BOM**) y luego lo renombra con operaciones `.NET` de **ruta literal**:

```powershell
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
if ([System.IO.File]::Exists($final)) { [System.IO.File]::Delete($final) }
[System.IO.File]::Move($tmp, $final)
```

Se usan operaciones literales porque los nombres suelen llevar **corchetes** (`[01]`, `[1080p]`…), que PowerShell interpretaría como comodines en `-Path`/`Test-Path`. Todas las funciones de job (`Test-CvJob`, `Read-CvJob`, `Remove-CvJob`) usan `-LiteralPath`.

> Las funciones van con prefijo `Cv` (`*-CvJob`) para no chocar con los cmdlets nativos de PowerShell `*-Job` (`Get-Job`, `Remove-Job`…).

## El lock (`Proceso\<nombre>.lock`)

Reclamo atómico entre workers. Se crea un fichero con `FileMode.CreateNew`, que **falla si ya existe** (mutex de una sola operación):

```powershell
$fs = [System.IO.File]::Open($lock, [FileMode]::CreateNew, [FileAccess]::Write, [FileShare]::None)
$fs.Close()   # Enter-Lock devuelve $true; si lanza, otro worker lo tiene
```

- Solo un worker gana el archivo; los demás siguen al siguiente.
- Se libera siempre en el `finally` (`Exit-Lock` → `[IO.File]::Delete`), incluso si la codificación falla.
- Es literal-safe (compatible con nombres con corchetes).

## Temporales (`Get-CvTempPaths`)

Durante la codificación de un archivo se generan, en `Proceso\`:

| Fichero | Lo crea | Contenido |
|---|---|---|
| `<nombre>.mkv` | `Invoke-VideoRun` | Vídeo recodificado (temporal). |
| `<nombre>.m4a` | `Invoke-AudioRun` | Audio recodificado (temporal). |
| `<nombre>_concat.wav` | `Invoke-AudioRun` (si hay sincronía) | Silencio + pista, para recodificar. |
| `<nombre>.job.json.tmp` | `Write-CvJob` | Job a medio escribir (si quedó colgado). |

Todos comparten la **fuente única** `Get-CvTempPaths`, que usan tanto los que los crean (Video/Audio/Multiplex) como el que los limpia.

Al terminar bien un archivo, `Remove-CvTemps` los borra por **ruta exacta** (no comodines, para no tocar temporales de otro archivo cuyo nombre empiece igual), salvo que exista el marcador `keep_temp` (`behavior.cleanTemps = false`).

## Ciclo de vida en `Proceso\`

```mermaid
sequenceDiagram
    participant P as PREPARAR
    participant W as WORKER
    participant FS as Proceso\
    P->>FS: escribe &lt;nombre&gt;.job.json
    W->>FS: crea &lt;nombre&gt;.lock (atómico)
    W->>FS: genera .m4a / .mkv / _concat.wav
    W->>FS: (multiplex) → Convertido\&lt;nombre&gt;_fix.mkv
    W->>FS: Remove-CvTemps (borra temporales)
    W->>FS: Remove-CvJob (borra .job.json)
    W->>FS: Exit-Lock (borra .lock)
```
