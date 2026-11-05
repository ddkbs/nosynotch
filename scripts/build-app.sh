#!/usr/bin/env bash
# Builds build/Claude Notch.app (release, ad-hoc signed).
#   ./scripts/build-app.sh           # build
#   ./scripts/build-app.sh --open    # build and launch
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ClaudeNotch"

APP="build/Claude Notch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClaudeNotch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

echo "✓ $APP"

if [[ "${1:-}" == "--open" ]]; then
  pkill -x ClaudeNotch 2>/dev/null || true
  open "$APP"
fi
