#!/usr/bin/env bash
# One-time setup + sanity checks for Epoch Clash. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v fvm >/dev/null || { echo "fvm not found: brew tap leoafarias/fvm && brew install fvm"; exit 1; }
fvm install 3.47.5
fvm use 3.47.5 --force
fvm flutter pub get

if command -v python3 >/dev/null && python3 -c "import PIL" 2>/dev/null; then
  python3 tools/check_assets.py
else
  echo "(skipping asset check: python3 + Pillow not found)"
fi

fvm flutter analyze
fvm flutter test

if [[ "$(uname)" == "Darwin" ]]; then
  (cd ios && pod install)
fi

echo
echo "Ready. Plug in a phone (or start a simulator) and run: fvm flutter run"
