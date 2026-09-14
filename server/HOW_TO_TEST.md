# How Ronald tests Square phone login

No SMS OTP. Phone **Continue** POSTs bakery-drinks. Twilio/Square secrets stay on Cloud Run.

**Sideload APK (v0.1.18-debug):**
https://github.com/glennw56/sunshine-android/releases/download/v0.1.18-debug/sunshines-bakery-0.1.18-debug.apk

Package `shop.sunshines.bakery`, versionName **0.1.18**, versionCode **19**.

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
5. Tap **PREVIOUS ORDERS** — Square tickets (name, date, total, items). **Order again** adds matching catalog items to the cart when the drink is still on the Square menu.
6. Guest / **Skip for now**: **PREVIOUS ORDERS** stays visible and asks you to sign in with phone.
7. **ORDER** → tap a drink: extras chips (selected = wine + ✓). Add to cart → sticky bar and Cart list those modifiers. Status / Previous orders show extras on each line. **Order again** puts them back in the cart.
8. **EXPLORE 3D** should load the denser bakery **GLB** (`Sunshines_Bakery_Storefront_Godot4.glb`, ~233 meshes) as the walkable storefront (white + blush pink, orange sign + letters, logo disc, neighbor, road). The **main menu stays the real photo**. Left stick + silent look drag (no LOOK arrows). You should not walk through the facade.
9. Order → Status = that session’s open tickets + **N ahead**.
10. **Log out** returns to the phone screen.

Menu prices / no Staff tab are unchanged. Explore uses the denser trimesh bakery GLB (not ObjToSchematic).
