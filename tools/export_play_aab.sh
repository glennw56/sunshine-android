#!/usr/bin/env bash
# Build a Play Console release AAB. Keystore + passwords live OUTSIDE git.
#   bash tools/export_play_aab.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENVF="${SUNSHINES_PLAY_ENV:-$HOME/.local/share/godot/keystores/sunshines-play-release.env}"
if [[ ! -f "$ENVF" ]]; then
  echo "Missing $ENVF — generate a Play upload keystore first (see docs/PLAY_STORE.md)." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$ENVF"
: "${SUNSHINES_PLAY_KEYSTORE:?}"
: "${SUNSHINES_PLAY_ALIAS:?}"
: "${SUNSHINES_PLAY_STOREPASS:?}"
: "${SUNSHINES_PLAY_KEYPASS:?}"
if [[ ! -f "$SUNSHINES_PLAY_KEYSTORE" ]]; then
  echo "Missing keystore $SUNSHINES_PLAY_KEYSTORE" >&2
  exit 1
fi
if [[ "$SUNSHINES_PLAY_STOREPASS" != "$SUNSHINES_PLAY_KEYPASS" ]]; then
  echo "Godot requires the keystore password and key password to match." >&2
  exit 1
fi

GODOT="${GODOT:-/tmp/godot/Godot_v4.3-stable_linux.x86_64}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export ANDROID_HOME="${ANDROID_HOME:-/home/ubuntu/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary not found: $GODOT" >&2
  exit 1
fi
if [[ ! -f android/.build_version || ! -f android/build/build.gradle ]]; then
  echo "Install the Godot Android build template (Project → Install Android Build Template)." >&2
  echo "Need android/.build_version and android/build/build.gradle." >&2
  exit 1
fi

PRESET="$ROOT/export_presets.cfg"
BACKUP="$(mktemp)"
cp "$PRESET" "$BACKUP"
python3 - "$PRESET" "$SUNSHINES_PLAY_KEYSTORE" "$SUNSHINES_PLAY_ALIAS" "$SUNSHINES_PLAY_STOREPASS" <<'PY'
import sys
from pathlib import Path
path, ks, alias, password = sys.argv[1:]
text = Path(path).read_text()
# Inject into the Play preset only (second keystore/release block).
needle = 'keystore/release=""\nkeystore/release_user=""\nkeystore/release_password=""'
play = (
    f'keystore/release="{ks}"\n'
    f'keystore/release_user="{alias}"\n'
    f'keystore/release_password="{password}"'
)
first = text.find(needle)
if first < 0:
    raise SystemExit("export_presets.cfg missing empty release keystore fields")
second = text.find(needle, first + 1)
if second < 0:
    raise SystemExit("export_presets.cfg missing Play preset keystore fields")
text = text[:second] + play + text[second + len(needle):]
Path(path).write_text(text)
PY

mkdir -p "$ROOT/export"
OUT="${1:-$ROOT/export/sunshines-bakery.aab}"
CANON="$ROOT/project.godot"
CANON_BAK="$(mktemp)"
cp "$CANON" "$CANON_BAK"

cleanup() {
  cp "$BACKUP" "$PRESET"
  cp "$CANON_BAK" "$CANON"
  rm -f "$BACKUP" "$CANON_BAK"
}
trap cleanup EXIT

set +e
DISPLAY="${DISPLAY:-:1}" "$GODOT" --path "$ROOT" \
  --display-driver x11 --rendering-driver opengl3 \
  --export-release "Android Play" "$OUT"
CODE=$?
set -e
if [[ $CODE -ne 0 ]]; then
  echo "Godot export failed with exit $CODE" >&2
  exit $CODE
fi
if [[ ! -s "$OUT" ]]; then
  echo "Export produced no AAB at $OUT" >&2
  exit 1
fi
echo "Wrote $OUT ($(du -h "$OUT" | awk '{print $1}'))"
