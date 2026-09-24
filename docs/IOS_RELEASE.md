# iOS TestFlight (Sunshine's Bakery)

Same Godot project as the Android app. Version **0.1.76**, build **77**
(`CFBundleShortVersionString` / `CFBundleVersion`). Bundle id
**`shop.sunshines.bakery`**. Apple Team ID **`37778DSQ6T`**. No provisioning
profile, certificate, or password is stored in git.

## Godot version

Export with **Godot 4.3.stable** (official build `4.3.stable`, template folder
`4.3.stable`, `--version` starts with `4.3.stable`).

That is the editor this repo's Android export and docs use (`export/README.md`,
`docs/PLAY_STORE.md`, `project.godot` feature `4.3`). The Poing AdMob plugin in
tree is v4.3.1 for that editor. The Mac already has export templates in the
**4.3.stable** folder, including `ios.zip`.

Do **not** export with the Godot **4.7.2** app in `/Applications`. A 4.7 editor
looks for `4.7.2.stable` templates, will not load `4.3.stable/ios.zip`, and can
rewrite `config/features` away from `4.3`.

If 4.3.stable is not installed yet, download the macOS editor that matches the
templates:

https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_macos.universal.zip

Minimum iOS version in the preset is **12.0**, which is what the 4.3.stable
`ios.zip` is built for. If Xcode 27 refuses `IPHONEOS_DEPLOYMENT_TARGET = 12.0`,
raise only `application/min_ios_version` in the `iOS` preset to the lowest
version that Xcode accepts. Keep the Godot editor on 4.3.stable.

## What the preset does

`export_presets.cfg` preset name **`iOS`**:

- Bundle id `shop.sunshines.bakery`
- Team `37778DSQ6T`
- Provisioning profile UUIDs left empty, so Godot writes **Automatic** signing
- `application/export_project_only=true` (this script runs `xcodebuild`, not Godot)
- Portrait, from `display/window/handheld/orientation=1` in `project.godot`
- iPhone (the UI is the phone layout; iPad runs the iPhone compatibility mode)
- App icons for every size the Godot 4.3 exporter emits, including a
  **1024×1024 RGB PNG with no alpha**
- Launch storyboard images `assets/branding/apple/launch-2x.png` and
  `launch-3x.png` on the bakery blush ground
- `ITSAppUsesNonExemptEncryption` = false, which the Godot 4.3 template already writes (HTTPS only). `tools/ios_export.sh` also deletes the empty camera, microphone, and photo-library purpose strings the template inserts, because this app does not use those APIs.

Icons are generated from `assets/branding/sunshine-logo-girl.jpg` by
`python3 tools/make_ios_icons.py`.

## Ads

**iOS does not link AdMob.** The vendored Poing plugin is the Android build
(v4.3.1). Its iOS zip is intentionally not installed: importing that zip crashes
Godot 4.3 headless export. Shipping Google's sample ad ids in a TestFlight
build also fails AdMob policy and App Review.

On `OS.get_name() == "iOS"` the tip button reads **TIP STAFF** and credits the
staff jar through the existing thank-you confirm. No `GADApplicationIdentifier`,
no SKAdNetwork list, no App Tracking Transparency prompt. Android live/test ads
are unchanged.

## Touch, notch, home indicator

Explore already gives the stick, look pad, and toss button each their own
`ScreenTouch` index (the 0.1.76 three-finger fix). iOS keeps
`emulate_mouse_from_touch` on so menu buttons still click.

`project.godot` sets, for iOS only:

- `display/window/ios/hide_home_indicator=false` (Godot's default `true` makes
  `suppress_ui_gesture` do nothing, so one swipe from the stick leaves the app)
- `display/window/ios/suppress_ui_gesture=true` (the home indicator needs two
  swipes)
- `display/window/ios/hide_status_bar=true` (same full-screen feel as Android)

`IosSafeArea` pads every `MarginContainer` named `Safe`, and lifts the Explore
stick, toss button, and top bar by `DisplayServer.get_display_safe_area()`, so
the notch and home indicator are not covering controls. It does nothing when
`OS.get_name()` is not `iOS`.

## Commands (owner's Mac)

1. Install **Godot 4.3.stable** as above. Confirm:

   ```bash
   /Applications/Godot_v4.3-stable.app/Contents/MacOS/Godot --version
   ```

   The line must start with `4.3.stable`. Point `GODOT_BIN` at the binary if
   you unpacked it somewhere else.

2. Sign in to **Xcode → Settings → Accounts** with the Apple ID that is on team
   **37778DSQ6T**. Select that team. Xcode 27 must be the active developer
   directory (`sudo xcode-select -s /Applications/Xcode.app`).

