# Documentación — ConversorVideoCMD

Documentación técnica y detallada del conversor. Para la visión general y la puesta en marcha, ver el [README principal](../README.md).

## Índice

| Documento | Contenido |
|---|---|
| [ref-arquitectura.md](ref-arquitectura.md) | Estructura de ficheros, módulos, el contexto (`$ctx`), y las "fuentes únicas de verdad". |
| [ref-flujo.md](ref-flujo.md) | Cómo trabaja: clasificar → preparar → worker. Diagramas, locks, paralelismo, regla del prefijo `_`. |
| [ref-comandos.md](ref-comandos.md) | **Los comandos exactos** de ffmpeg/ffprobe/ffplay/aacgain que se lanzan en cada fase. |
| [ref-perfiles.md](ref-perfiles.md) | Perfiles de codificación 1–7, los propios de `config.json` (sección `profiles`), el perfil custom y las preguntas por archivo (vídeo/audio/subs/bordes). |
| [ref-configuracion.md](ref-configuracion.md) | Referencia completa de `config.json` (todas las secciones y claves). |
| [ref-herramientas.md](ref-herramientas.md) | Sistema de herramientas versionadas (`tools\<app>\<version>\<plataforma>`), descargas, plataforma y `setup.ps1`. |
| [ref-jobs.md](ref-jobs.md) | Formato del `.job.json`, el lock atómico y los ficheros temporales. |
| [ref-pruebas.md](ref-pruebas.md) | Muestras de test (`test\`): qué prueba cada una, resultado esperado, cómo regenerarlas y las fuentes/licencias. |
| [explica-control-tasa.md](explica-control-tasa.md) | Qué son **CRF**, **QMIN/QMAX** y **QP**, para qué sirven, cómo se traducen a ffmpeg y cómo elegir valores (escala 0–51). |
| [explica-deteccion-bordes.md](explica-deteccion-bordes.md) | Detección de bordes negros: escaneo `cropdetect` multipunto, reparto por el vídeo, y la auto-aceptación por votos (% + margen) con matriz de decisión. |
| [caso-rendimiento-subtitulos.md](caso-rendimiento-subtitulos.md) | Nota técnica: diagnóstico de la lentitud de PREPARAR con subtítulos (conteo de cues vía tag `NUMBER_OF_FRAMES` en vez de demultiplexar), cómo se localizó y la mejora medida. |

## Convención de nombres

El **prefijo** del nombre indica el **tipo** de documento (un único eje); el resto del nombre es el tema. Así se distingue de un vistazo una referencia de una explicación o de un caso:

| Prefijo | Tipo | Qué es | Ejemplo |
|---|---|---|---|
| `ref-` | **Referencia** | Documentación estable y consultable: qué hay y cómo se configura. Es la mayoría. | `ref-configuracion.md` |
| `explica-` | **Explicación** | Cómo funciona un mecanismo en profundidad (el porqué, diagramas, decisiones de diseño); complementa a la referencia. | `explica-deteccion-bordes.md` |
| `caso-` | **Caso** | Nota técnica de un problema concreto: síntoma → diagnóstico → solución → mejora medida (postmortem). | `caso-rendimiento-subtitulos.md` |

Reglas:

- El prefijo describe el **tipo**, no el área (no se usan prefijos de tema tipo `conf-`/`audio-`; el tema va en el nombre: `explica-deteccion-bordes`).
- Un solo prefijo por fichero (nada de `explica-conf-…`).
- `README.md` (este índice) no lleva prefijo.
- Al añadir un documento nuevo: elige el prefijo por su tipo y añádelo a la tabla del índice de arriba.

## Resumen en una frase

`Convert.cmd` lanza `Convert.ps1`, que en una primera pasada **pregunta** toda la configuración de cada vídeo de `Original\` y la congela en un `Proceso\<nombre>.job.json`; después, en la misma ventana (o en otras ventanas en paralelo), un **worker** codifica cada archivo preparado de forma desatendida, reclamándolo con un lock atómico.

```mermaid
flowchart LR
    O[Original/*.mkv] -->|PREPARAR| J[Proceso/*.job.json]
    J -->|WORKER| C[Convertido/*_fix.mkv]
```
