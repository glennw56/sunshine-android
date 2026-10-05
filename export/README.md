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

1. Godot **4.7.2** stable matching [export templates](https://godotengine.org/download)
   (**Editor → Manage Export Templates**). Do not export with 4.3: its iOS
   template has no UIScene lifecycle and crashes on launch under the iOS 27 SDK.
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

Both export presets use **Use Gradle Build**. The Poing AdMob plugin **v5.1.0**
lives in `addons/admob/` with Godot 4.7.2 binaries under
`addons/admob/android/bin/` and `addons/admob/ios/bin/`. The Android app id is
`admob/general/android/app_id` (production `ca-app-pub-2788636443838183~1520526800`).
`ad_mode` stays **live** on release, so a Play AAB keeps the production app id and `tip_reward`. A **debug** APK writes Google's sample app id (`~3347511713`) into the manifest and requests the sample rewarded unit (`/5224354917`). Those two have to match or Google shows no test ad.

## iOS Xcode project (rewarded ads)

The iOS preset has **Export Project Only** on. Godot 4.7.2 writes an Xcode project that uses the UIScene lifecycle (`UIApplicationSceneManifest` in the exported `Info.plist`). It does not sign or upload. A Linux headless release export produces that project with Google Mobile Ads and the User Messaging Platform linked. The Mac still has to archive it. There is no iPhone Simulator on this Linux agent.

On the Mac, from this branch (Godot 4.7.2, Xcode, and the Apple team already signed in on that machine). Use **iOS Test World**, not the store **iOS** preset:

```bash
export SUNSHINE_AD_MODE=live
export SUNSHINE_ADMOB_IOS_APP_ID=ca-app-pub-2788636443838183~5610388009
export SUNSHINE_ADMOB_IOS_REWARDED_UNIT=ca-app-pub-2788636443838183/5379462878
godot --headless --path . --export-release "iOS Test World" export/test/ios/SunshineBakery.ipa
cd export/test/ios
xcodebuild -project SunshineBakery.xcodeproj -scheme SunshineBakery -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates archive -archivePath "$HOME/SunshineBakery.xcarchive"
xcodebuild -exportArchive -archivePath "$HOME/SunshineBakery.xcarchive" -exportPath "$HOME/SunshineBakery-ipa" -exportOptionsPlist ../../ios-export-options.plist -allowProvisioningUpdates
```

The first `xcodebuild` resolves Swift packages (network required): Google Mobile Ads **13.9.0** (`GoogleMobileAds`) and the User Messaging Platform **3.1.0** (`GoogleUserMessagingPlatform`). `-allowProvisioningUpdates` uses automatic signing and team `37778DSQ6T`, which is already in the Xcode project and in `export/ios-export-options.plist`. Provisioning profile UUIDs in the preset are empty. This repo has no certificate, login, or keystore. Upload `$HOME/SunshineBakery-ipa/*.ipa` with Transporter or Xcode Organizer to TestFlight. If Xcode rejects `app-store-connect`, change `method` in that plist to `app-store`. Do not submit for App Review. Do not use `--export-debug` for this TestFlight build.

The Poing iOS plugin v5.1.0 is vendored under `addons/admob/ios/bin/` (Godot 4.7.2 template zip). v5 injects frameworks at export time. Do not put legacy `ios/plugins/*.gdip` or xcframeworks back; Xcode then reports `Multiple commands produce`. Only the **AdMob** library is enabled. Mediation libraries ship in the zip and stay off, same as Android.

`GADApplicationIdentifier` in `Info.plist` is the live iOS app id `ca-app-pub-2788636443838183~5610388009`. The export reads `SUNSHINE_ADMOB_IOS_APP_ID`, then `sunshine/admob_ios_app_id`, then `admob/general/ios/app_id`. A value from Google's sample publisher `ca-app-pub-3940256099942544` is ignored. The iOS Tip unit is `ca-app-pub-2788636443838183/5379462878` for release, debug, and `ad_mode=test`. Android ids are unchanged.

TestFlight rebuild on a Mac (this agent does not archive or upload). Godot 4.7.2, Xcode, and the Apple team already signed in on that machine. Check out this branch. Do not export the store **iOS** preset.

```bash
export SUNSHINE_AD_MODE=live
export SUNSHINE_ADMOB_IOS_APP_ID=ca-app-pub-2788636443838183~5610388009
export SUNSHINE_ADMOB_IOS_REWARDED_UNIT=ca-app-pub-2788636443838183/5379462878
# Leave Android ids alone:
#   SUNSHINE_ADMOB_APP_ID=ca-app-pub-2788636443838183~1520526800
#   SUNSHINE_ADMOB_REWARDED_UNIT=ca-app-pub-2788636443838183/7894363467
godot --headless --path . --export-release "iOS Test World" export/test/ios/SunshineBakery.ipa
```

`--export-release` plus preset **iOS Test World** (custom feature `test_world`, version **0.1.90** / **92**). Do not pass `--export-debug` for TestFlight. Do not submit the archive to App Review.

Info.plist also gets:

- `NSUserTrackingUsageDescription` — required if anything requests App Tracking Transparency. This build does not call `ATTrackingManager`; ads still load without the IDFA. The string is there so a later prompt cannot crash.
- `SKAdNetworkItems` — written by the v5 ads library (Google's SKAdNetwork list) so attribution works without tracking permission.
- `AppTrackingTransparency.framework` linked by the plugin, plus `-ObjC`.

Privacy nutrition for this preset marks advertising data as collected for third-party advertising, not linked to the user and not used for tracking. Minimum iOS is **15.0**. If Xcode reports a missing Swift symbol from Google Mobile Ads, raise Minimum iOS Version to 16.0 and export again.
