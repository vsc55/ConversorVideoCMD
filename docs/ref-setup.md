# setup: gestión de herramientas y configuración

`setup.ps1` (lanzado con `setup.cmd`) es la utilidad de gestión del conversor: instalar/actualizar herramientas (ffmpeg, aacgain, MKVToolNix, 7zr), editar `config.json` con un editor navegable, ver el estado del entorno, comprobar la compatibilidad GPU, ejecutar los tests unitarios y limpiar `Proceso\`/`logs\`. No ejecuta el pipeline de conversión (eso es `Convert.ps1`).

```powershell
setup.cmd                       # normal (config.json junto al programa)
setup.cmd -Config otra.json     # usar/editar un config alterno (ver "Config alterno")
powershell -ExecutionPolicy Bypass -File setup.ps1
```

La sesión queda registrada en `logs\setup_<fecha>_<PID>.log` (mismo interruptor `behavior.log` / marcador `no_log`). El arranque (config + contexto + apariencia + cabecera) es común con `Convert.ps1` vía `Start-CvSession`.

## Menú principal

Agrupado por bloques (**Herramientas / Estado / Compatibilidad / Pruebas / Configuración / Limpieza**). La gestión de herramientas vive en un **submenú** para que el menú principal no crezca con el número de apps:

| Bloque · Opción | Qué hace |
|---|---|
| **Herramientas** · Instalar / gestionar herramientas | Submenú con una entrada por app (ffmpeg, aacgain, mkvtoolnix, sevenzip…) y "Reinstalar TODO". Por app: elige versión (selector ordenado de más nueva a más antigua), borra esa carpeta de versión y la (re)instala; ofrece fijarla como `selected`. Al instalar **ffmpeg** valida NVENC y, si no es compatible, **vuelve a la versión anterior** (ver abajo). Instalación: [ref-herramientas.md](ref-herramientas.md). |
| **Estado** · Ver estado | Muestra (bajo demanda): **identidad** (versión de ConvertVideo + config en uso, marcando si es alterno `-Config` o no existe); **checklist de directorios**; **versiones de herramientas** instaladas por app/plataforma (o `[NO SOPORTADO]`); **estado de `Proceso\`** (jobs pendientes, bloqueos —con cuántos **caducados/huérfanos**— y temporales); y **trabajo** (nº de vídeos en `Original\` y convertidos `*_fix.<ext>` en `Convertido\`). |
| **Compatibilidad** · Comprobar compatibilidad GPU (NVENC) | Prueba NVENC en las versiones de ffmpeg instaladas, **sin reinstalar**. |
| **Pruebas** · Ejecutar tests unitarios | Lanza `test\unit-tests.ps1` (funciones puras: sin GPU ni ffmpeg, < 1 s) como **proceso hijo** y reporta si todo pasó o falló algún caso. Ver [ref-pruebas.md](ref-pruebas.md). |
| **Pruebas** · Ejecutar batería de features | Lanza `test\feature-tests.ps1` (E2E; usa ffmpeg; los casos de GPU se **saltan** si no hay NVENC) como proceso hijo. Tarda más (codifica). Ver [ref-pruebas.md](ref-pruebas.md). |
| **Configuración** · Editar configuración | Editor navegable de todas las secciones del config en uso (ver abajo). |
| **Configuración** · Restablecer | Vuelve a los valores por defecto (conserva el catálogo `downloads`; copia en `<fichero>.bak`). |
| **Limpieza** · Limpiar jobs / bloqueos (Proceso) | Borra `*.job.json`, `*.lock`, temporales o todo (con confirmación); las cuentas se muestran en el menú. Patrones: `Get-CvProcesoPatterns`. |
| **Limpieza** · Limpiar logs | Borra los `*.log` de `logs\` (excepto el de la sesión actual). |
| Salir | — |

> El estado ya no se imprime en cada vuelta al menú; se ve con la opción **Ver estado**. Al saltar de menú a menú se **limpia la pantalla**; tras una acción con información relevante (instalación, borrado, guardado) hay una **pausa** antes de limpiar.

## Compatibilidad GPU (NVENC) y fallback de versión

Al **instalar/reinstalar ffmpeg**, tras copiar los binarios se hace una **validación funcional** de NVENC (`Test-CvNvenc`: codifica un clip sintético con `hevc_nvenc`, y si falla `h264_nvenc`) y se da un veredicto (COMPATIBLE / NO COMPATIBLE con la causa extraída de ffmpeg). Detalle del mecanismo en [ref-herramientas.md](ref-herramientas.md).

Si la versión recién instalada **NO es compatible** con NVENC en este equipo (típico: ffmpeg 8.x exige un driver NVIDIA más nuevo del instalado), `setup` **prueba las versiones anteriores del catálogo** (`downloads.ffmpeg.versions`) hasta dar con una compatible:

1. Toma las versiones **anteriores** a la fallida (las más nuevas no ayudarían: el fallo es "driver demasiado antiguo para este ffmpeg"), ordenadas de **más nueva a más antigua** (`Get-CvNvencFallbackCandidates`).
2. Por cada candidata: la **instala** (descarga fresca + verifica SHA, sin borrar la anterior por si la descarga falla) y **comprueba NVENC**. Se queda con la **primera compatible** y la fija como `selected`.
3. Si **ninguna** es compatible, **avisa** (usa un perfil CPU `libx264`/`libx265` o actualiza el driver NVIDIA) y no cambia la selección.

Así no depende de qué versiones estén ya instaladas: descarga y prueba las del catálogo. `Install-CvTool` expone el resultado NVENC con `-NvencOk`.

La elección la decide `Resolve-CvFallbackVersion` (función pura); `Install-CvTool` expone el resultado NVENC con `-NvencOk`. La comprobación *Comprobar compatibilidad GPU* del menú **no** reinstala ni cambia la selección: solo informa.

## Editor de configuración

Recorre el árbol del config en uso (se muestra su **nombre real** en el título: `config.json`, `config.debug.json`…):

- **Escalares**: edición por tipo, con selectores especiales para colores (`background`/`foreground`), método de volumen (`method`) y booleanos. Cada opción muestra su **ayuda** (catálogo `Get-CvConfigHelp`) y su **valor por defecto** de fábrica.
- **Listas** (idiomas): añadir / eliminar / editar elementos.
- **Objetos**: se navegan hacia dentro.

Se edita el config **fusionado** (defaults + overrides), así que el editor muestra **todas** las opciones aunque el fichero sea mínimo. Al guardar, solo se escribe lo que **difiere del default** (lo que vuelve al default se elimina del fichero); el serializador propio **conserva valores, tipos, arrays y formato** (4 espacios, CRLF) y normaliza a array los campos que deben serlo (PS 5.1 desenvuelve los arrays de 1 elemento al leer JSON). Referencia de claves: [ref-configuracion.md](ref-configuracion.md).

## Config alterno (`-Config`) y modo debug

`-Config <ruta>` (en `Convert.ps1` y `setup.ps1`, reenviado por `Convert.cmd`/`setup.cmd` con `%*`) usa un **fichero de configuración alterno** en vez del `config.json` por defecto. La ruta se resuelve a **absoluta** (`Resolve-CvConfigPathArg`): vacío = `<Root>\config.json`; relativa = respecto al directorio actual; absoluta = tal cual. Todos los textos de `setup` (editor, prompts, menú, estado) muestran el **nombre real** del fichero, no un literal `config.json`.

Cuando `Convert.ps1` abre **ventanas worker en paralelo**, **reenvía el mismo `-Config`** (ruta absoluta) a cada una, así que todas usan el mismo config.

Lanzadores de depuración incluidos:

| Fichero | Uso |
|---|---|
| `config.debug.json` | Override mínimo `{ "behavior": { "debug": true } }` (se fusiona con los defaults). |
| `Convert-Debug.cmd` | Igual que `Convert.cmd` pero con `-Config config.debug.json`: abre el conversor con el **log detallado** (comandos de ffmpeg y pasos internos) sin tocar tu `config.json`. |
| `setup-Debug.cmd` | Igual que `setup.cmd` pero con `-Config config.debug.json`: para **editar/gestionar** ese config de depuración. |

## Añadir una versión nueva de una herramienta

En el config, dentro de `downloads.<app>.versions`, añade `"<version>": "<sha256>"`. Si sigue el patrón de la `url` (con `{version}`), ya se puede instalar desde `setup` o se autoinstala si un job la pide. El catálogo completo es la fuente única `Get-CvConfigDefaults`; ver [ref-herramientas.md](ref-herramientas.md).
