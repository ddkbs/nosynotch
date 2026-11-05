#!/usr/bin/env bash
# Renders every notch animation into GIFs in docs/gifs/ (README) and MP4s + JPG posters in website/public/demo/.
#
#   ./scripts/record-gifs.sh            all scenes
#   ./scripts/record-gifs.sh done error only these scenes ("settings" = the settings window)
#
# Frames are rendered on a virtual clock, so none are ever dropped – a slow machine only takes longer.
#
#   FPS=60        capture frame rate (also the MP4 frame rate)
#   SCALE=2       pixels per point while capturing (3 = 1680 px wide, sharper and slower)
#   GIF_WIDTH=840 GIF_FPS=30 GIF_COLORS=256   GIF output (WIDTH= still works for GIF_WIDTH)
#   VIDEO=1       MP4 + poster for the website (0 = GIFs only); VIDEO_WIDTH defaults to the capture width
#   WEBM=1        also write VP9 WebMs next to the MP4s
#   STILLS=1      also save PNG stills of the fully expanded notch to docs/screenshots/
#
# Needs ffmpeg (brew install ffmpeg). A small window appears in the bottom-left corner
# of the screen while recording – leave it uncovered.
set -euo pipefail
cd "$(dirname "$0")/.."

export FPS="${FPS:-60}"
export SCALE="${SCALE:-2}"
GIF_WIDTH="${GIF_WIDTH:-${WIDTH:-840}}"
GIF_FPS="${GIF_FPS:-30}"
GIF_COLORS="${GIF_COLORS:-256}"
VIDEO="${VIDEO:-1}"
WEBM="${WEBM:-0}"
VIDEO_WIDTH="${VIDEO_WIDTH:-$(awk "BEGIN { printf \"%d\", 560 * $SCALE }")}"

command -v ffmpeg >/dev/null || { echo "✗ ffmpeg is missing: brew install ffmpeg" >&2; exit 1; }

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NosyNotch"

FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT
# "settings" is the settings window, everything else a notch scene. No arguments = all of them.
scenes=()
for arg in "$@"; do [[ "$arg" == settings ]] || scenes+=("$arg"); done
if [[ $# -eq 0 || ${#scenes[@]} -gt 0 ]]; then "$BIN" --record "$FRAMES" ${scenes[@]+"${scenes[@]}"}; fi
if [[ $# -eq 0 || " $* " == *" settings "* ]]; then "$BIN" --record-settings "$FRAMES"; fi

size() { du -h "$1" | cut -f1 | tr -d ' '; }

mkdir -p docs/gifs
[[ "$VIDEO" == 1 ]] && mkdir -p website/public/demo
for dir in "$FRAMES"/*/; do
  name="$(basename "$dir")"
  [[ "$name" == stills ]] && continue
  input=(-framerate "$FPS" -i "$dir/frame_%04d.png")

  # GIF: one palette for the whole clip (the static wallpaper gets its colours too, so gradients don't band),
  # only the changed rectangle is re-dithered per frame to keep the file small.
  rate="$GIF_FPS"; [[ "$name" == settings ]] && rate=15
  gif="docs/gifs/$name.gif"
  ffmpeg -loglevel error -y "${input[@]}" \
    -vf "fps=$rate,scale=$GIF_WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=$GIF_COLORS:stats_mode=full:reserve_transparent=0[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    -loop 0 "$gif"
  echo "✓ $gif ($(size "$gif"))"

  [[ "$VIDEO" == 1 ]] || continue
  # Frames are sRGB: convert with the BT.709 matrix and say so, otherwise browsers shift the colours.
  scale="scale=$VIDEO_WIDTH:-2:flags=lanczos"
  yuv="$scale:out_color_matrix=bt709,format=yuv420p"
  tags=(-colorspace bt709 -color_primaries bt709 -color_trc iec61966-2-1)
  mp4="website/public/demo/$name.mp4"
  ffmpeg -loglevel error -y "${input[@]}" -vf "$yuv" "${tags[@]}" \
    -c:v libx264 -preset slow -crf 18 -tune animation -profile:v high -r "$FPS" -movflags +faststart -an "$mp4"
  echo "✓ $mp4 ($(size "$mp4"))"
  if [[ "$WEBM" == 1 ]]; then
    webm="website/public/demo/$name.webm"
    ffmpeg -loglevel error -y "${input[@]}" -vf "$yuv" "${tags[@]}" \
      -c:v libvpx-vp9 -crf 30 -b:v 0 -row-mt 1 -r "$FPS" -an "$webm"
    echo "✓ $webm ($(size "$webm"))"
  fi
  # Poster: the first frame, so the page shows exactly what the video starts with.
  jpg="website/public/demo/$name.jpg"
  ffmpeg -loglevel error -y -i "$dir/frame_0000.png" -vf "$scale" -q:v 3 -frames:v 1 "$jpg"
  echo "✓ $jpg ($(size "$jpg"))"
done

# Stills of the fully expanded notch (PNG) only on request: STILLS=1 ./scripts/record-gifs.sh
if [[ "${STILLS:-0}" == 1 && -d "$FRAMES/stills" ]]; then
  mkdir -p docs/screenshots
  for png in "$FRAMES"/stills/*.png; do
    cp "$png" "docs/screenshots/$(basename "$png")"
    echo "✓ docs/screenshots/$(basename "$png")"
  done
fi
