"""Aggregate Sunshine Square donations for the in-app Donate screen.

Public checkout HTML can publish goal + raised. Donor names need Square
Payments / Orders on bakery-drinks (SQUARE_ACCESS_TOKEN). Checkout stays
https://square.link/u/9tUzPJZQ — this module never invents another pay URL.
"""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from typing import Any

DONATE_URL = "https://square.link/u/9tUzPJZQ"
DONATE_LINK_ID = "5L2X3ONG3NYNAR4WUU2S2SL5"
DONATE_CHECKOUT_PAGE = (
    "https://checkout.square.site/merchant/ML089M4WW1WX2/checkout/" + DONATE_LINK_ID
)
DONATE_ITEM_NEEDLES = ("new store improvements",)
DEFAULT_GOAL_CENTS = 50000
GOAL_BEGIN = "2026-09-20T05:00:00Z"


def fallback_goal_cents() -> int:
    raw = (os.environ.get("SUNSHINE_DONATE_GOAL_CENTS") or "").strip()
    if raw.isdigit() and int(raw) >= 100:
        return int(raw)
    return DEFAULT_GOAL_CENTS


def money_cents(blob: Any) -> int:
    if isinstance(blob, dict):
        return money_cents(blob.get("amount", 0))
    if isinstance(blob, bool):
        return 0
    if isinstance(blob, int):
        return blob
    if isinstance(blob, float):
        return int(round(blob))
    if isinstance(blob, str) and blob.isdigit():
        return int(blob)
    return 0


def is_donation_order(order: dict[str, Any]) -> bool:
    if not isinstance(order, dict):
        return False
    for item in order.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip().lower()
        if any(needle in name for needle in DONATE_ITEM_NEEDLES):
            return True
    source = order.get("source") if isinstance(order.get("source"), dict) else {}
    src_name = str(source.get("name") or "").strip().lower()
    if "donation" in src_name:
        return True
    ticket = str(order.get("ticket_name") or order.get("reference_id") or "").lower()
    return any(needle in ticket for needle in DONATE_ITEM_NEEDLES)


def is_completed_payment(payment: dict[str, Any]) -> bool:
    if not isinstance(payment, dict):
        return False
    status = str(payment.get("status") or "").upper()
    return status in {"COMPLETED", "APPROVED"}


def donor_public_name(
    *,
    payment: dict[str, Any] | None = None,
    order: dict[str, Any] | None = None,
    customer: dict[str, Any] | None = None,
) -> str:
    for blob in (payment, order):
        if not isinstance(blob, dict):
            continue
        note = str(blob.get("note") or "").strip()
        if note and note.lower() not in {"anonymous", "anon"}:
            return note[:80]
    if isinstance(customer, dict):
        given = str(customer.get("given_name") or "").strip()
        family = str(customer.get("family_name") or "").strip()
        nick = str(customer.get("nickname") or "").strip()
        shown = str(customer.get("display_name") or "").strip()
        if nick:
            return nick[:80]
        if given and family:
            return ("%s %s" % (given, family))[:80]
        if given:
            return given[:80]
        if shown:
            return shown[:80]
    if isinstance(order, dict):
        for ful in order.get("fulfillments") or []:
            if not isinstance(ful, dict):
                continue
            details = ful.get("pickup_details") or ful.get("shipment_details") or {}
            if not isinstance(details, dict):
                continue
            recipient = details.get("recipient") or {}
            if isinstance(recipient, dict):
                shown = str(recipient.get("display_name") or "").strip()
                if shown:
                    return shown[:80]
    return "Anonymous"


def parse_public_checkout_html(html: str) -> dict[str, Any]:
    out = {
        "ok": False,
        "goal_cents": fallback_goal_cents(),
        "raised_cents": -1,
        "title": "",
        "description": "",
        "source": "placeholder",
    }
    blob = _extract_bootstrap_json(html or "")
    if not blob:
        return out
    try:
        data = json.loads(blob)
    except json.JSONDecodeError:
        return out
    if not isinstance(data, dict):
        return out
    link = data.get("checkoutLink") if isinstance(data.get("checkoutLink"), dict) else {}
    link_data = link.get("checkout_link_data") if isinstance(link.get("checkout_link_data"), dict) else {}
    goal = link_data.get("donation_goal") if isinstance(link_data.get("donation_goal"), dict) else {}
    target = goal.get("target") if isinstance(goal.get("target"), dict) else {}
    goal_cents = money_cents(target.get("amount"))
    if goal_cents <= 0:
        goal_cents = fallback_goal_cents()
        out["source"] = "config"
    else:
        out["ok"] = True
        out["source"] = "square-public"
    out["goal_cents"] = goal_cents
    out["title"] = str(data.get("checkoutTitle") or link_data.get("name") or "")
    out["description"] = str(link_data.get("description") or "")
    if "donationGoalProgress" in data:
        raw = data.get("donationGoalProgress")
        if isinstance(raw, (int, float)) and raw >= 0:
            if raw <= 1.0:
                out["raised_cents"] = int(round(float(raw) * float(goal_cents)))
            else:
                out["raised_cents"] = int(round(float(raw)))
    return out


