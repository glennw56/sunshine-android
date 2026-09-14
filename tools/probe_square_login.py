#!/usr/bin/env python3
"""Hit bakery-drinks Square customer routes. No token in this process."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request

DEFAULT = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app"


def normalize(raw: str) -> str:
    digits = re.sub(r"\D+", "", raw or "")
    if len(digits) == 10:
        return "+1" + digits
    if len(digits) == 11 and digits.startswith("1"):
        return "+" + digits
    if raw.startswith("+") and 8 <= len(digits) <= 15:
        return "+" + digits
    return ""


def call(url: str, method: str = "GET", payload: dict | None = None) -> tuple[int, object]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Accept": "application/json", "Content-Type": "application/json"},
    )
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default=DEFAULT)
    parser.add_argument("--phone", default="2055550123")
    parser.add_argument("--create", action="store_true", help="POST (creates a Square customer if missing)")
    args = parser.parse_args()
    phone = normalize(args.phone)
    if not phone:
        print("bad phone", file=sys.stderr)
        return 2
    base = args.base.rstrip("/")
    if args.create:
        print("POST", base + "/order/api/customer")
        code, body = call(base + "/order/api/customer", "POST", {"phone": phone, "join_loyalty": True})
    else:
        url = base + "/order/api/customer?phone=" + phone.replace("+", "%2B")
        print("GET", url)
        code, body = call(url, "GET")
    print("HTTP", code)
    print(json.dumps(body, indent=2)[:2000])
    if code == 404:
        print("\nDrinks service does not have customer routes yet. Deploy server/account.py.")
        return 1
    if code >= 400:
        return 1
    customer = body.get("customer") if isinstance(body, dict) else {}
    orders = body.get("orders") if isinstance(body, dict) else []
    print(
        "customer_id=",
        (customer or {}).get("id"),
        "name=",
        (customer or {}).get("display_name"),
        "orders=",
        len(orders) if isinstance(orders, list) else 0,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
