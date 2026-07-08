# TODO (versión PowerShell)

## Audio multipista (mantener varias pistas por idioma)

**Estado:** pendiente.

**Qué:** que `audioLanguages` del `config.json` signifique "mantener TODAS las pistas de
audio de estos idiomas" (p. ej. `["es","eng"]` → 2 pistas en el MKV final), en vez de
elegir una sola. Sería simétrico con cómo se tratan hoy los subtítulos.

**Situación actual:** el audio selecciona **una única** pista (la mejor según el orden de
`audioLanguages`, y dentro del idioma prefiere 5.1). El pipeline asume una sola pista
(un `.m4a`, un `-map`).

**Trabajo estimado (medio):**
- Selección: quedarse con todas las pistas cuyo idioma esté en la lista.
- Codificación: un temporal por pista (`<name>_aN.m4a`), cada una con su sincronía y volumen.
- Multiplex: mapear todas con su metadato de idioma y marcar una como `default`.

**Decisiones a confirmar cuando se retome:**
1. ¿Multipista (todas las de la lista) o mantener el modo "una sola por preferencia"?
2. Si hay 2+ pistas del MISMO idioma: ¿preguntar cuál (menú), mantener todas, o la mejor de cada idioma?

**Archivos que tocaría:** `lib/MediaInfo.psm1` (selección), `lib/Audio.psm1` (ASK/RUN),
`lib/Multiplex.psm1` (mapeo), `Convert.ps1` (job con lista de pistas de audio).
