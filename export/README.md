# Android sideload + Play export

Play Store **release AAB** (Closed testing, target API 36):

https://github.com/glennw56/sunshine-android/releases/download/v0.1.49-play/sunshines-bakery-0.1.49.aab

Sideload debug APK:

0.1.77 debug: Godot 4.3 Android debug export (`versionCode` 78, `export/sunshines-bakery.apk`). Release URL after cut:
https://github.com/glennw56/sunshine-android/releases/download/v0.1.77-debug/sunshines-bakery-0.1.77-debug.apk
0.1.76 debug: Godot 4.3 Android debug export (`versionCode` 77, `export/sunshines-bakery.apk`). Release URL after cut:
https://github.com/glennw56/sunshine-android/releases/download/v0.1.76-debug/sunshines-bakery-0.1.76-debug.apk
0.1.75 debug: Godot 4.3 Android debug export (`versionCode` 76, `export/sunshines-bakery.apk`). Release URL after cut:
https://github.com/glennw56/sunshine-android/releases/download/v0.1.75-debug/sunshines-bakery-0.1.75-debug.apk
0.1.74 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.74-debug/sunshines-bakery-0.1.74-debug.apk
0.1.73 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.73-debug/sunshines-bakery-0.1.73-debug.apk
0.1.72 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.72-debug/sunshines-bakery-0.1.72-debug.apk
0.1.71 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.71-debug/sunshines-bakery-0.1.71-debug.apk
0.1.70 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.70-debug/sunshines-bakery-0.1.70-debug.apk
0.1.69 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.69-debug/sunshines-bakery-0.1.69-debug.apk

0.1.68 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.68-debug/sunshines-bakery-0.1.68-debug.apk

0.1.67 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.67-debug/sunshines-bakery-0.1.67-debug.apk

0.1.66 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.66-debug/sunshines-bakery-0.1.66-debug.apk

0.1.65 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.65-debug/sunshines-bakery-0.1.65-debug.apk

0.1.64 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.64-debug/sunshines-bakery-0.1.64-debug.apk

0.1.63 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.63-debug/sunshines-bakery-0.1.63-debug.apk

0.1.62 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.62-debug/sunshines-bakery-0.1.62-debug.apk

0.1.61 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.61-debug/sunshines-bakery-0.1.61-debug.apk

0.1.60 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.60-debug/sunshines-bakery-0.1.60-debug.apk

0.1.59 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.59-debug/sunshines-bakery-0.1.59-debug.apk

0.1.58 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.58-debug/sunshines-bakery-0.1.58-debug.apk

0.1.57 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.57-debug/sunshines-bakery-0.1.57-debug.apk

0.1.56 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.56-debug/sunshines-bakery-0.1.56-debug.apk

0.1.55 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.55-debug/sunshines-bakery-0.1.55-debug.apk

0.1.54 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.54-debug/sunshines-bakery-0.1.54-debug.apk

0.1.53 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.53-debug/sunshines-bakery-0.1.53-debug.apk

0.1.50 debug: https://github.com/glennw56/sunshine-android/releases/download/v0.1.50-debug/sunshines-bakery-0.1.50-debug.apk

This folder is the default export path (`export_presets.cfg`). APKs and AABs
are gitignored. Signing secrets never live here — see `docs/PLAY_STORE.md`.

## First sideload (Gradle + AdMob)

Gradle is **on** so the vendored Poing AdMob plugin is packaged. Install the
Godot Android build template once (**Project → Install Android Build Template**).

1. Godot **4.3** matching [export templates](https://godotengine.org/download)
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

## Gradle / AdMob

Both export presets use **Use Gradle Build**. The Poing AdMob plugin v4.3.1
lives in `addons/admob/` with Android 4.3 binaries under
`addons/admob/android/bin/ads/`. Manifest `APPLICATION_ID` follows
`sunshine/admob_app_id` (production `ca-app-pub-2788636443838183~1520526800`).
`SUNSHINE_AD_MODE=test` and debug sideloads load Google’s sample rewarded unit at runtime.

## iOS Xcode project (rewarded ads)

The iOS preset has **Export Project Only** on. Godot 4.3 on Linux writes an Xcode project; it does not sign or upload.

```bash
godot --headless --path . --export-debug iOS export/ios/SunshineBakery.ipa
```

Open `export/ios/SunshineBakery.xcodeproj` on a Mac. The first Xcode build resolves Swift packages (network required): Google Mobile Ads **12.14.0** and the User Messaging Platform. Archive and upload from Xcode. Signing profiles and the App Store team login stay on that Mac; this repo does not contain them.

The Poing iOS plugin v4.3.1 is vendored at `ios/plugins/` (official `poing-godot-admob-ios-v4.3.0.zip` from the v4.3.1 release). Only the **AdMob** plugin is enabled. Meta and Vungle mediation gdips ship in that zip and stay off, same as Android.

`GADApplicationIdentifier` in `Info.plist` comes from `sunshine/admob_ios_app_id` or `SUNSHINE_ADMOB_IOS_APP_ID`. Until Ronald creates the iOS app in AdMob, that value is Google's sample `ca-app-pub-3940256099942544~1458002511`. The rewarded unit at runtime is `ca-app-pub-3940256099942544/1712485313` for test mode, debug builds, and the current live default.

Info.plist also gets:

- `NSUserTrackingUsageDescription` — required if anything requests App Tracking Transparency. This build does not call `ATTrackingManager`; ads still load without the IDFA. The string is there so a later prompt cannot crash.
- `SKAdNetworkItems` — written from the Poing `.gdip` (Google's SKAdNetwork list) so attribution works without tracking permission.
- `AppTrackingTransparency.framework` linked by the plugin, plus `-ObjC`.

Privacy nutrition for this preset marks advertising data as collected for third-party advertising, not linked to the user and not used for tracking. Minimum iOS is **15.0**. If Xcode reports a missing Swift symbol from Google Mobile Ads, raise Minimum iOS Version to 16.0 and export again.
