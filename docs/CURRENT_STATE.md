# CURRENT_STATE — Sunshine COS

## Next quality pass after 0.1.54 (this branch)

0.1.54 is still the last **public** debug APK. This branch does not ship 0.1.55 until a patio origin exists that survives this agent VM.

| Ask | Status |
| --- | --- |
| Persist patio on Cloud Run | **Blocked on bakery GCP login.** Deploy script is `tools/deploy_sunshine_explore.sh` (`sunshine-explore`, min 0 / max 1, 3600s, session affinity). This VM has gcloud 585 and **no credentialed accounts**. `bakery-drinks` has no `/explore/*` (404). Do not treat the trycloudflare URL as persistent. |
| Soften faceted patio | **In code.** Authored furniture meshes are hidden; `cute_pack.gd` drops rounded tables, planters, lamps, hedges, stalls. Logo wall + grass stay authored. |
| Remote nameplate clutter | **In code.** Local plate stays hidden. Remote plates fade 5.5–10 m and start hidden. HTTPS tick ghosts prune after 8 s idle. |
| Two-phone / two-client | **Documented + automated.** `docs/TWO_PHONE_PATIO.md`. CI: `python3 tools/two_client_patio.py` and `server/test_explore.py` TwoClientPatioTests (two HTTPS + one WSS). Godot editor: `res://tools/two_client_patio.gd`. Physical two-phone still needs Ronald. |
| Bump + APK | **Held.** Pack / owner: ship 0.1.55 only when the persistent server is real. |
| Player floating / TPP / avatar / Order / tip | Unchanged from 0.1.54. No Play upload. |

**Transport choice:** WSS on Cloud Run (Google TLS) + HTTPS `POST /explore/tick` fallback. ENet/UDP is not used — Cloud Run cannot do UDP and a 24×7 VM would crowd the $15 cap.

**Monthly cost estimate (when `sunshine-explore` is deployed):** **$0 idle** (min-instances 0, CPU throttling). Typical patio use a few hours/month: **under $2**. Always-on e2-micro: **not created** ($6–12). Stays inside the $15 bakery GCP hard cap with existing drinks.

- **Commit/build:** quality-pass on `cursor/persist-explore-patio-320e` (app version still 0.1.54 / versionCode 55 until persist)
- **Engine:** Godot 4.3, renderer `mobile`, package `shop.sunshines.bakery`
- **Official site / commerce:** [sunshinebakeshop.com](https://www.sunshinebakeshop.com/) · bakery-drinks `https://bakery-drinks-k6uuoen7wa-ue.a.run.app` · location `L4CK6YWGT5XQX`
- **Patio URL:** ephemeral tunnel only until Cloud Run exists — see `project.godot` `explore_base_url`
- **APK:** https://github.com/glennw56/sunshine-android/releases/download/v0.1.54-debug/sunshines-bakery-0.1.54-debug.apk
- **Advisor:** ChatGPT namespace still unavailable; work continued.

## Missing approval (only this)

Bakery GCP project id + `gcloud auth` (or a deploy service account JSON) so this agent can run:

```bash
GCP_PROJECT=YOUR_BAKERY_PROJECT bash tools/deploy_sunshine_explore.sh
```

Then wire `sunshine/explore_base_url`, bump to 0.1.55, and publish a debug APK. No new spend decision — owner already approved the $15 cap and scale-to-zero.

## What you can run now

1. Sideload 0.1.54 (does not include cute-pack / nameplate fade).
2. `python3 tools/two_client_patio.py` — in-process two-client proof.
3. ORDER / TIP VIA AD — 0.1.50 behavior preserved.
