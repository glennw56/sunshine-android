#!/usr/bin/env python3
"""POST bakery-drinks phone login. Never GET ?phone= (that dumps PII)."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request

DEFAULT = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"
LOGIN_PATHS = (
    "/order/api/account/login",
    "/order/api/login",
    "/order/api/session",
    "/order/api/account/phone",
    "/order/api/customer",
)


def normalize(raw: str) -> str:
    digits = re.sub(r"\D+", "", raw or "")
    if len(digits) == 10:
        return "+1" + digits
    if len(digits) == 11 and digits.startswith("1"):
        return "+" + digits
    if raw.startswith("+") and 8 <= len(digits) <= 15:
        return "+" + digits
    return ""


def call(url: str, method: str = "GET", payload: dict | None = None, token: str = "") -> tuple[int, object]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
        headers["X-Session-Token"] = token
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            body = resp.read().decode("utf-8")
            parsed = json.loads(body) if body else {}
            return resp.status, parsed
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else {"error": raw}
        except json.JSONDecodeError:
            parsed = {"error": raw or str(exc)}
        return exc.code, parsed


def public_view(body: object) -> dict:
    if not isinstance(body, dict):
        return {"raw": str(body)[:400]}
    customer = body.get("customer") if isinstance(body.get("customer"), dict) else {}
    orders = body.get("orders") if isinstance(body.get("orders"), list) else []
    return {
        "ok": body.get("ok"),
        "created": body.get("created"),
        "has_session_token": bool(
            body.get("session_token") or body.get("access_token") or body.get("token")
        ),
        "customer_id": (customer or {}).get("id"),
        "name": (customer or {}).get("display_name"),
        "phone": (customer or {}).get("phone"),
        "order_count": len(orders),
        "latest": (
            {
                "name": orders[0].get("name"),
                "date": orders[0].get("date") or orders[0].get("created_at"),
                "total_cents": orders[0].get("total_cents"),
                "items": orders[0].get("items"),
            }
            if orders and isinstance(orders[0], dict)
            else None
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default=DEFAULT)
    parser.add_argument("--phone", default="2055550123")
    args = parser.parse_args()
    phone = normalize(args.phone)
    if not phone:
        print("bad phone", file=sys.stderr)
        return 2
    base = args.base.rstrip("/")
    payload = {"phone": phone, "join_loyalty": True}
    last_code = 0
    last_body: object = {}
    for path in LOGIN_PATHS:
        url = base + path
        print("POST", url)
        last_code, last_body = call(url, "POST", payload)
        print("HTTP", last_code)
        if last_code == 404 or last_code == 405:
            continue
        break
    print(json.dumps(public_view(last_body), indent=2))
    if last_code == 404:
        print("\nDrinks has no POST login yet.")
        return 1
    if last_code >= 400:
        return 1
    token = ""
    if isinstance(last_body, dict):
        token = str(
            last_body.get("session_token")
            or last_body.get("access_token")
            or last_body.get("token")
            or ""
        ).strip()
    if token:
        url = base + "/order/api/account"
        print("GET", url, "(Bearer session)")
        code, body = call(url, "GET", token=token)
        print("HTTP", code)
        print(json.dumps(public_view(body), indent=2))
        if code >= 400:
            print("Session GET not wired yet; POST login payload is enough for the app.")
    else:
        print("No session_token on POST yet. App stores POST customer/orders and will send Bearer when drinks adds one.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
