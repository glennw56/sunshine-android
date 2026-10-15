# Square phone account API (bakery-drinks)

The Android app never holds a Square or Twilio token. Phone **Continue**
POSTs the same bakery-drinks origin as `/order/api/menu`. No SMS OTP.

## Contract Glenn’s drinks should match

Login is **POST only**. A `session_token` on that response is preferred.
Later profile/orders/status calls send `Authorization: Bearer <session_token>`
and **must not** take a public `?phone=` query (that dumps email/orders).

| Method | Path | What |
| --- | --- | --- |
| POST | `/order/api/account/login`, `/order/api/login`, `/order/api/session`, `/order/api/account/phone`, `/order/api/customer` | SearchCustomers by phone; CreateCustomer if missing; Loyalty enroll; return `session_token` when drinks is ready |
| POST / PATCH / PUT | `/order/api/account/profile`, `/order/api/customer/profile` | Bearer session + `{ given_name, family_name, email }` → Square **UpdateCustomer**. Live drinks: POST `/order/api/account/profile`. |
| GET | `/order/api/account`, `/order/api/session`, `/order/api/me`, `/order/api/customer` | Bearer session → profile + orders |
| GET | `/order/api/account/status`, `/order/api/orders` | Bearer session → orders + queue ahead |
| DELETE | `/order/api/account`, `/order/api/customer` | Bearer session → delete the **app** account |

Glenn: if Cloud Run does not have `/order/api/account/profile` yet, copy `server/account.py` `update_customer_profile` / the profile route. The app POSTs first, then PATCH, then PUT, with `Authorization: Bearer` + `X-Session-Token`. It does not GET PII by phone.

## Account deletion

`DELETE /order/api/account` with `Authorization: Bearer <session_token>` (or `X-Session-Token`) removes app-side data for that customer:

- the forever look (avatar + username) in `SUNSHINE_AVATAR_STORE` (`avatar_store.json`)
- the Square custom attribute `sunshine_avatar`, when `SQUARE_ACCESS_TOKEN` is configured (best effort; a missing attribute is ignored)
- explore/patio avatar rows for that session and player id, when `EXPLORE_AVATAR_PATH` (default `/tmp/sunshine_avatar_store.json`) exists
- session tokens for that customer, recorded in `SUNSHINE_SESSION_REVOCATIONS` (default `session_revocations.json` next to the avatar store). A later sign-in mints a new token. Tokens issued before deletion, including older tokens that have no `iat`, stop working.

**Square customer delete is off by default.** Orders, loyalty, and the Square customer record stay unless you set:

```bash
SUNSHINE_DELETE_SQUARE_CUSTOMER=true
```

Accepted values: `1`, `true`, `yes`, `on`. Anything else, including unset, does **not** call Square `DeleteCustomer`. Leave it unset for the normal bakery deploy. Do not point this at live Square from a laptop test; the unit tests use a fake HTTP client.

If the flag is on and Square is not configured, the route returns **503** and does not wipe the local look, so the person can retry.

Cloud Run’s disk is ephemeral. Persist `SUNSHINE_AVATAR_STORE` and `SUNSHINE_SESSION_REVOCATIONS` on the same durable path you already use for the forever look, or merge this DELETE handler into the live `app/account.py` that stores `sunshine_avatar` (do not replace that custom-attribute upsert with the file-only copy). `python3 server/apply_to_bakery_local.py /path/to/bakery-local` copies this file over `app/account.py`.

The Godot client tries those POST aliases in order (404/405 → next) and
stores `session_token` / `access_token` / `token` when present.

## Apply onto bakery-local

```bash
python3 server/apply_to_bakery_local.py /path/to/bakery-local
```

`server/account.py` mints a signed `session_token` on POST and requires
Bearer on GET. Live Cloud Run may still omit the token until Glenn’s
harden lands — the app still accepts POST login bodies.

Keep `SQUARE_ACCESS_TOKEN` in Secret Manager. Optional `ACCOUNT_SESSION_SECRET`
(or `SESSION_SECRET`) for signing session tokens.

## How Ronald tests

See `HOW_TO_TEST.md`.
