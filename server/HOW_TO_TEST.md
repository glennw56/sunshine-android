# How Ronald tests Square phone login

No SMS OTP. Phone **Continue** POSTs bakery-drinks. Twilio/Square secrets stay on Cloud Run.

**Sideload APK (v0.1.65-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.65-debug/sunshines-bakery-0.1.65-debug.apk

**Previous sideload (v0.1.64-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.64-debug/sunshines-bakery-0.1.64-debug.apk

**Previous sideload (v0.1.63-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.63-debug/sunshines-bakery-0.1.63-debug.apk

**Previous sideload (v0.1.62-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.62-debug/sunshines-bakery-0.1.62-debug.apk

**Previous sideload (v0.1.61-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.61-debug/sunshines-bakery-0.1.61-debug.apk

**Previous sideload (v0.1.60-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.60-debug/sunshines-bakery-0.1.60-debug.apk

**Previous sideload (v0.1.59-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.59-debug/sunshines-bakery-0.1.59-debug.apk

**Previous sideload (v0.1.58-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.58-debug/sunshines-bakery-0.1.58-debug.apk

**Previous sideload (v0.1.57-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.57-debug/sunshines-bakery-0.1.57-debug.apk

**Previous sideload (v0.1.56-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.56-debug/sunshines-bakery-0.1.56-debug.apk

**Previous sideload (v0.1.55-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.55-debug/sunshines-bakery-0.1.55-debug.apk

**Previous sideload (v0.1.54-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.54-debug/sunshines-bakery-0.1.54-debug.apk

**Previous sideload (v0.1.53-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.53-debug/sunshines-bakery-0.1.53-debug.apk

**Previous sideload (v0.1.50-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.50-debug/sunshines-bakery-0.1.50-debug.apk

**Play AAB (v0.1.49, versionCode 50, target API 36 — no new Play upload for 0.1.50):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.49-play/sunshines-bakery-0.1.49.aab

Package `shop.sunshines.bakery`. Play upload steps: `docs/PLAY_STORE.md`.

## Contract (app ↔ drinks)

| Step | App | Drinks |
| --- | --- | --- |
| Sign in | **POST** `/order/api/account/login` (then `/login`, `/session`, `/account/phone`, `/customer`) `{ "phone", "join_loyalty" }` | `{ "ok", "session_token"?, "customer", "orders", "open_orders" }` |
| Incomplete name | If `given_name` + `family_name` + `display_name` are empty, show first / last / email | Then **POST/PATCH/PUT** `/order/api/account/profile` with Bearer + `{ given_name, family_name, email }` → Square UpdateCustomer |
| Refresh / Status / orders | **GET** `/order/api/account`, `/account/status`, `/orders` with `Authorization: Bearer <session_token>` | Same payload. **No phone query.** |
| Donate progress | **GET** `/order/api/donations` (no auth) | `{ ok, goal_cents, raised_cents, donor_count, donors:[{name, amount_cents, at}] }` from Square Payments/Orders + public checkout. Live drinks is 404 until Glenn copies `server/account.py` + `server/donations.py` (`python3 server/apply_to_bakery_local.py /path/to/bakery-local`) and redeploys. App still scrapes Square’s public checkout page for goal/raised. |

The app **does not** call `GET /order/api/customer?phone=` (that dumps email/orders without a session).

If drinks has not issued `session_token` yet, Continue still uses the **POST login body** for `Hi, {name}` + previous orders, and Status uses that snapshot. Skip/guest still works.

## Probe (POST only — do not GET by phone)

```bash
python3 tools/probe_square_login.py --phone 2564525192
```

Prints customer_id, name, order count, latest order. Does not print email.

Known test phone (Ronald): **2564525192** → Square customer `YA47DPANBS1K522Y885AY4M4AM`, display name **Ronald Williamson**. Live POST login currently returns several completed drink tickets (latest: Vietnamese Coffee, 2026-09-09).

## On the v0.1.15 APK

1. Open the storefront login (or **Log out** / **Sign in**).
2. Enter `2564525192`. Leave loyalty checked. Tap **Continue** (not an OTP screen).
3. Home: **Hi, Ronald**. Full circular logo (girl + ring) visible; **no Settings**. Lawn buttons: **ORDER**, **PREVIOUS ORDERS**, **DONATE**, **TIP VIA AD**, **EXPLORE 3D**. **DONATE** (above Tip) opens the donation screen: live **Raised $X of $Y · N supporters**, a supporters list (Anonymous if no name), optional name, and **Donate with Square** → `https://square.link/u/9tUzPJZQ`. Totals come from bakery-drinks `GET /order/api/donations` when Glenn has applied `server/account.py` + `server/donations.py`; otherwise from Square’s public checkout page ($10,000 goal today). Not a fake filled bar.
4. A Square customer with no name should see **First name / Last name / Email** after Continue; Save updates Square (needs Glenn’s `/order/api/account/profile` on drinks).
5. Tap **PREVIOUS ORDERS** — cached **paid** Square tickets should appear immediately; a quiet bakery-drinks refresh fills in the rest. Unpaid OPEN checkouts, drafts, and canceled tickets stay off this list (live drinks today still returns those in `orders` with `status: making` and no tenders/`state`/`net_amount_due` — the app filters client-side; drinks should also stamp `paid` + tenders and filter server-side). The app **GET**s bakery-drinks `/order/api/orders` with Bearer (same Cloud Run; no second GCP). Tickets include drink extras (`25%`, `Lactose Free` · $0.75 on QR-13) and each line’s **Square photo** (or the neutral no-photo tile; photos fill in async). Optional **GET** `/order/api/orders/{order_id}` fills a ticket if the list is thin. Empty `modifiers: []` shows **No extras**; a missing modifiers field still says **Extras not listed on this ticket**. **Order again** loads the live catalog first and adds every line with those extras.
6. Guest / **Skip for now**: **PREVIOUS ORDERS** stays visible and asks you to sign in with phone.
7. **ORDER** opens on the **last successful Square menu** when one is cached (from a previous visit or a background prefetch on the lawn). Type is **large throughout** (lawn labels, Order, cart, Status, Previous Orders, Tip, Explore HUD, toasts) — bigger than 0.1.35, with no leftover tiny sticky-bar or HUD type. Order/menu browse photos fill **~75% of the card width**; Previous Orders, cart/checkout, and Status keep the older **96px square thumbs**. Drag on a menu **card** to scroll (you should not have to aim at the gaps). A short tap still opens the item. The sticky cart bar shows **item count only** (`1 item` / `3 items`) — names, extras, and dollars stay on the Cart tab. With items in the cart, **Clear cart** on the sticky bar empties every line (count goes back to 0 items). Entering Explore no longer toasts Fresh Batch (the HUD banner is enough). The drink list paints immediately; Square photos fill in from disk/memory without blocking. A quiet refresh runs in the background and does **not** rebuild the list unless Square catalog rows changed. First launch with no cache shows a **Loading menu…** card in the list (not a blank screen); a failed fetch shows an error and **Retry Square**. Tap a pastry (Nutella Croissant) and a drink (Coffee): **all** Square optional groups and options (Reheat, Milk, Sweet, Extra Shot, Ice, Espresso, Sauce, Boba, …). Cart **Change extras** lists what you picked. Status / Previous orders show extras on each line. **Order again** puts them back in the cart.
8. **EXPLORE 3D** should load the **outdoor eating patio** (`sunshine_outdoor_eating.glb`: tables, chairs, planters, Sunshine logo wall, 90×80 m grass). **Toss cookie** (thumb button between the sticks, or Space) throws the chocolate-chip cookie prop; guests get a playful knockback and stay on the grass. Look stays drag-only (no red/wine square). Guests and table props spawn after the first patio frame so the walk-in hitch is shorter. The **main menu stays the real photo**. Left stick + silent look drag (no LOOK arrows). You should not walk through the logo wall.
9. Order → Status = that session’s **paid making** tickets as **app order xxx** + **N ahead** (other paid making Irondale tickets). Unpaid/ready/canceled stay off Status.
10. **Log out** returns to the phone screen.

Menu prices / no Staff tab are unchanged. Explore uses the Y-up outdoor eating patio GLB (not ObjToSchematic, not the ChatGPT shop). Previous Orders + Order Again consume bakery-drinks `GET /order/api/orders` (and optional `GET /order/api/orders/{id}`).

## Two-phone patio

See `docs/TWO_PHONE_PATIO.md`. Short version: same APK on two phones → both EXPLORE 3D → walk close (nameplates fade in) → toss cookie / chat.

Laptop stand-in:

```bash
python3 tools/two_client_patio.py
python3 -m unittest server/test_explore.py
```

Persistent Cloud Run (after bakery GCP login):

```bash
GCP_PROJECT=YOUR_BAKERY_PROJECT bash tools/deploy_sunshine_explore.sh
```

That is a **sibling** `sunshine-explore` service (`min-instances 0`, `max-instances 1`), not a 24×7 VM. Drinks / Order / tip stay on `bakery-drinks`.
