#!/usr/bin/env python3
"""Pure-function checks for Square account helpers. No token, no network."""

from __future__ import annotations

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "server"))

from account import (  # noqa: E402
    AccountError,
    ahead_count,
    customer_public,
    display_name,
    has_usable_name,
    is_in_queue,
    mint_session_token,
    normalize_phone,
    order_name,
    order_status_label,
    profile_update_payload,
    read_session_token,
    summarize_order,
    valid_email,
)


def fail(msg: str) -> None:
    raise SystemExit("FAIL: " + msg)


def test_phone() -> None:
    if normalize_phone("205-555-0123") != "+12055550123":
        fail("10-digit US phone")
    if normalize_phone("(205) 555-0123") != "+12055550123":
        fail("formatted US phone")
    if normalize_phone("12055550123") != "+12055550123":
        fail("11-digit with leading 1")
    if normalize_phone("+12055550123") != "+12055550123":
        fail("E.164 stays")
    if normalize_phone("nope") != "":
        fail("junk phone must be empty")


def test_names() -> None:
    if display_name({"nickname": "Ronnie", "given_name": "Ronald"}) != "Ronnie":
        fail("nickname wins")
    if display_name({"given_name": "Ronald", "family_name": "W"}) != "Ronald W":
        fail("given + family")
    if display_name({"given_name": "Ronald"}) != "Ronald":
        fail("given only")
    if display_name({}) != "":
        fail("no invented name")
    pub = customer_public(
        {
            "id": "CUST_1",
            "given_name": "Ada",
            "family_name": "Lovelace",
            "phone_number": "+12055550123",
        }
    )
    if pub["id"] != "CUST_1" or pub["display_name"] != "Ada Lovelace":
        fail("customer_public")
    if "email" in pub:
        fail("customer_public must not dump email")
    if has_usable_name({"given_name": "Ronald"}):
        pass
    else:
        fail("given_name is usable")
    if has_usable_name({"given_name": "", "family_name": "", "display_name": ""}):
        fail("empty names are not usable")
    if not valid_email("ronald@example.com"):
        fail("valid email")
    if valid_email("nope") or valid_email("missing-at.com"):
        fail("junk email")
    try:
        profile_update_payload({"given_name": "Ada", "family_name": "Lovelace", "email": "ada@example.com"})
    except AccountError as exc:
        fail("valid profile payload: %s" % exc)
    try:
        profile_update_payload({"given_name": "", "family_name": "Lovelace", "email": "ada@example.com"})
        fail("first name required")
    except AccountError:
        pass


def test_session_token() -> None:
    os.environ["ACCOUNT_SESSION_SECRET"] = "unit-test-secret"
    token = mint_session_token("CUST_1", "+12055550123")
    session = read_session_token(token)
    if not session or session.get("customer_id") != "CUST_1":
        fail("session roundtrip")
    if read_session_token("nope") is not None:
        fail("junk token")
    if read_session_token("Bearer " + token) is None:
        fail("bearer prefix")


def test_orders() -> None:
    older = {
        "id": "A",
        "created_at": "2026-09-14T10:00:00Z",
        "state": "OPEN",
        "fulfillments": [{"state": "PROPOSED"}],
        "line_items": [{"name": "Coffee", "quantity": "1"}],
        "net_amounts": {"total_money": {"amount": 350}},
    }
    newer = {
        "id": "B",
        "created_at": "2026-09-14T10:05:00Z",
        "state": "OPEN",
        "fulfillments": [{"state": "RESERVED"}],
        "line_items": [
            {
                "name": "Nutella Croissant",
                "quantity": "2",
            },
            {
                "name": "Coffee",
                "quantity": "1",
                "modifiers": [{"name": "Oat milk"}, {"name": "Less sweet"}],
            },
        ],
        "net_amounts": {"total_money": {"amount": 1550}},
    }
    ready = {
        "id": "C",
        "created_at": "2026-09-14T09:00:00Z",
        "state": "OPEN",
        "fulfillments": [{"state": "PREPARED"}],
    }
    if order_name(newer) != "Nutella Croissant + 1 more":
        fail("order name")
    if summarize_order(newer)["total_cents"] != 1550:
        fail("total cents")
    coffee = summarize_order(newer)["items"][1]
    if coffee.get("detail") != "Oat milk · Less sweet":
        fail("line modifiers")
    priced = {
        "id": "P",
        "created_at": "2026-09-14T10:06:00Z",
        "state": "OPEN",
        "line_items": [{
            "name": "Coffee",
            "quantity": "1",
            "modifiers": [{
                "name": "Oat milk",
                "catalog_object_id": "MOD_OAT",
                "base_price_money": {"amount": 75, "currency": "USD"},
            }],
        }],
        "net_amounts": {"total_money": {"amount": 425}},
    }
    oat = summarize_order(priced)["items"][0]["modifiers"][0]
    if oat.get("price_cents") != 75 or oat.get("id") != "MOD_OAT":
        fail("modifier price/id from Square")
    if order_status_label(ready) != "ready":
        fail("ready label")
    if is_in_queue(ready):
        fail("ready is not ahead")
    if ahead_count(newer, [older, newer, ready]) != 1:
        fail("one order ahead")
    if ahead_count(older, [older, newer, ready]) != 0:
        fail("first in queue")


def main() -> int:
    test_phone()
    test_names()
    test_session_token()
    test_orders()
    print("OK  server/account helpers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
