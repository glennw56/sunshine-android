# Square phone account API (bakery-drinks)

The Android app never holds a Square token. Phone login goes through the
same bakery-drinks origin as `/order/api/menu`.

## Apply onto bakery-local

```bash
python3 server/apply_to_bakery_local.py /path/to/bakery-local
```

That copies `account.py` → `app/account.py` and mounts the routes after
`/order/api/status`. Same result by hand:

```python
from app import account as account_svc
account_svc.mount(app)   # after the existing /order/api/menu routes
```

That registers:

| Method | Path | Square |
| --- | --- | --- |
| POST | `/order/api/customer` and `/order/api/account/phone` | SearchCustomers by phone; CreateCustomer if missing; Loyalty enroll |
| GET | `/order/api/customer?phone=` | SearchCustomers + profile |
| GET | `/order/api/orders?customer_id=` | SearchOrders for that customer + queue ahead |
| GET | `/order/api/account` / `/order/api/account/status` | same payload aliases |

`BAKERY_SERVICE=drinks` already allows `/order/*`. Redeploy Cloud Run
`bakery-drinks` after merging. Keep `SQUARE_ACCESS_TOKEN` in Secret Manager.

Token scopes to add if login 403s: **CUSTOMERS_READ, CUSTOMERS_WRITE,
ORDERS_READ**, plus **LOYALTY_READ / LOYALTY_WRITE** to enroll.

## How Ronald tests

See `HOW_TO_TEST.md`.
