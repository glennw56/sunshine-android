# Android sideload export

This folder is the default APK output path (`export_presets.cfg` →
`export/sunshines-bakery.apk`). APKs are gitignored.

## First sideload (no Gradle)

Gradle is **off** on the Android preset so you do not need
“Install Android Build Template” for the first APK.

1. Godot **4.3 or 4.4+** matching [export templates](https://godotengine.org/download)
   (**Editor → Manage Export Templates**).
2. JDK **17** and an Android SDK (`platform-tools` so `adb` works).
   In Godot: **Editor Settings → Export → Android**
   - Android SDK Path
   - Java SDK Path
   - Debug Keystore (see below)
3. **Project → Export → Android → Export Project** →
   `export/sunshines-bakery.apk`
4. Phone: enable install from this source, or
   `adb install -r export/sunshines-bakery.apk`

### Debug keystore

If the export dialog says the debug keystore is missing:

```bash
mkdir -p "$HOME/.android"
keytool -genkeypair -v -keystore "$HOME/.android/debug.keystore" \
  -alias androiddebugkey -storepass android -keypass android \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

Point Godot’s **Debug Keystore** at that file. User `androiddebugkey`,
password `android`. Never put release keystore passwords in git.

CLI helper: `bash tools/make_debug_keystore.sh`

### Command line (once templates + SDK are set in the editor)

```bash
godot --headless --path . --export-debug Android export/sunshines-bakery.apk
```

This cloud agent **cannot** produce a device APK without Android SDK +
export templates on the machine.

## Gradle / AdMob later

Turn **Use Gradle Build** on in the Android preset only when you vendor
the AdMob plugin. Then **Project → Install Android Build Template** and
follow README AdMob notes. Mock ads need neither Gradle nor Google binaries.
