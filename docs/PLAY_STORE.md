# Play Store closed testing (Sunshine’s Bakery)

Package **`shop.sunshines.bakery`**. This is a **release AAB** for Play Console
**Closed testing**, not a debug APK.

This agent does **not** upload to Play Console. CoS uses the browser session.

## Build that is ready to upload

| Field | Value |
| --- | --- |
| versionName | **0.1.76** |
| versionCode | **77** |
| package | `shop.sunshines.bakery` |
| target API | **36** (compileSdk 36; minSdk 24) |
| format | Android App Bundle (`.aab`) |
| AAB (this VM) | `export/sunshines-bakery.aab` (also `export/sunshines-bakery-0.1.76.aab` after copy) |

Release name in Console: **`0.1.76 (77)`**.

## Signing (upload key) — reset 2026-09-21

The 2026-09-16 upload keystore (0.1.42–0.1.46, SHA-1 `D1:AC:C4:67:…`) lived only on a
deleted agent VM and was **never backed up**. Play App Signing is **ON**, so the
app-signing key stays at Google. A **new upload key** was generated on this VM.
Register it in Console via **Request upload key reset** before the AAB will be
accepted.

| | |
| --- | --- |
| Keystore (agent VM) | `/home/ubuntu/.local/share/godot/keystores/sunshines-play-release.keystore` |
| Passwords (agent VM) | `/home/ubuntu/.local/share/godot/keystores/sunshines-play-release.env` (mode 600) |
| Alias | `sunshines` |
| Validity | 2026-09-21 → 2054-02-06 |
| SHA-1 | `46:56:DD:78:30:DA:DF:3D:AF:40:8F:DA:52:CA:58:59:F0:48:B7:E4` |
| SHA-256 | `52:FD:C1:AA:08:C5:B6:C0:46:78:5F:EB:FC:95:22:4C:FB:19:B8:77:A3:9A:37:63:AB:EA:5B:2B:89:D3:28:75` |
| DN | `CN=Sunshine's Bakery LLC, OU=Android, O=Sunshine's Bakery LLC, L=Irondale, ST=AL, C=US` |
| Upload cert (public) | `export/sunshines-upload-cert.pem` (DER sibling `.der`) |

Godot requires the keystore password and key password to be the same. Secrets
are **not** in git.

### Ronald — back up BOTH files to 1Password THIS TIME

Do this **before this agent VM is deleted**. The last keystore was lost because
it was never copied off the box.

1. Copy **both** files into a 1Password Secure Note / Document on the Sunshine’s
   Bakery vault:
   - `sunshines-play-release.keystore`
   - `sunshines-play-release.env`
2. Title the item **Sunshine Bakery Play upload key (2026-09-21)** and paste the
   SHA-1 / SHA-256 above so you can match Console later.
3. Keep one extra offline copy (encrypted USB). Do **not** commit either file,
   do **not** attach them to a GitHub release, do **not** paste the password into
   Slack or chat.
4. After 1Password has both attachments, delete any laptop download copies.
5. Losing this keystore again means another upload-key reset in Play Console.

Rebuild on a machine that has the files:

```bash
export SUNSHINES_PLAY_ENV=/path/to/sunshines-play-release.env
# Godot 4.3 + JDK 17 + Android SDK 36, then:
# Project → Install Android Build Template
bash tools/export_play_aab.sh
```

## CoS — register the new upload key, then Closed testing

Developer account: **sunshines bakery llc**, Play Console ID
`6858675150063668312`, login `koolaiddhackerman@gmail.com`.

1. Play Console → Sunshine's Bakery (`shop.sunshines.bakery`).
2. **Setup → App signing** (or **Release → Setup → App integrity**).
3. **Request upload key reset** / register a new upload key.
4. Attach **`export/sunshines-upload-cert.pem`** (PEM). Confirm Console shows
   SHA-1 `46:56:DD:78:30:DA:DF:3D:AF:40:8F:DA:52:CA:58:59:F0:48:B7:E4`.
5. Wait until Google accepts the reset (often minutes; can be longer).
6. **Release → Testing → Closed testing → Create new release**.
7. Upload the 0.1.76 AAB. Release name: `0.1.76 (77)`.
8. Paste the tester notes below → Save → Review → **Start rollout to Closed
   testing**.
9. Testers: https://play.google.com/apps/testing/shop.sunshines.bakery

Do not use a `*-debug.apk` on Play.

### Closed-testing release notes

```
Closed test 0.1.76 — please poke at this and tell us what still feels off.

• Patio multiplayer should feel smoother (less snap / rubber-band; throw while you keep walking).
• Three-finger patio: left stick + look + Toss cookie can all stay down at once.
• UI/controls polish from the last sideloads (Order category chips stay put, Donate progress, centered baker).

Known check: hold move, drag look, tap Toss — cookie should leave the hand and remotes should still see it.
```

## Blockers / not done in-repo

- Upload to Play Console is a Console UI step (CoS browser session).
- Store listing copy, screenshots, privacy policy URL, content rating, and
  Data safety form are still required before production.
- `android/build` (Gradle template) is gitignored; each machine must install
  it once. `tools/export_play_aab.sh` raises compileSdk/targetSdk to 36.
