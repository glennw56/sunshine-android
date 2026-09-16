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

# Godot 4.3's gitignored Gradle template still ships compileSdk 34. Play now
# requires target API 36, so raise compileSdk / default targetSdk / build-tools
# before Gradle runs. compileSdk must be >= the Play preset target_sdk (36).
CFG="$ROOT/android/build/config.gradle"
CFG_BAK="$(mktemp)"
PROPS="$ROOT/android/build/gradle.properties"
PROPS_BAK="$(mktemp)"
PRESET="$ROOT/export_presets.cfg"
BACKUP="$(mktemp)"
CANON="$ROOT/project.godot"
CANON_BAK="$(mktemp)"
cp "$CFG" "$CFG_BAK"
cp "$PROPS" "$PROPS_BAK"
cp "$PRESET" "$BACKUP"
cp "$CANON" "$CANON_BAK"
cleanup() {
  cp "$BACKUP" "$PRESET"
  cp "$CANON_BAK" "$CANON"
  cp "$CFG_BAK" "$CFG"
  cp "$PROPS_BAK" "$PROPS"
  rm -f "$BACKUP" "$CANON_BAK" "$CFG_BAK" "$PROPS_BAK"
}
trap cleanup EXIT
python3 - "$CFG" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
text, n1 = re.subn(r"compileSdk\s*:\s*\d+", "compileSdk         : 36", text, count=1)
text, n2 = re.subn(r"targetSdk\s*:\s*\d+", "targetSdk          : 36", text, count=1)
text, n3 = re.subn(r"buildTools\s*:\s*'[\d.]+'", "buildTools         : '36.0.0'", text, count=1)
if n1 != 1 or n2 != 1 or n3 != 1:
    raise SystemExit(f"failed to patch config.gradle for API 36 (compile={n1} target={n2} buildTools={n3})")
path.write_text(text)
print("Patched android/build/config.gradle compileSdk/targetSdk/buildTools -> 36")
PY
if ! grep -q 'android.suppressUnsupportedCompileSdk' "$PROPS"; then
  printf '\nandroid.suppressUnsupportedCompileSdk=36\n' >> "$PROPS"
fi

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
