# Phase 2 patio room

Preferred origin (baked into the client):

`http://34.138.16.245:8080`

Fallback, used until that health check succeeds and again if the VM socket drops:

`https://sunshine-explore-k6uuoen7wa-ue.a.run.app`

WebSocket hello-before-state, dirty HTTPS ticks, and the 8 Hz move cap are unchanged. Disco (`t:disco`, 20s, refresh on another bullseye hit) is on both. Cloud Run revision `sunshine-explore-00008-g2h` and the VM health both include `disco_sec` 20.

```bash
curl -s http://34.138.16.245:8080/explore/health
curl -s https://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/health
```

## Dedicated VM

The live room is one **e2-micro** in **us-east1** (not spot). Spot would drop the room when Google reclaims the machine.

| Piece | Choice | About |
| --- | --- | --- |
| Machine | `e2-micro` in `us-east1` | ~$6.11/mo on-demand (730 h). $0 if this billing account’s free e2-micro in us-east1 is unused. |
| Disk | 10 GB standard | ~$0.40/mo |
| Address | `http://34.138.16.245:8080` | `sunshine/explore_phase2_url` |
| Fallback | Cloud Run `sunshine-explore`, min-instances 0 | $0 while idle |

`tools/deploy_explore_phase2_vm.sh` is the create script. It refuses unless `EXPLORE_VM_CONFIRM=1`. The VM above is already up.

On Explore join the client GETs `http://34.138.16.245:8080/explore/health`. Success uses the VM for WSS and ticks. A failed probe or a dropped socket returns to the Cloud Run URL. `SUNSHINE_EXPLORE_PHASE2_URL` or `user://config.cfg` can still override the baked default.

## Bullseye

Eating patio, just east of the right picnic table, world `(4.35, 3.05, -2.4)`. The colored disc is 0.14 m across, about 10 ft up, and stays live after a hit. Toss a cookie into that disc. Every phone in the room should see the dance floor on the open grass just west of that disc, hear the loop, and dance for 20 seconds. A second hit during the party sets the end to 20 seconds from that hit.
