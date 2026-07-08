# Documentación — ConversorVideoCMD

Documentación técnica y detallada del conversor. Para la visión general y la puesta en marcha, ver el [README principal](../README.md).

## Índice

| Documento | Contenido |
|---|---|
| [arquitectura.md](arquitectura.md) | Estructura de ficheros, módulos, el contexto (`$ctx`), y las "fuentes únicas de verdad". |
| [flujo.md](flujo.md) | Cómo trabaja: clasificar → preparar → worker. Diagramas, locks, paralelismo, regla del prefijo `_`. |
| [comandos.md](comandos.md) | **Los comandos exactos** de ffmpeg/ffprobe/ffplay/aacgain que se lanzan en cada fase. |
| [perfiles.md](perfiles.md) | Perfiles de codificación 1–7 y el perfil custom. |
| [configuracion.md](configuracion.md) | Referencia completa de `config.json` (todas las secciones y claves). |
| [herramientas.md](herramientas.md) | Sistema de herramientas versionadas (`tools\<app>\<version>\<plataforma>`), descargas, plataforma y `setup.ps1`. |
| [jobs.md](jobs.md) | Formato del `.job.json`, el lock atómico y los ficheros temporales. |

## Resumen en una frase

`Convert.cmd` lanza `Convert.ps1`, que en una primera pasada **pregunta** toda la configuración de cada vídeo de `Original\` y la congela en un `Proceso\<nombre>.job.json`; después, en la misma ventana (o en otras ventanas en paralelo), un **worker** codifica cada archivo preparado de forma desatendida, reclamándolo con un lock atómico.

```mermaid
flowchart LR
    O[Original/*.mkv] -->|PREPARAR| J[Proceso/*.job.json]
    J -->|WORKER| C[Convertido/*_fix.mkv]
```
