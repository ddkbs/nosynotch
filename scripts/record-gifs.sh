#!/usr/bin/env bash
# Renders every notch animation into GIFs in docs/gifs/ (STILLS=1 also saves PNG stills to docs/screenshots/).
#
#   ./scripts/record-gifs.sh            all scenes
#   ./scripts/record-gifs.sh done error only these scenes ("settings" = the settings window)
#
# Needs ffmpeg (brew install ffmpeg). A small window appears in the bottom-left corner
# of the screen while recording – leave it uncovered.
set -euo pipefail
cd "$(dirname "$0")/.."

WIDTH="${WIDTH:-840}"   # output width in px (frames are rendered at 2x = 1120 px)
FPS="${FPS:-25}"

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

mkdir -p docs/gifs
for dir in "$FRAMES"/*/; do
  name="$(basename "$dir")"
  [[ "$name" == stills ]] && continue
  out="docs/gifs/$name.gif"
  rate=30; [[ "$name" == settings ]] && rate=15
  ffmpeg -loglevel error -y -framerate "$rate" -i "$dir/frame_%04d.png" \
    -vf "fps=$FPS,scale=$WIDTH:-1:flags=lanczos,format=rgb24,split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    -loop 0 "$out"
  echo "✓ $out ($(du -h "$out" | cut -f1 | tr -d ' '))"
done

# Stills of the fully expanded notch (PNG) only on request: STILLS=1 ./scripts/record-gifs.sh
if [[ "${STILLS:-0}" == 1 && -d "$FRAMES/stills" ]]; then
  mkdir -p docs/screenshots
  for png in "$FRAMES"/stills/*.png; do
    cp "$png" "docs/screenshots/$(basename "$png")"
    echo "✓ docs/screenshots/$(basename "$png")"
  done
fi
