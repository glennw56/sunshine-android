# Phase 2 patio room

Phase 1 stays the live origin:

`https://sunshine-explore-k6uuoen7wa-ue.a.run.app`

WebSocket hello-before-state, dirty HTTPS ticks, and the 8 Hz move cap are unchanged. Disco (`t:disco`, 20s, refresh on another bullseye hit) is in this server build. Cloud Run does not run it until someone with bakery credentials redeploys:

```bash
GCP_PROJECT=bakery-444323 bash tools/deploy_sunshine_explore.sh
curl -s https://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/health
```

Health should still show `move_hz_max` 8 and should add `disco_sec` 20.

## Dedicated VM

`tools/deploy_explore_phase2_vm.sh` is the Phase 2 path. It is not a spot VM. Spot would drop the room when Google reclaims the machine.

| Piece | Choice | About |
| --- | --- | --- |
| Machine | `e2-micro` in `us-east1` | ~$6.11/mo on-demand (730 h). $0 if this billing account’s free e2-micro in us-east1 is unused. |
| Disk | 10 GB standard | ~$0.40/mo |
| Fallback | Cloud Run `sunshine-explore`, min-instances 0 | $0 while idle |
| Cap | bakery-444323 hard $15/mo | Do not create the VM if current spend plus ~$7 would pass $15 |

The script refuses to create anything unless `EXPLORE_VM_CONFIRM=1` and `gcloud` is logged into `bakery-444323`. This agent did not run it: no credentialed account, and spend against the cap could not be read.

After the VM answers `/explore/health`, set the client:

```bash
# user://config.cfg or the environment
SUNSHINE_EXPLORE_PHASE2_URL=http://THE_VM_IP:8080
```

Or project setting `sunshine/explore_phase2_url`. On Explore join the client GETs that health URL. Success uses the VM for WSS and ticks. A failed probe or a dropped socket returns to the Phase 1 URL above.

## Bullseye

South lawn, in front of the three practice posts, world `z = 31.2`. The colored disc is 0.26 m across. Toss a cookie into that disc (not the big practice posts). Every phone in the room should see the orbs and wash for 20 seconds. A second hit during the party sets the end to 20 seconds from that hit.
