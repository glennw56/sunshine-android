#!/usr/bin/env bash
# Sideload debug APK with Gradle + AdMob. No Play upload key required.
#   bash tools/export_debug_apk.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PLAYER="$ROOT/scripts/explore/player.gd"
if [[ ! -f "$PLAYER" ]]; then
  echo "REFUSE export: scripts/explore/player.gd missing" >&2
  exit 1
fi
if ! grep -q 'SpringArm3D' "$PLAYER" || ! grep -q 'const SHOULDER := Vector3(0.0, 1.78, 0.12)' "$PLAYER"; then
  echo "REFUSE export: player.gd is not the centered TPP baker (need SpringArm + SHOULDER.x=0)." >&2
  echo "Do not export from main / a stub camera." >&2
  exit 1
fi
if grep -q 'Vector3(0.68' "$PLAYER"; then
  echo "REFUSE export: over-right-shoulder 0.68 offset is still in player.gd" >&2
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
# Godot will otherwise reimport mipmap icons and leave *.import that Gradle rejects.
mkdir -p android
touch android/.gdignore
find android/build -name '*.import' -delete 2>/dev/null || true

CFG="$ROOT/android/build/config.gradle"
CFG_BAK="$(mktemp)"
PROPS="$ROOT/android/build/gradle.properties"
PROPS_BAK="$(mktemp)"
cp "$CFG" "$CFG_BAK"
cp "$PROPS" "$PROPS_BAK"
cleanup() {
  cp "$CFG_BAK" "$CFG"
  cp "$PROPS_BAK" "$PROPS"
  rm -f "$CFG_BAK" "$PROPS_BAK"
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
if [[ -n "${JAVA_HOME:-}" ]] && ! grep -q '^org.gradle.java.home=' "$PROPS"; then
  printf '\norg.gradle.java.home=%s\n' "$JAVA_HOME" >> "$PROPS"
fi

mkdir -p "$ROOT/export"
OUT="${1:-$ROOT/export/sunshines-bakery.apk}"

set +e
DISPLAY="${DISPLAY:-:1}" "$GODOT" --path "$ROOT" \
  --display-driver x11 --rendering-driver opengl3 \
  --export-debug Android "$OUT"
CODE=$?
set -e
if [[ $CODE -ne 0 ]]; then
  echo "Godot export failed with exit $CODE" >&2
  exit $CODE
fi
if [[ ! -s "$OUT" ]]; then
  echo "Export produced no APK at $OUT" >&2
  exit 1
fi
echo "Wrote $OUT ($(du -h "$OUT" | awk '{print $1}'))"
