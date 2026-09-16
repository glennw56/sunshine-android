# Play Store internal testing (Sunshine’s Bakery)

Package **`shop.sunshines.bakery`**. This is a **release AAB** for Play Console
internal testing, not a debug APK.

This agent does **not** upload to Play Console. Identity / device / phone
verification on the developer account may still block publish.

## Build that is ready to upload

| Field | Value |
| --- | --- |
| versionName | **0.1.43** |
| versionCode | **44** |
| package | `shop.sunshines.bakery` |
| target API | **36** (compileSdk 36; minSdk 21) |
| format | Android App Bundle (`.aab`) |
| GitHub | https://github.com/glennw56/sunshine-android/releases/download/v0.1.43-play/sunshines-bakery-0.1.43.aab |

Play Console rejected **0.1.42** (`targetSdk 34`). This bundle targets **API 36**.

Includes latest `main` plus the stacked product PRs through Status **0.1.41**
(paid making + **app order xxx** + ahead) and ORDER-tap loading **0.1.40**.

## Signing (upload key)

A **new** Play upload keystore was generated on the cloud agent. It is **not**
in git. Godot requires the keystore password and key password to be the same.

**0.1.43 is signed with the same upload key as 0.1.42.** Do not generate a
second keystore if the files below still exist.

| | |
| --- | --- |
| Keystore (agent VM) | `/home/ubuntu/.local/share/godot/keystores/sunshines-play-release.keystore` |
| Passwords (agent VM) | `/home/ubuntu/.local/share/godot/keystores/sunshines-play-release.env` (mode 600) |
| Alias | `sunshines` |
| Validity | 2026-09-16 → 2054-02-01 |
| SHA-1 | `D1:AC:C4:67:CC:35:B0:73:54:CB:52:C5:67:02:F8:BA:60:F5:3A:49` |
| SHA-256 | `BD:BD:06:D3:D4:1D:B1:30:45:47:6B:43:9C:27:64:43:CA:EC:D5:3A:C6:D4:E1:78:64:F8:33:CF:37:15:4E:5C` |
| DN | `CN=Sunshine's Bakery LLC, OU=Android, O=Sunshine's Bakery LLC, L=Irondale, ST=AL, C=US` |

**Ronald / CoS backup (do this before the agent VM is deleted):**

1. Copy **both** the `.keystore` and the `.env` off the VM to a password manager
   or encrypted drive (1Password / Bitwarden attachment, or an encrypted USB).
2. Do **not** commit them, do **not** attach them to the GitHub release, do
   **not** paste passwords into Slack.
3. Keep one extra offline copy. Losing this keystore means you cannot update
   the Play listing unless Play App Signing already holds a separate app-signing
   key (see below).
4. After backup, shred the `.env` from any laptop download folder; keep only
   the password manager copy.

Rebuild on a machine that has the files:

```bash
export SUNSHINES_PLAY_ENV=/path/to/sunshines-play-release.env
# Godot 4.3 + JDK 17 + Android SDK 36 (platforms;android-36 + build-tools;36.0.0)
# + export templates, then:
# Project → Install Android Build Template  (extracts to android/build, gitignored)
# tools/export_play_aab.sh patches that template's compileSdk/targetSdk to 36.
bash tools/export_play_aab.sh
```

Play preset: `export_presets.cfg` **Android Play** has `gradle_build/target_sdk="36"`.

## Play Console upload (internal testing)

Developer account context (for the human who clicks Upload): **sunshines bakery llc**,
Play Console ID `6858675150063668312`, login `koolaiddhackerman@gmail.com`.
Identity / device / phone verification may still be pending — that is a Console
blocker, not an AAB blocker.

1. Open [Play Console](https://play.google.com/console) → the Sunshine’s Bakery app
   (create the app first if it does not exist: app name **Sunshine's Bakery**,
   default language English (US), app or game → app, free).
2. **Release → Testing → Internal testing → Create new release**.
3. Turn on **Play App Signing** if prompted (recommended). First upload: this
   AAB’s key becomes the *upload* key; Google keeps the *app signing* key.
4. Upload `sunshines-bakery-0.1.43.aab` (not 0.1.42 — that one targeted API 34).
5. Release name: `0.1.43 (44)`. Notes: internal build — Square Order, Status
   paid making + app order numbers, storefront lawn, Explore patio, **target API 36**.
6. Save → Review → **Start rollout to Internal testing**.
7. Add testers (email list or Google Group). They install from the internal
   testing link, not the public store.

Do not use the debug APK (`*-debug.apk`) on Play — Play rejects debug-signed
binaries.

## Blockers / not done here

- This agent **did not** upload to Play Console.
- Play Console identity / phone / device verification may still be incomplete.
- Store listing copy, screenshots, privacy policy URL, content rating, and
  Data safety form are still required before production.
- `android/build` (Gradle template) is gitignored; each machine must install
  it once (**Project → Install Android Build Template**). Godot 4.3 still
  ships compileSdk 34; `tools/export_play_aab.sh` raises it to 36 for the AAB.
- First Play upload of this package name locks the signing story. Back up the
  upload keystore before deleting the agent VM.
