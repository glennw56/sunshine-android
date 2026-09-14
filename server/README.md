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
| POST / PATCH / PUT | `/order/api/account/profile` | Bearer session + `{ given_name, family_name, email }` → Square **UpdateCustomer**. Required when login returns an empty name. |
| GET | `/order/api/account`, `/order/api/session`, `/order/api/me`, `/order/api/customer` | Bearer session → profile + orders |
| GET | `/order/api/account/status`, `/order/api/orders` | Bearer session → orders + queue ahead |

Glenn: if Cloud Run does not have `/order/api/account/profile` yet, copy `server/account.py` `update_customer_profile` / the profile route. The app POSTs first, then PATCH, then PUT, with `Authorization: Bearer` + `X-Session-Token`. It does not GET PII by phone.

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
