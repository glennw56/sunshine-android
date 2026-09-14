# How Ronald tests Square phone login

No SMS. The APK talks only to bakery-drinks. The Square token stays on Cloud Run.

**Sideload APK (v0.1.10-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.10-debug/sunshines-bakery-0.1.10-debug.apk

Package `shop.sunshines.bakery`, versionName **0.1.10**, versionCode **11**.

Continue on the phone **cannot** return a Square name until bakery-drinks has
the customer routes. Live probe on 2026-09-14:

`GET /order/api/customer?phone=` → HTTP **404** `{"detail":"Not Found"}`

Skip for now / guest still works without that deploy.

## 1. Redeploy bakery-drinks (required once)

This Cloud Agent cannot push `glennw56/bakery-local` or run `gcloud`.
On a laptop that already deploys drinks (Square catalog branch):

```bash
# sunshine-android + bakery-local checkouts
python3 /path/to/sunshine-android/server/apply_to_bakery_local.py /path/to/bakery-local
# then the same gcloud run deploy you already use for bakery-drinks
```

That copies `server/account.py` → `app/account.py` and mounts:

| Method | Path | Square |
| --- | --- | --- |
| POST | `/order/api/customer` and `/order/api/account/phone` | SearchCustomers by phone; CreateCustomer if missing; Loyalty enroll |
| GET | `/order/api/customer?phone=` | SearchCustomers + profile |
| GET | `/order/api/orders?customer_id=` | SearchOrders for that customer + queue ahead |
| GET | `/order/api/account` / `/order/api/account/status` | same payload aliases |

Keep `SQUARE_ACCESS_TOKEN` in Secret Manager. If Continue **403**s after
deploy, add scopes **CUSTOMERS_READ, CUSTOMERS_WRITE, ORDERS_READ**, plus
**LOYALTY_READ / LOYALTY_WRITE** to enroll.

Confirm (GET only — do not `--create` unless you intend to create a customer):

```bash
python3 tools/probe_square_login.py --phone 205XXXXXXX
```

A working service prints `customer_id=… name=… orders=N`.
HTTP 404 means the routes are not on Cloud Run yet.

## 2. Pick a phone

**Known customer (this is the done check):** Square Dashboard → Customers →
open someone who already has a **name** and past tickets → use that 10-digit
US number.

**New unused phone:** the app creates a Square Customer and enrolls loyalty
if a program exists. Home is often `Hi there` with “No Square orders on this
phone yet.”

Do not invent a local customer list. If Square has no name, the app will not
make one up.

## 3. On the v0.1.10 APK

1. Install the APK above. Open the app (phone login on the storefront photo).
   If you already skipped, tap **Log out** / **Sign in** on the home lawn.
2. Enter the 10-digit Dashboard number. Leave **Join Sunshine’s Bakery loyalty / save your orders** checked.
3. Tap **Continue**.
4. **Found:** home says `Hi, {given / family / nickname}` and lists **Previous orders**
   (name · date · total) or “No Square orders on this phone yet.”
5. **Order → Status** shows only that customer’s open tickets and **N ahead**.
6. Kill and reopen: still signed in. **Log out** returns to the phone screen.
   **Skip for now** is guest (no name, Status asks to sign in).

Menu prices / Explore / no Staff tab are unchanged.
