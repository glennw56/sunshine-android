#!/usr/bin/env python3
"""Donation aggregation + public Square checkout parse. No token required."""

from __future__ import annotations

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "server"))

from donations import (  # noqa: E402
    DONATE_URL,
    aggregate_donations,
    donor_public_name,
    is_donation_order,
    parse_public_checkout_html,
    scrape_public_checkout,
)


def fail(msg: str) -> None:
    raise SystemExit("FAIL: " + msg)


def test_order_match() -> None:
    if not is_donation_order({"line_items": [{"name": "New store improvements"}]}):
        fail("donation line item should match")
    if is_donation_order({"line_items": [{"name": "Biscoff Coffee"}]}):
        fail("drink order must not count as a donation")


def test_aggregate() -> None:
    orders = [
        {
            "id": "ORD1",
            "line_items": [{"name": "New store improvements"}],
            "created_at": "2026-09-20T12:00:00Z",
        }
    ]
    payments = [
        {
            "id": "PAY1",
            "status": "COMPLETED",
            "order_id": "ORD1",
            "note": "Ada",
            "total_money": {"amount": 2500, "currency": "USD"},
            "created_at": "2026-09-20T12:01:00Z",
        },
        {
            "id": "PAY2",
            "status": "COMPLETED",
            "order_id": "ORD_COFFEE",
            "total_money": {"amount": 425, "currency": "USD"},
        },
    ]
    row = aggregate_donations(orders=orders, payments=payments, goal_cents=1000000)
    if row["raised_cents"] != 2500:
        fail("raised should be donation only, got %s" % row["raised_cents"])
    if row["donor_count"] != 1 or row["donors"][0]["name"] != "Ada":
        fail("named donor from payment note: %s" % row)
    if row["url"] != DONATE_URL:
        fail("must keep the existing Square donate URL")
    anon = donor_public_name(payment={"note": ""}, order={})
    if anon != "Anonymous":
        fail("blank name is Anonymous")


def test_public_html() -> None:
    html = (
        'window.bootstrap = {"checkoutTitle":"Sunshine\'s Bakery","donationGoalProgress":0,'
        '"checkoutLink":{"checkout_link_data":{"name":"New store improvements",'
        '"description":"Trussville","link_type":"DONATION_LINK",'
        '"donation_goal":{"target":{"amount":1000000,"currency":"USD"}},'
        '"short_url":"https://square.link/u/9tUzPJZQ"}}};'
    )
    row = parse_public_checkout_html(html)
    if not row["ok"] or row["goal_cents"] != 1000000 or row["raised_cents"] != 0:
        fail("public checkout parse: %s" % row)


def test_live_public_page() -> None:
    row = scrape_public_checkout()
    if not row.get("ok"):
        print("WARN: public Square checkout scrape failed")
        return
    if row.get("goal_cents", 0) < 100:
        fail("live public goal missing")
    print(
        "OK  live public Square donate goal=%s raised=%s"
        % (row.get("goal_cents"), row.get("raised_cents"))
    )


def main() -> int:
    test_order_match()
    test_aggregate()
    test_public_html()
    test_live_public_page()
    print("OK  server/donations helpers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
