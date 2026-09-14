# How Ronald tests Square phone login

No SMS. The APK talks only to bakery-drinks. The Square token stays on Cloud Run.

## 1. Redeploy bakery-drinks (required once)

This Cloud Agent cannot push `glennw56/bakery-local` or run `gcloud`.
Until drinks has the routes, Continue shows:

`Square login is not on bakery-drinks yet…`

On a laptop that can deploy drinks (Square catalog branch):

```bash
# in bakery-local
cp /path/to/sunshine-android/server/account.py app/account.py
# add: from app import account as account_svc
# add: account_svc.mount(app)
# then the same gcloud run deploy you already use for bakery-drinks
```

Confirm:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  -d '{"phone":"+12055550123","join_loyalty":true}' \
  https://bakery-drinks-k6uuoen7wa-ue.a.run.app/order/api/customer
```

A working service returns JSON with `"ok": true` and `"customer": {"id": "..."}`.
HTTP 404 means the routes are not on Cloud Run yet.
HTTP 403 means the token needs CUSTOMERS_READ / CUSTOMERS_WRITE / ORDERS_READ.

Or: `python3 tools/probe_square_login.py --phone 2055550123`

## 2. Pick a phone

**Known customer (best):** Square Dashboard → Customers → open someone with a
name and past tickets → use that 10-digit US phone.

**New phone:** any unused US number. The app creates a Square Customer and
enrolls loyalty if a program exists. Name may be empty (`Hi there`) and
previous orders empty until they buy.

Do not invent a local customer list. If Square has no name, the app will not
make one up.

## 3. On the v0.1.10 APK

1. Open the app (phone login on the storefront photo).
2. Enter the 10-digit number. Leave **Join Sunshine’s Bakery loyalty / save your orders** checked.
3. Tap **Continue**.
4. **Found:** home says `Hi, {given / family / nickname}` and lists **Previous orders** (name · date · total) or “No Square orders on this phone yet.”
5. **Order → Status** shows only that customer’s open tickets and **N ahead**.
6. Kill and reopen: still signed in. **Log out** returns to the phone screen. **Skip for now** is guest (no name, Status asks to sign in).

Menu prices / Explore / no Staff tab are unchanged.
