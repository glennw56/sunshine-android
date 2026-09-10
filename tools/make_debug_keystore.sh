#!/usr/bin/env bash
# Create a standard Android debug keystore for Godot sideload exports.
set -euo pipefail
DEST="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
mkdir -p "$(dirname "$DEST")"
if [[ -f "$DEST" ]]; then
  echo "Already exists: $DEST"
  exit 0
fi
keytool -genkeypair -v -keystore "$DEST" \
  -alias androiddebugkey -storepass android -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
echo "Wrote $DEST (alias androiddebugkey, password android)"
