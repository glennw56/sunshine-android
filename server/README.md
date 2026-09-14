# Square phone account API (bakery-drinks)

The Android app never holds a Square token. Phone login, loyalty enroll, and
previous / open orders go through the same bakery-drinks origin already used
for `/order/api/menu`.

Copy `account.py` into [bakery-local](https://github.com/glennw56/bakery-local)
as `app/account.py` on the Square catalog branch, then add these routes next
to the existing `/order/api/*` handlers in `app/main.py`:

```python
from app import account as account_svc

@app.post("/order/api/account/phone")
def order_api_account_phone(body: dict = Body(...)):
    try:
        return account_svc.login_or_signup(body)
    except account_svc.AccountError as exc:
        return JSONResponse({"error": exc.message}, status_code=exc.status_code)

@app.get("/order/api/account")
def order_api_account(customer_id: str = Query(""), phone: str = Query("")):
    try:
        return account_svc.get_account(customer_id, phone)
    except account_svc.AccountError as exc:
        return JSONResponse({"error": exc.message}, status_code=exc.status_code)

@app.get("/order/api/account/status")
def order_api_account_status(customer_id: str = Query(""), phone: str = Query("")):
    try:
        return account_svc.get_status(customer_id, phone)
    except account_svc.AccountError as exc:
        return JSONResponse({"error": exc.message}, status_code=exc.status_code)
```

`BAKERY_SERVICE=drinks` already allows `/order/*`, so Cloud Run picks the
routes up on the next deploy. Redeploy bakery-drinks after merging.

The token stays `SQUARE_ACCESS_TOKEN` in the Cloud Run service. Do not put it
in this Android repo.
