#!/usr/bin/env bash
# Regenera las fixtures multipista (*.mkv) de la carpeta test/ a partir de la
# muestra base `video-1080p-basico.mp4` (fuente: samplelib.com) + pistas sinteticas.
# Documentacion (que prueba cada fixture, fuentes/licencias): docs/ref-pruebas.md
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

# Duracion del video base (para repartir los cues por toda su longitud).
FFP="tools/ffmpeg/7.1.1/x64/ffprobe.exe"; [ -x "$FFP" ] || FFP="ffprobe"
DUR="$("$FFP" -v error -show_entries format=duration -of default=nw=1:nk=1 "$BASE" 2>/dev/null)"
case "$DUR" in ''|*[!0-9.]*) DUR="5.7" ;; esac

# gen_srt <count> <prefix> <outfile>: SRT con <count> cues REPARTIDOS por el 100% del video.
# Cada cue ocupa el centro de su reparto (10%..90% del hueco), sin solaparse.
gen_srt() {
  local count="$1" prefix="$2" out="$3"
  : > "$out"
  awk -v n="$count" -v dur="$DUR" -v pfx="$prefix" 'BEGIN{
    slot=dur/n
    for(i=0;i<n;i++){
      a=slot*i+slot*0.1; b=slot*i+slot*0.9
      printf "%d\n%s --> %s\n%s %d.\n\n", i+1, ts(a), ts(b), pfx, i+1
    }
  }
  function ts(s,  h,m,sec,ms){ h=int(s/3600); m=int((s%3600)/60); sec=int(s%60); ms=int((s-int(s))*1000);
    return sprintf("%02d:%02d:%02d,%03d",h,m,sec,ms) }' > "$out"
}
# forzado = POCOS cues (3); completos = MUCHOS (9 y 7) -> distingue por tamaño ademas de por flag.
gen_srt 3 "[Forzado]"        "$TMP/forced.srt"
gen_srt 9 "Dialogo completo" "$TMP/full.srt"
gen_srt 7 "[SDH]"            "$TMP/full2.srt"
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

# 2 pistas de VIDEO (640x480 + 320x240) + audio spa -> se elige la 1a pista de video
Q "$FF" -hide_banner -y \
  -f lavfi -t 6 -i "testsrc=size=640x480:rate=30" \
  -f lavfi -t 6 -i "testsrc2=size=320x240:rate=30" \
  -f lavfi -t 6 -i "anullsrc=channel_layout=stereo:sample_rate=48000" \
  -map 0:v -map 1:v -map 2:a -c:v libx264 -pix_fmt yuv420p -c:a aac \
  -metadata:s:v:0 title="Cam A 480p" -metadata:s:v:1 title="Cam B 240p" \
  -metadata:s:a:0 language=spa \
  -f matroska "test/pistas-video-multiple.mkv"

echo "Fixtures regeneradas en test/"
