#!/usr/bin/env bash
# Regenera las fixtures multipista (*.mkv) de la carpeta test/ a partir de la
# muestra base `video-1080p-basico.mp4` (fuente: samplelib.com) + pistas sinteticas.
# Documentacion (que prueba cada fixture, fuentes/licencias): docs/pruebas.md
# Uso:  bash test/generate-fixtures.sh
# Requiere ffmpeg (usa el de tools/ si existe, si no el del PATH).
set -e
cd "$(dirname "$0")/.."

FF="tools/ffmpeg/7.1.1/x64/ffmpeg.exe"
[ -x "$FF" ] || FF="ffmpeg"
BASE="test/video-1080p-basico.mp4"
[ -f "$BASE" ] || { echo "Falta $BASE (descargar de samplelib.com)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf '1\n00:00:01,000 --> 00:00:03,000\n[texto forzado]\n\n2\n00:00:04,000 --> 00:00:05,000\n[texto forzado]\n' > "$TMP/forced.srt"
printf '1\n00:00:00,500 --> 00:00:02,500\nDialogo completo linea 1.\n\n2\n00:00:03,000 --> 00:00:05,000\nDialogo completo linea 2.\n' > "$TMP/full.srt"
printf '1\n00:00:00,500 --> 00:00:02,500\n[door creaks] Full SDH.\n\n2\n00:00:03,000 --> 00:00:05,000\n[music] Full SDH.\n' > "$TMP/full2.srt"
Q(){ "$@" >/dev/null 2>&1; }

# subtitulo forzado + predefinido (regresion del flag default)
Q "$FF" -hide_banner -y -i "$BASE" -i "$TMP/forced.srt" -i "$TMP/full2.srt" \
  -map 0:v:0 -map 0:a:0 -map 1:0 -map 2:0 -c:v copy -c:a copy -c:s srt \
  -metadata:s:a:0 language=spa -metadata:s:a:0 title=European \
  -metadata:s:s:0 language=spa -metadata:s:s:0 title="European (Forced)" -disposition:s:0 default+forced \
  -metadata:s:s:1 language=eng -metadata:s:s:1 title=SDH -disposition:s:1 0 \
  -f matroska "test/subs-forzado-predefinido.mkv"

# audio spa/eng/fra + subs spa-full/spa-forced/eng/fra-forced
Q "$FF" -hide_banner -y -i "$BASE" -i "$TMP/full.srt" -i "$TMP/forced.srt" -i "$TMP/full2.srt" -i "$TMP/forced.srt" \
  -map 0:v:0 -map 0:a:0 -map 0:a:0 -map 0:a:0 -map 1:0 -map 2:0 -map 3:0 -map 4:0 \
  -c:v copy -c:a copy -c:s srt \
  -metadata:s:a:0 language=spa -metadata:s:a:0 title=Castellano -disposition:a:0 default \
  -metadata:s:a:1 language=eng -metadata:s:a:1 title=English  -disposition:a:1 0 \
  -metadata:s:a:2 language=fra -metadata:s:a:2 title=Francais -disposition:a:2 0 \
  -metadata:s:s:0 language=spa -metadata:s:s:0 title=Castellano -disposition:s:0 default \
  -metadata:s:s:1 language=spa -metadata:s:s:1 title="Castellano (Forzados)" -disposition:s:1 forced \
  -metadata:s:s:2 language=eng -metadata:s:s:2 title=English -disposition:s:2 0 \
  -metadata:s:s:3 language=fra -metadata:s:s:3 title="Francais (Forces)" -disposition:s:3 forced \
  -f matroska "test/audio-y-subs-multiidioma.mkv"

# 2 completos spa + forzado spa + eng (menu de subtitulo)
Q "$FF" -hide_banner -y -i "$BASE" -i "$TMP/full.srt" -i "$TMP/full2.srt" -i "$TMP/forced.srt" -i "$TMP/full2.srt" \
  -map 0:v:0 -map 0:a:0 -map 1:0 -map 2:0 -map 3:0 -map 4:0 -c:v copy -c:a copy -c:s srt \
  -metadata:s:a:0 language=spa \
  -metadata:s:s:0 language=spa -metadata:s:s:0 title=Castellano -disposition:s:0 default \
  -metadata:s:s:1 language=spa -metadata:s:s:1 title="Castellano (SDH)" \
  -metadata:s:s:2 language=spa -metadata:s:s:2 title="Castellano (Forzados)" -disposition:s:2 forced \
  -metadata:s:s:3 language=eng -metadata:s:s:3 title=English \
  -f matroska "test/subs-varios-completos-espanol-menu.mkv"

# audio spa 2.0 + spa 5.1 + eng (preferencia 5.1 / menu audio)
Q "$FF" -hide_banner -y -i "$BASE" -f lavfi -t 6 -i anullsrc=channel_layout=5.1:sample_rate=48000 \
  -map 0:v:0 -map 0:a:0 -map 1:0 -map 0:a:0 -shortest -c:v copy -c:a aac -b:a 128k \
  -metadata:s:a:0 language=spa -metadata:s:a:0 title="Castellano 2.0" \
  -metadata:s:a:1 language=spa -metadata:s:a:1 title="Castellano 5.1" \
  -metadata:s:a:2 language=eng -metadata:s:a:2 title=English \
  -f matroska "test/audio-espanol-estereo-y-51.mkv"

# audio eng(default) + fra, sin spa (fallback al default)
Q "$FF" -hide_banner -y -i "$BASE" \
  -map 0:v:0 -map 0:a:0 -map 0:a:0 -c:v copy -c:a copy \
  -metadata:s:a:0 language=eng -metadata:s:a:0 title=English  -disposition:a:0 default \
  -metadata:s:a:1 language=fra -metadata:s:a:1 title=Francais -disposition:a:1 0 \
  -f matroska "test/audio-sin-espanol-fallback.mkv"

# audio spa + subs eng + fra (subs no preferidos -> ninguno)
Q "$FF" -hide_banner -y -i "$BASE" -i "$TMP/full.srt" -i "$TMP/full2.srt" \
  -map 0:v:0 -map 0:a:0 -map 1:0 -map 2:0 -c:v copy -c:a copy -c:s srt \
  -metadata:s:a:0 language=spa \
  -metadata:s:s:0 language=eng -metadata:s:s:0 title=English \
  -metadata:s:s:1 language=fra -metadata:s:s:1 title=Francais \
  -f matroska "test/subs-sin-espanol-descartar.mkv"

# orden fisico de pistas: sub, audio, video, audio, sub
Q "$FF" -hide_banner -y -i "$BASE" -i "$TMP/forced.srt" -i "$TMP/full2.srt" \
  -map 1:0 -map 0:a:0 -map 0:v:0 -map 0:a:0 -map 2:0 -c:v copy -c:a copy -c:s srt \
  -metadata:s:s:0 language=spa -metadata:s:s:0 title="Castellano (Forzados)" -disposition:s:0 default+forced \
  -metadata:s:a:0 language=spa -metadata:s:a:0 title=Castellano -disposition:a:0 default \
  -metadata:s:a:1 language=eng -metadata:s:a:1 title=English \
  -metadata:s:s:1 language=eng -metadata:s:s:1 title=English \
  -f matroska "test/pistas-orden-aleatorio.mkv"

echo "Fixtures regeneradas en test/"