def scrape_public_checkout(timeout: float = 12.0) -> dict[str, Any]:
    req = urllib.request.Request(
        DONATE_CHECKOUT_PAGE,
        headers={
            "User-Agent": "SunshineBakeryDonations/0.1.65",
            "Accept": "text/html",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            html = resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError, OSError):
        return parse_public_checkout_html("")
    return parse_public_checkout_html(html)


def aggregate_donations(
    *,
    orders: list[dict[str, Any]],
    payments: list[dict[str, Any]],
    customers: dict[str, dict[str, Any]] | None = None,
    goal_cents: int = 0,
    source: str = "square-payments",
) -> dict[str, Any]:
    customers = customers or {}
    orders_by_id = {
        str(row.get("id") or ""): row
        for row in orders
        if isinstance(row, dict) and row.get("id")
    }
    donors: list[dict[str, Any]] = []
    seen: set[str] = set()
    raised = 0
    for payment in payments:
        if not is_completed_payment(payment):
            continue
        oid = str(payment.get("order_id") or "").strip()
        order = orders_by_id.get(oid) or {}
        if order and not is_donation_order(order):
            continue
        if not order and not _payment_looks_like_donation(payment):
            continue
        pid = str(payment.get("id") or "")
        if pid and pid in seen:
            continue
        if pid:
            seen.add(pid)
        cents = money_cents(payment.get("total_money") or payment.get("amount_money"))
        if cents < 0:
            continue
        raised += cents
        cid = str(payment.get("customer_id") or (order.get("customer_id") if order else "") or "")
        donors.append(
            {
                "name": donor_public_name(
                    payment=payment,
                    order=order,
                    customer=customers.get(cid),
                ),
                "amount_cents": cents,
                "at": str(payment.get("created_at") or order.get("created_at") or ""),
            }
        )
    if not donors:
        for order in orders:
            if not is_donation_order(order):
                continue
            oid = str(order.get("id") or "")
            if oid and oid in seen:
                continue
            cents = money_cents(order.get("total_money") or order.get("net_amount_due_money"))
            if cents <= 0:
                continue
            if oid:
                seen.add(oid)
            raised += cents
            cid = str(order.get("customer_id") or "")
            donors.append(
                {
                    "name": donor_public_name(order=order, customer=customers.get(cid)),
                    "amount_cents": cents,
                    "at": str(order.get("created_at") or ""),
                }
            )
    donors.sort(key=lambda row: str(row.get("at") or ""), reverse=True)
    if goal_cents <= 0:
        goal_cents = fallback_goal_cents()
    return {
        "ok": True,
        "source": source,
        "url": DONATE_URL,
        "goal_cents": goal_cents,
        "raised_cents": raised,
        "donor_count": len(donors),
        "donors": donors[:40],
        "ratio": min(1.0, raised / float(goal_cents)) if goal_cents else 0.0,
    }


def empty_payload(*, source: str = "placeholder") -> dict[str, Any]:
    goal = fallback_goal_cents()
    return {
        "ok": False,
        "source": source,
        "url": DONATE_URL,
        "goal_cents": goal,
        "raised_cents": -1,
        "donor_count": -1,
        "donors": [],
        "ratio": 0.0,
    }


def _payment_looks_like_donation(payment: dict[str, Any]) -> bool:
    note = str(payment.get("note") or "").lower()
    if any(needle in note for needle in DONATE_ITEM_NEEDLES) or "donation" in note:
        return True
    details = payment.get("application_details") if isinstance(payment.get("application_details"), dict) else {}
    product = str(details.get("square_product") or "").upper()
    return product in {"ECOMMERCE_API", "INVOICES", "VIRTUAL_TERMINAL"} and "donation" in note


def _extract_bootstrap_json(html: str) -> str:
    start = html.find("window.bootstrap")
    if start < 0:
        return ""
    brace = html.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    in_str = False
    escape = False
    for i, ch in enumerate(html[brace:], brace):
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return html[brace : i + 1]
    return ""
