# Control de tasa: CRF y QMIN/QMAX/QP

Qué significan **CRF**, **QMIN**, **QMAX** y **QP** en los perfiles del conversor, para qué sirve cada uno, cómo se traducen a argumentos de ffmpeg y cómo elegir valores. Se definen en el perfil (de serie, propio de `config.json`, o el custom interactivo) y los aplica `Get-VideoArgs` ([Video.psm1](../lib/Video.psm1)).

## Qué es el control de tasa

Al recodificar vídeo hay que decidir el equilibrio **calidad ↔ tamaño**. En vez de fijar un bitrate (Mbps), el conversor usa **control de tasa por calidad**: le dices "quiero *esta* calidad" y el encoder gasta los bits que hagan falta en cada escena (más en las complejas, menos en las planas). Hay **dos familias** según dónde codifiques:

| Encoder | Dónde | Parámetro de calidad |
|---|---|---|
| `libx264`, `libx265` | **CPU** | **CRF** |
| `h264_nvenc`, `hevc_nvenc` | **GPU** (NVIDIA NVENC) | **QMIN / QMAX** (o **QP** constante) |

Todos operan sobre la misma escala subyacente: el **QP** (*Quantizer Parameter*) de H.264/HEVC, que va de **0 a 51**:

- **QP bajo** (p. ej. 1–18) → poca cuantización → **más calidad, más tamaño**.
- **QP alto** (p. ej. 35–51) → mucha cuantización → **menos calidad, menos tamaño**.

Por eso todos los valores de esta página se mueven en **0–51** (el conversor rechaza valores fuera de ese rango).

## CRF (Constant Rate Factor) — CPU

**Qué es:** un objetivo de **calidad constante percibida**. El encoder ajusta el QP por escena para mantener una calidad visual uniforme (baja el QP en escenas con movimiento, lo sube en las estáticas), apuntando al "nivel CRF" que le pides.

- **Escala 0–51.** Más bajo = mejor calidad y mayor tamaño. `0` ≈ sin pérdida (enorme); `51` = muy comprimido (feo).
- **Valores típicos:** x264 ≈ **18–23**; x265 ≈ **23–28** para calidad equivalente (x265 comprime más, así que el mismo número da menos tamaño). El default del builder custom es **21** (configurable, ver abajo).
- **Se aplica como:** `-crf <N>`.
- Un mismo CRF **no** da la misma calidad ni tamaño entre x264 y x265: coincide el *rango* (0–51), no el *punto* óptimo.

## QMIN / QMAX — GPU (NVENC)

NVENC no usa CRF; su control de tasa por calidad se acota con dos cuantizadores:

- **QMIN** = QP **mínimo** permitido → **techo de calidad**. El encoder no bajará de este QP aunque le sobren bits (evita malgastar tamaño en escenas simples).
- **QMAX** = QP **máximo** permitido → **suelo de calidad**. El encoder no subirá de este QP aunque la escena sea muy compleja (garantiza una calidad mínima, a costa de tamaño).

Entre ambos, NVENC ajusta el QP frame a frame. Un rango típico del conversor es **QMIN 1 / QMAX 23**: permite subir mucho la calidad en escenas fáciles (hasta QP 1) pero nunca dejar caer la calidad por debajo de QP 23.

- **Escala 0–51** para ambos.
- **Se aplica como:** `-qmin <QMIN> -qmax <QMAX>`.

### Caso especial: QP constante (QMIN == QMAX)

Si defines **QMIN igual a QMAX**, no hay rango que ajustar: es **calidad fija** (equivalente en espíritu al CRF, pero en GPU). El conversor lo detecta y usa:

```
-rc constqp -qp <valor>
```

### "Q auto" (sin QMIN/QMAX)

Si **no** defines QMIN/QMAX (vacío en el builder, o negativo = "desactivar"), NVENC usa su propio control de tasa según el `-preset` (aquí `slow`), sin cotas manuales. Es lo que hacen los perfiles de serie de **"Q auto"** (los que no fijan `qmin`/`qmax`; ver [ref-perfiles.md](ref-perfiles.md)).

## Cómo se traduce a ffmpeg (resumen)

Aquí solo el **control de tasa**; el comando completo por encoder (profile/level, pix_fmt/profundidad, preset, lookahead, multipass…) está en **[ref-comandos.md](ref-comandos.md) §8** (fuente única, no se repite aquí):

| Encoder | Control de tasa | Argumento ffmpeg |
|---|---|---|
| `libx264` / `libx265` (CPU) | `Crf` (0-51) | `-crf <N>` |
| `libsvtav1` (CPU, AV1) | `Crf` (0-63) | `-crf <N>` |
| `h264_nvenc` / `hevc_nvenc` / `av1_nvenc` (NVENC) | `Qmin`/`Qmax` | `-qmin`/`-qmax`, o `-rc constqp -qp <q>` si `qmin == qmax` |

## Cómo elegir el valor

- **Punto de partida:** CRF/QP **21–23** suele dar muy buena calidad con tamaño razonable en 1080p. Baja el número si quieres más calidad (más tamaño), súbelo si priorizas tamaño.
- **NVENC con rango** (`QMIN 1 / QMAX 23`): deja al encoder mejorar escenas simples sin dejar caer las complejas; buen equilibrio por defecto.
- **Calidad fija reproducible:** usa `QMIN == QMAX` (constqp) o un CRF concreto.
- Regla práctica: **±6** en la escala ≈ *doble/mitad* de tamaño aproximado.

## Dónde se define

- **Perfiles de serie** (1–13): valores fijos (ver [ref-perfiles.md](ref-perfiles.md)).
- **Perfiles propios** de `config.json` (sección `profiles`): campos `crf`, `qmin`, `qmax` por perfil.
- **Perfil custom interactivo:** se pregunta en el menú "Control de tasa"; el **valor por defecto** de cada pregunta sale de la sección **`customProfile`** de `config.json` (`crf`, `qmin`, `qmax`) — ENTER acepta el default. Ver [ref-configuracion.md](ref-configuracion.md).

**Validación:** el builder acepta **0–51**; un valor **> 51** se rechaza y se vuelve a preguntar (no tiene sentido en H.264/HEVC). Un valor **negativo** (p. ej. `-1`) significa **"auto"**: no se pasa `-qmin`/`-qmax` ni `-crf` y decide el encoder ("Q auto"). Los defaults de `config.json` siguen la misma regla: `-1` = auto, y el resto se acota a 0–51.
