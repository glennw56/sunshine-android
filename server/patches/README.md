# bakery-drinks patches (apply on glennw56/bakery-local)

This agent cannot push `glennw56/bakery-local` (403) and has no GCP ADC, so Cloud Run is not redeployed from here.

## Avatar forever store

Patch: `bakery-local-avatar.patch`  
Onto: bakery-local branch `feat/square-account-routes`

```bash
cd /path/to/bakery-local
git checkout feat/square-account-routes
git apply /path/to/sunshine-android/server/patches/bakery-local-avatar.patch
# or: git am that file
```

Then the existing drinks deploy (DEPLOY.md) — same `bakery-drinks` service, `min-instances 0`, **no new VM**:

```bash
gcloud builds submit --tag REGION-docker.pkg.dev/PROJECT/bakery/bakery-drinks
gcloud run deploy bakery-drinks \
  --image REGION-docker.pkg.dev/PROJECT/bakery/bakery-drinks \
  --region REGION \
  --min-instances 0
```

Confirm: `GET /order/api/account/avatar` with a Bearer session is **401** without a token (not 404).

Monthly add: **$0**. Square custom attribute `sunshine_avatar` is the durable store.
