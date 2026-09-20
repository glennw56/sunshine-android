# iOS TestFlight — Mac.lan checklist

Repo prep only. Builds run on **Ronald’s Mac (Mac.lan)** via
**Godot → Xcode → TestFlight**. Do **not** use a cloud Mac, CI Mac, or
rented Mac. This document does **not** mean a build was uploaded.

Apple Developer Program is paid and enrolled (Ronald confirmed). Remaining
work is local signing, App Store Connect, and the first archive.

## Identity (already set in this repo)

| Field | Value | Where |
| --- | --- | --- |
| Display name | **Sunshine's Bakery** | `project.godot` `application/config/name` (same as Android `package/name`) |
| Bundle / package id | **`shop.sunshines.bakery`** | iOS `application/bundle_identifier` and Android `package/unique_name` |
| User version | **0.1.0** | iOS `application/short_version`, Android `version/name`, `application/config/version` |
| Build number | **1** | iOS `application/version`, Android `version/code` |
| Icons | `assets/branding/sunshine-logo-girl.jpg` | iOS icon slots; Android launcher is `icon-192.png` |
| Export path | `export/ios/SunshinesBakery.xcodeproj` | Godot iOS preset (gitignored output) |

First TestFlight candidate is **0.1.0 (1)**. Nothing was bumped so Android
sideload stays on the same numbers. After the first successful upload,
increment **both** iOS `application/version` and Android `version/code`
together (and the user-facing `0.1.0` when you ship a new candidate).

## Must fill on Mac.lan (not in git)

Godot **4.3+ will refuse to export** while these are empty. Leave them
blank in the repo. Paste values only in the Godot export dialog (or
Xcode) on Mac.lan.

| Godot field | Why empty | What to put on Mac.lan |
| --- | --- | --- |
| **Application → App Store Team ID** | Secret / machine-specific | 10-character Team ID (`ABCDE12XYZ`), **not** the team display name. [developer.apple.com](https://developer.apple.com/account) → Membership details, or the Organizational Unit on the distribution cert. |
| **Provisioning Profile UUID Debug** | Xcode can create it | Leave empty for Automatic Signing. Optional override: `GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG`. |
| **Provisioning Profile UUID Release** | Xcode can create it | Leave empty for Automatic Signing. Optional override: `GODOT_IOS_PROVISIONING_PROFILE_UUID_RELEASE`. |
| **Code Sign Identity Debug / Release** | Empty = Godot defaults (`iPhone Developer` / `iPhone Distribution`) | Leave empty unless you need a specific identity. |

Never commit a Team ID, profile UUID, `.p12`, or Apple password.

## Privacy usage strings (already set)

The app does **not** use camera, microphone, or the photo library. Those
usage strings are intentionally **empty** so iOS does not show unused
permission prompts.

Godot Required Reason API defaults are set (file timestamp, system boot
time, disk space) so App Store Connect does not reject a missing
`PrivacyInfo.xcprivacy`. **Tracking is off** (`privacy/tracking_enabled=false`)
because ads default to mock. If you later ship live AdMob, turn tracking
on only after you add an App Tracking Transparency prompt and update
App Store Connect privacy answers.

`ITSAppUsesNonExemptEncryption` is `false` in the iOS preset (HTTPS only).
If you add custom crypto later, change that plist key and the App Store
Connect export-compliance answers.

## One-time Mac.lan setup

1. Install **Xcode** from the Mac App Store (current stable). Open it once,
   accept the license, and install the **iOS** platform support.
2. Xcode → **Settings → Accounts**: add the Apple ID that owns the
   enrolled Developer Program team.
3. Install **Godot 4.3 or 4.4+** matching this project (`project.godot`
   features `4.3`). **Editor → Manage Export Templates** → install the
   matching **iOS** templates (`ios.zip`).
4. Clone or pull this repo. The Godot project path is the folder that
   contains `project.godot` (example: `~/src/sunshine-android`).

## Export Xcode project (Godot)

1. On Mac.lan: `cd` to the repo root and open Godot:
   ```bash
   godot --path /path/to/sunshine-android --editor
   ```
   Or **Import** that folder in the Godot project manager.
2. **Project → Export… → iOS**.
3. Set **App Store Team ID** to the 10-character enrolled-team code.
4. Confirm:
   - Identifier: `shop.sunshines.bakery`
   - Short Version: `0.1.0`
   - Version (build): `1`
   - **Export Project Only**: on (preset default)
   - Release export method: **App Store** (for TestFlight)
5. **Export Project** → `export/ios/SunshinesBakery.xcodeproj`
   (create `export/ios/` if Godot says the folder is missing).

Godot uses `application/config/name` (**Sunshine's Bakery**) as the
visible app name. The Xcode target folder is `SunshinesBakery` so the
path has no apostrophe.

CLI equivalent (still needs Team ID filled in the preset or the export
will fail):

```bash
mkdir -p export/ios
godot --headless --path . --export-release iOS export/ios/SunshinesBakery.xcodeproj
```

## Sign, archive, upload (Xcode)

1. Open the exported project:
   ```bash
   open export/ios/SunshinesBakery.xcodeproj
   ```
2. Select the **SunshinesBakery** target → **Signing & Capabilities**.
   - **Automatically manage signing**: on
   - **Team**: the enrolled Apple Developer team (same as the Team ID)
   - Bundle Identifier: `shop.sunshines.bakery`
3. If Xcode reports the bundle id is not registered: create it under
   [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
   (App ID, explicit, `shop.sunshines.bakery`).
4. Toolbar destination: **Any iOS Device (arm64)** — not a simulator.
5. **Product → Archive**. Wait for the Organizer.
6. In Organizer: **Distribute App → App Store Connect → Upload**.
   Use automatic signing. Upload.
7. Wait for email / App Store Connect processing (often 5–30 minutes).

This checklist stops at “upload from Xcode”. Processing and tester
invites happen in App Store Connect after that. **No TestFlight build
is uploaded from this repo or any cloud agent.**

## App Store Connect app (create if missing)

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → +**
2. Platform: iOS. Name: **Sunshine's Bakery**.
3. Primary language: English (U.S.).
4. Bundle ID: **`shop.sunshines.bakery`** (must match the preset).
5. SKU: e.g. `sunshines-bakery-ios` (internal; not shown to customers).
6. After the first build processes: **TestFlight** tab → internal testers
   (up to 100). External testers need a group and may trigger Beta App
   Review.

## After the first archive

- Next upload: increment iOS `application/version` (build) — Apple rejects
  a reused build number. Keep Android `version/code` in lockstep if you
  still ship both.
- User-facing `0.1.0` / `application/short_version` / Android
  `version/name` stay put until you want testers to see a new version
  string.
- Re-export from Godot after project changes; do not hand-edit the
  generated Xcode project as the source of truth.

## Out of scope for this repo

- Apple payment / enrollment (already done).
- Storing Team ID, certs, or profiles in git.
- Claiming a TestFlight upload from CI or this cloud environment.
