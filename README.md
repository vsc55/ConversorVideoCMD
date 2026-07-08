# ConversorVideoCMD

Conversor/recodificador de vídeo por lotes para Windows, escrito en **PowerShell 5.1**, que usa **FFmpeg** como motor. Diseño modular en `lib\` y toda la configuración en `config.json`.

Recodifica a **MKV** (H.265/H.264 por GPU NVIDIA o CPU), con detección y recorte de bandas negras, selección de audio/subtítulos por idioma, corrección de sincronía y normalización de volumen.

> La versión antigua en Batch (CMD + VBScript) se conserva en la rama **`v3.x`**.

***

## Puesta en marcha

1. Copia tus vídeos en la carpeta `Original\` (admite `.avi`, `.flv`, `.mp4`, `.mov`, `.mkv`).
2. Doble clic en **`Convert.cmd`**.
   - Si falta FFmpeg, se ofrece a **descargarlo** (build de [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg), verificado con SHA256).
   - Primero **pregunta** la configuración de cada archivo; luego **codifica** sin más preguntas.
3. El resultado queda en `Convertido\<nombre>_fix.mkv`.

`Convert.cmd` solo lanza `Convert.ps1` con `-ExecutionPolicy Bypass` (no cambia la política del sistema) y pone la consola en UTF-8.

Para gestionar versiones de FFmpeg/aacgain o editar la configuración cómodamente: **`setup.cmd`**.

## En qué consiste

Modelo **preparar → procesar**:

- **PREPARAR**: elige un perfil y, por cada vídeo, pregunta/detecta todo (bordes con preview, resize, animación, pista de audio, sincronía, subtítulos) y lo congela en `Proceso\<nombre>.job.json`.
- **WORKER**: codifica cada preparado de forma desatendida (audio → vídeo → multiplexado) y deja el MKV en `Convertido\`.
- **Paralelo**: cuando todos tienen `.job`, puedes abrir varias ventanas de `Convert.cmd`; cada una toma archivos libres mediante un lock atómico.

## Requisitos

- Windows de 64 bits con **PowerShell 5.1** (el que trae Windows).
- FFmpeg/FFprobe/FFplay: se descargan solos a `tools\ffmpeg\<version>\<plataforma>\` (o instálalos con `setup.cmd`).
- Para los perfiles NVENC, una GPU NVIDIA compatible con la versión de FFmpeg elegida.

## Estructura

| Carpeta / fichero | Uso |
|---|---|
| `Convert.cmd` / `setup.cmd` | Lanzadores del conversor / de la utilidad de gestión. |
| `Convert.ps1` | Orquestador (clasificar / preparar / worker). |
| `setup.ps1` | Herramientas + editor de `config.json` + limpieza. |
| `config.json` | Toda la configuración. |
| `lib\` | Módulos PowerShell (`*.psm1`). |
| `Original\` | Vídeos de entrada. |
| `Proceso\` | Trabajo: `*.job.json`, `*.lock`, temporales. |
| `Convertido\` | Resultado final (`*_fix.mkv`). |
| `tools\<app>\<ver>\<plat>` | Ejecutables (FFmpeg, aacgain). |
| `docs\` | Documentación detallada. |

## 📖 Documentación

La documentación técnica y detallada (cómo trabaja, flujos, diagramas y **los comandos exactos** que se lanzan en cada fase) está en **[`docs/`](docs/README.md)**:

- [Arquitectura](docs/arquitectura.md) — módulos, contexto, fuentes de verdad.
- [Flujo de trabajo](docs/flujo.md) — clasificar → preparar → worker, con diagramas.
- [Comandos de las herramientas](docs/comandos.md) — ffmpeg/ffprobe/ffplay/aacgain por fase.
- [Perfiles](docs/perfiles.md) — perfiles 1–7 y custom.
- [Configuración](docs/configuracion.md) — referencia de `config.json`.
- [Herramientas](docs/herramientas.md) — versiones, plataforma, descargas y `setup`.
- [Jobs](docs/jobs.md) — formato del job, lock y temporales.
