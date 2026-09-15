# How Ronald tests Square phone login

No SMS OTP. Phone **Continue** POSTs bakery-drinks. Twilio/Square secrets stay on Cloud Run.

**Sideload APK (v0.1.32-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.32-debug/sunshines-bakery-0.1.32-debug.apk

Package `shop.sunshines.bakery`, versionName **0.1.32**, versionCode **33**.

## Contract (app ↔ drinks)

| Step | App | Drinks |
| --- | --- | --- |
| Sign in | **POST** `/order/api/account/login` (then `/login`, `/session`, `/account/phone`, `/customer`) `{ "phone", "join_loyalty" }` | `{ "ok", "session_token"?, "customer", "orders", "open_orders" }` |
| Incomplete name | If `given_name` + `family_name` + `display_name` are empty, show first / last / email | Then **POST/PATCH/PUT** `/order/api/account/profile` with Bearer + `{ given_name, family_name, email }` → Square UpdateCustomer |
| Refresh / Status / orders | **GET** `/order/api/account`, `/account/status`, `/orders` with `Authorization: Bearer <session_token>` | Same payload. **No phone query.** |

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
3. Home: **Hi, Ronald**. Full circular logo (girl + ring) visible; **no Settings**. Lawn buttons: **ORDER**, **PREVIOUS ORDERS**, **TIP VIA AD**, **EXPLORE 3D**.
4. A Square customer with no name should see **First name / Last name / Email** after Continue; Save updates Square (needs Glenn’s `/order/api/account/profile` on drinks).
5. Tap **PREVIOUS ORDERS** — the app **GET**s bakery-drinks `/order/api/orders` with Bearer (same Cloud Run; no second GCP). Tickets include drink extras (`25%`, `Lactose Free` · $0.75 on QR-13) and each line’s **Square photo** (or the neutral no-photo tile). Optional **GET** `/order/api/orders/{id}` fills a ticket if the list is thin. Empty `modifiers: []` shows **No extras**; a missing modifiers field still says **Extras not listed on this ticket**. **Order again** loads the live catalog first and adds every line with those extras.
6. Guest / **Skip for now**: **PREVIOUS ORDERS** stays visible and asks you to sign in with phone.
7. **ORDER** opens on the **last successful Square menu** when one is cached (from a previous visit or a background prefetch on the lawn). A quiet refresh runs in the background. First launch with no cache still shows **Loading Square menu…**. Tap a pastry (Nutella Croissant) and a drink (Coffee): **all** Square optional groups and options (Reheat, Milk, Sweet, Extra Shot, Ice, Espresso, Sauce, Boba, …). Cart **Change extras** and the sticky bar list what you picked. Status / Previous orders show extras on each line. **Order again** puts them back in the cart.
8. **EXPLORE 3D** should load the **outdoor eating patio** (`sunshine_outdoor_eating.glb`: tables, chairs, planters, Sunshine logo wall, 90×80 m grass). The **main menu stays the real photo**. Left stick + silent look drag (no LOOK arrows, no red/wine square in the bottom-right). You should not walk through the logo wall.
9. Order → Status = that session’s open tickets + **N ahead**.
10. **Log out** returns to the phone screen.

Menu prices / no Staff tab are unchanged. Explore uses the Y-up outdoor eating patio GLB (not ObjToSchematic, not the ChatGPT shop). Previous Orders + Order Again consume bakery-drinks `GET /order/api/orders` (and optional `GET /order/api/orders/{id}`). Do **not** stand up a second GCP service.