3. In App Store Connect, create the app **Sunshine's Bakery** with bundle id
   `shop.sunshines.bakery` if it does not exist yet. Automatic signing can
   register the id only when that Apple ID is allowed to.

4. From the repo root:

   ```bash
   bash tools/ios_export.sh
   ```

   That runs, in order:

   ```bash
   godot --headless --path . --export-release "iOS" export/ios/SunshineBakery.ipa
   ```

   (`export_project_only` writes `export/ios/SunshineBakery.xcodeproj` and does
   not codesign.)

   ```bash
   xcodebuild archive \
     -project export/ios/SunshineBakery.xcodeproj \
     -scheme SunshineBakery \
     -configuration Release \
     -destination 'generic/platform=iOS' \
     -archivePath export/ios/SunshineBakery.xcarchive \
     -allowProvisioningUpdates \
     DEVELOPMENT_TEAM=37778DSQ6T \
     CODE_SIGN_STYLE=Automatic \
     PRODUCT_BUNDLE_IDENTIFIER=shop.sunshines.bakery
   ```

   ```bash
   xcodebuild -exportArchive \
     -archivePath export/ios/SunshineBakery.xcarchive \
     -exportPath export/ios/ipa \
     -exportOptionsPlist tools/ios_ExportOptions.plist \
     -allowProvisioningUpdates
   ```

   `tools/ios_ExportOptions.plist` uses `method` = `app-store-connect`,
   `signingStyle` = `automatic`, `teamID` = `37778DSQ6T`, and `destination` =
   `export` (writes an `.ipa` on disk).

5. The first archive often asks you to sign in again or to allow keychain
   access for the Apple ID. Let that dialog finish. Nothing in this repo can
   answer it.

6. Upload the IPA either way:

   - `bash tools/ios_export.sh --upload` (same plist with `destination` =
     `upload`, so `xcodebuild -exportArchive` sends it to App Store Connect)
   - Xcode → **Window → Organizer** → the archive → **Distribute App** →
     App Store Connect
   - `xcrun altool --upload-app -f export/ios/ipa/*.ipa -t ios -u "APPLE_ID" -p "@keychain:AC_PASSWORD"`

   `altool` needs an app-specific password in the keychain item `AC_PASSWORD`,
   or an App Store Connect API key. Those stay on the Mac, not in git.

Godot-only (no `xcodebuild`), including on a Linux machine that has the
4.3.stable editor and `ios.zip`:

```bash
bash tools/ios_export.sh --export-only
```

## What you still do by hand

- Xcode Apple ID login and the first provisioning prompt (above).
- App Store Connect app record, screenshots, age rating, and the privacy
  policy URL (same gap as the Play listing; this repo does not invent one).
- Privacy nutrition label, using the table below.
- Export compliance: the generated Info.plist sets
  `ITSAppUsesNonExemptEncryption` to false. If Connect still asks, answer
  **No** (HTTPS only).
- Do not commit `export/ios/`, profiles, or certificates.

## App Store privacy nutrition label

Answer these in App Store Connect for **this iOS build**. Data is linked to
the user when they are signed in. None of it is used for tracking. The iOS
binary does not include the Google Mobile Ads SDK.

| Data type | Collected | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Name | Yes | Yes | No | App Functionality (account profile; optional name on a donation) |
| Email address | Yes | Yes | No | App Functionality (account profile) |
| Phone number | Yes | Yes | No | App Functionality (sign-in) |
| User ID | Yes | Yes | No | App Functionality (bakery account id and Explore player id) |
| Purchase History | Yes | Yes | No | App Functionality (previous Square orders shown in the app) |
| Product Interaction | Yes | Yes | No | App Functionality (menu, cart, Explore session sent to the bakery servers) |
| Gameplay Content | Yes | Yes | No | App Functionality (patio chat and avatar look) |

Do **not** declare:

- **Payment Info.** Card data is entered on Square's hosted checkout in the
  system browser, not in this app. The app only receives a checkout URL.
- **Advertising Data** or **Device ID.** No AdMob and no IDFA on iOS. Do not
  turn on tracking, and do not add an ATT usage string unless a later build
  actually links an ad SDK.
- **Precise or Coarse Location.** The Irondale address is a constant in the
  app. The device location is not read.
- **Photos or Videos.** Menu photos are downloaded from the bakery catalog.
  The photo library is not requested.
- **Contacts, Health, Crash Data, Performance Data.** No third-party crash or
  analytics SDK is linked.

Third parties that receive the data above: the bakery's existing order and
Explore services, and Square when the customer continues to Square's web
checkout or the existing donate link. No Square secret or live Square
configuration is changed by this export.
