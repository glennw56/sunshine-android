# Two-phone patio test (Ronald)

The patio is one shared Cloud Run process (`sunshine-explore`, min 0 / max 1). Phones are never the host. Same APK on both phones. No Play upload.

## What you need

- Two Android phones on **different networks** if you can (phone Wi-Fi + phone LTE is enough). Same Wi-Fi still proves the room; different networks prove it is not LAN broadcast.
- The current debug APK from the GitHub release notes.
- Both phones signed into **different** Sunshine accounts, or one signed-in + one Skip/guest.

## Steps

1. Sideload the same APK on both phones (`shop.sunshines.bakery`).
2. Phone A: Continue with your number → **EXPLORE 3D**.
3. Phone B: Continue with a second number (or Skip) → **EXPLORE 3D**.
4. Walk toward each other on the lawn. You should see the other baker’s rounded chibi.
5. Nameplates appear only when you are close (they fade out past ~10 m so the patio is not a wall of labels).
6. **Toss cookie** on A **at B** — B should **feel** a shove + lean-back flinch, and both phones get crumbs for that `proj_id`. Hits are **client-predicted**: inbound throws arm `hits_local` immediately (no 0.1s baker grace). The server only relays `throw` + `impact`. NPC guests still knock on grass.
7. Type a short chat line on A — B should see it plus **Mute / Block / Report**. Banned words stay blocked.
8. Leave Explore on A. A should vanish on B right away (WSS disconnect or `POST /explore/leave`). If A force-quits, wait ~12 seconds on HTTPS / ~45 seconds on WSS for idle prune.
9. Lock Phone A, wait a few seconds, unlock, walk — you rejoin the same Cloud Run patio (HTTPS seats drop after ~12s idle; the process stays up while anyone else is still ticking, then scales to zero).

If the HUD says `Patio using HTTPS`, that is expected on some TLS paths. Movement still shares through `POST /explore/tick`. `Patio · live` on WebSocket is the preferred path on Google-managed TLS. HTTPS clients POST `/explore/leave` when they leave Explore so smoke ghosts cannot sit in the 16-cap until Cloud Run dies. See `docs/ROOM_SERVER.md` (How the room clears).

## Laptop / CI stand-in (no second phone)

Two scripted clients join one room and assert both names in the snapshot:

```bash
# In-process (CI / editor machine, no network)
python3 tools/two_client_patio.py

# Against the persistent Cloud Run origin
python3 tools/two_client_patio.py https://sunshine-explore-k6uuoen7wa-ue.a.run.app

# Godot editor / headless, uses project.godot explore_base_url
godot --headless --path . --script res://tools/two_client_patio.gd
```

`python3 -m unittest server/test_explore.py` includes the same two-client HTTP + WebSocket case.

This is **not** a substitute for the two-phone walk-around. It does prove the room accepts two joiners and replicates state.