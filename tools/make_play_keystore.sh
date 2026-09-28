#!/usr/bin/env bash
# Create a Play upload keystore OUTSIDE the repo. Does not overwrite an existing file.
#   bash tools/make_play_keystore.sh
set -euo pipefail
DEST_DIR="${SUNSHINES_PLAY_DIR:-$HOME/.local/share/godot/keystores}"
DEST="${SUNSHINES_PLAY_KEYSTORE:-$DEST_DIR/sunshines-play-release.keystore}"
ENVF="${SUNSHINES_PLAY_ENV:-$DEST_DIR/sunshines-play-release.env}"
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"
if [[ -f "$DEST" || -f "$ENVF" ]]; then
  echo "Already exists (refusing to overwrite): $DEST / $ENVF" >&2
  exit 1
fi
PASS="$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)"
umask 077
keytool -genkeypair -v \
  -keystore "$DEST" \
  -alias sunshines \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Sunshine's Bakery LLC, OU=Android, O=Sunshine's Bakery LLC, L=Irondale, ST=AL, C=US"
cat > "$ENVF" <<EOF
# Sunshine's Bakery Play upload key. NOT in git. chmod 600.
SUNSHINES_PLAY_KEYSTORE=$DEST
SUNSHINES_PLAY_ALIAS=sunshines
SUNSHINES_PLAY_STOREPASS=$PASS
SUNSHINES_PLAY_KEYPASS=$PASS
EOF
chmod 600 "$DEST" "$ENVF"
echo "Wrote $DEST"
echo "Passwords: $ENVF"
echo "SHA-256:"
keytool -list -keystore "$DEST" -storepass "$PASS" | sed -n 's/.*SHA-256: //p'
