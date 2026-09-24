#!/usr/bin/env bash
# Export Sunshine's Bakery for TestFlight.
# Godot 4.3.stable writes the Xcode project. Xcode 27 archives and exports the IPA.
# No provisioning profile or certificate is read from git.
#
#   bash tools/ios_export.sh                 # Xcode project + archive + IPA
#   bash tools/ios_export.sh --export-only   # Godot Xcode project only
#   bash tools/ios_export.sh --upload        # also upload the IPA to App Store Connect
#
# Override the editor with GODOT or GODOT_BIN. The binary's --version must
# start with 4.3.stable. Godot 4.7.2 will not see the installed 4.3.stable templates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

UPLOAD=0
EXPORT_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    --export-only) EXPORT_ONLY=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

is_godot_43_stable() {
  local bin="$1"
  [[ -n "$bin" && -x "$bin" ]] || return 1
  local ver
  ver="$("$bin" --version 2>/dev/null || true)"
  # 4.3.stable.official.<hash>. Reject 4.3.1.stable and 4.7.x.
  [[ "$ver" == 4.3.stable* ]]
}

pick_godot() {
  local candidate
  local -a candidates=()
  if [[ -n "${GODOT_BIN:-}" ]]; then
    candidates+=("$GODOT_BIN")
  fi
  if [[ -n "${GODOT:-}" ]]; then
    candidates+=("$GODOT")
  fi
  candidates+=(
    "/Applications/Godot_v4.3-stable.app/Contents/MacOS/Godot"
    "/Applications/Godot 4.3.app/Contents/MacOS/Godot"
    "$HOME/Applications/Godot_v4.3-stable.app/Contents/MacOS/Godot"
    "/tmp/godot/Godot_v4.3-stable_linux.x86_64"
    "/tmp/godot/Godot_v4.3-stable_macos.universal"
  )
  # /Applications/Godot.app on the owner's Mac is 4.7.2. Accept it only if
  # --version really is 4.3.stable.
  candidates+=(
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
  )
  for candidate in "${candidates[@]}"; do
    if is_godot_43_stable "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

GODOT_PATH="$(pick_godot || true)"
if [[ -z "$GODOT_PATH" ]]; then
  echo "Need Godot 4.3.stable. The iOS templates on this Mac live in the 4.3.stable folder." >&2
  echo "Godot 4.7.2 in /Applications cannot export this project." >&2
  echo "Install https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_macos.universal.zip" >&2
  echo "or set GODOT_BIN to that editor and re-run." >&2
  exit 1
fi

echo "Using $GODOT_PATH ($("$GODOT_PATH" --version))"

EXPORT_DIR="$ROOT/export/ios"
mkdir -p "$EXPORT_DIR"
# Godot 4.3 requires the destination directory to already exist.
"$GODOT_PATH" --headless --path "$ROOT" --export-release "iOS" "$EXPORT_DIR/SunshineBakery.ipa"
# Godot 4.3's iOS template writes empty camera/mic/photo purpose strings even
# when the app does not use those APIs. Drop the empty keys so App Review does
# not treat them as a permission request. The template already sets
# ITSAppUsesNonExemptEncryption to false; drop a duplicate if one was appended.
python3 - "$EXPORT_DIR" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
empty_keys = (
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
)
for plist in root.rglob("*-Info.plist"):
    text = plist.read_text()
    for key in empty_keys:
        text = text.replace(f"\t<key>{key}</key>\n\t<string></string>\n", "")
    marker = "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false />\n"
    extra = "\t<key>ITSAppUsesNonExemptEncryption</key><false/>\n"
    if marker in text:
        text = text.replace(extra, "")
    plist.write_text(text)
    print("cleaned", plist)
PY

XCODEPROJ="$EXPORT_DIR/SunshineBakery.xcodeproj"
if [[ ! -d "$XCODEPROJ" ]]; then
  echo "Godot did not write $XCODEPROJ" >&2
  exit 1
fi
echo "Xcode project: $XCODEPROJ"

if [[ "$EXPORT_ONLY" == "1" ]]; then
  echo "Stopped after the Godot export (--export-only)."
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "xcodebuild archive runs on the Mac. The Xcode project is ready." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode 27 and select it with: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi

echo "Sign in to Xcode → Settings → Accounts with the Apple ID on team 37778DSQ6T before this archive."
echo "The first -allowProvisioningUpdates run may prompt for that Apple ID."

ARCHIVE="$EXPORT_DIR/SunshineBakery.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project "$XCODEPROJ" \
  -scheme "SunshineBakery" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=37778DSQ6T \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  PRODUCT_BUNDLE_IDENTIFIER=shop.sunshines.bakery

PLIST_SRC="$ROOT/tools/ios_ExportOptions.plist"
PLIST="$(mktemp -t sunshine-export-options).plist"
cp "$PLIST_SRC" "$PLIST"
if [[ "$UPLOAD" == "1" ]]; then
  # destination=upload sends the IPA to App Store Connect from xcodebuild.
  python3 - "$PLIST" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace("<string>export</string>", "<string>upload</string>", 1)
path.write_text(text)
PY
fi

IPA_DIR="$EXPORT_DIR/ipa"
rm -rf "$IPA_DIR"
mkdir -p "$IPA_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$IPA_DIR" \
  -exportOptionsPlist "$PLIST" \
  -allowProvisioningUpdates

echo "Archive: $ARCHIVE"
if [[ "$UPLOAD" == "1" ]]; then
  echo "xcodebuild uploaded the archive to App Store Connect (destination=upload)."
else
  echo "IPA directory: $IPA_DIR"
  echo "Upload from Xcode → Window → Organizer, or:"
  echo "  xcrun altool --upload-app -f \"$IPA_DIR\"/*.ipa -t ios -u \"APPLE_ID\" -p \"@keychain:AC_PASSWORD\""
fi
