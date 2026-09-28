#!/usr/bin/env python3
"""§10 cart replacement + inventory eligibility cases. Synthetic fixtures only."""

from __future__ import annotations

import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from sunshine_commerce import (  # noqa: E402
    EMPTY_REPLACE,
    FAIL_VALIDATE,
    SUCCESS_REPLACE,
    category_counts,
    filter_menu,
    is_purchase_eligible,
    purchasable_quantity,
    replace_cart_from_order,
    search_eligible,
)


def fail(msg: str) -> None:
    raise SystemExit("FAIL: " + msg)


def ok(msg: str) -> None:
    print("OK  :", msg)


COOKIE = {
    "id": "VAR_COOKIE",
    "item_id": "ITEM_COOKIE",
    "name": "Chocolate Chip Cookie",
    "category": "pastry",
    "inventory": {"tracking_enabled": True, "available_to_sell": 8},
}
LATTE = {
    "id": "VAR_LATTE",
    "item_id": "ITEM_LATTE",
    "name": "Matcha Latte",
    "category": "tea",
    "inventory": {"tracking_enabled": True, "available_to_sell": 2},
}
SOLD = {
    "id": "VAR_SOLD",
    "item_id": "ITEM_SOLD",
    "name": "Almond Croissant",
    "category": "pastry",
    "sold_out": True,
    "inventory": {"tracking_enabled": True, "available_to_sell": 4},
}
UNTRACKED = {
    "id": "VAR_FREE",
    "item_id": "ITEM_FREE",
    "name": "Water",
    "category": "more",
    "inventory": {"tracking_enabled": False, "available_to_sell": 99},
}
UNKNOWN = {
    "id": "VAR_UNK",
    "item_id": "ITEM_UNK",
    "name": "Mystery Roll",
    "category": "pastry",
    "inventory": {"tracking_enabled": True},
}
ZERO = {
    "id": "VAR_ZERO",
    "item_id": "ITEM_ZERO",
    "name": "Pistachio Croissant",
    "category": "pastry",
    "inventory": {"tracking_enabled": True, "available_to_sell": 0},
}
NEGATIVE = {
    "id": "VAR_NEG",
    "item_id": "ITEM_NEG",
    "name": "Cinnamon Roll",
    "category": "pastry",
    "inventory": {"tracking_enabled": True, "available_to_sell": -2},
}
FLAG_OK = {
    "id": "QASHH4IWRCAJWUVJEVKGO4VA",
    "item_id": "VLYSUPIJKKN6OVVZFOT3GA2X",
    "name": "Biscoff Coffee",
    "category": "coffee",
    "sold_out": False,
}
FLAG_SOLD = {
    "id": "VAR_FLAG_SOLD",
    "name": "Seasonal Macaron",
    "category": "pastry",
    "sold_out": True,
}
TWO_VAR = {
    "id": "ITEM_TOTE",
    "name": "Tote Bag",
    "category": "more",
    "variations": [
        {"id": "VAR_TOTE_RED", "name": "Tote Bag", "inventory": {"tracking_enabled": True, "available_to_sell": 3}},
        {"id": "VAR_TOTE_NAVY", "name": "Tote Bag Navy", "sold_out": True, "inventory": {"tracking_enabled": True, "available_to_sell": 9}},
    ],
}

CATALOG = [COOKIE, LATTE, SOLD, UNTRACKED, UNKNOWN, ZERO, NEGATIVE, FLAG_OK, FLAG_SOLD, TWO_VAR]


def test_eligibility() -> None:
    if not is_purchase_eligible(COOKIE):
        fail("tracked positive ATS should be eligible")
    if is_purchase_eligible(SOLD):
        fail("explicit sold_out wins over a positive count")
    if is_purchase_eligible(UNTRACKED):
        fail("untracked / unlimited must be excluded")
    if is_purchase_eligible(UNKNOWN):
        fail("unknown quantity must be excluded")
    if is_purchase_eligible(ZERO) or is_purchase_eligible(NEGATIVE):
        fail("zero/negative ATS must be excluded")
    if not is_purchase_eligible(FLAG_OK):
        fail("drinks rows without inventory counts stay eligible via provider flags")
    if is_purchase_eligible(FLAG_SOLD):
        fail("provider sold_out flag must exclude")
    if purchasable_quantity(LATTE) != 2:
        fail("ATS cap")
    ok("eligibility matrix")


def test_replace_unrelated_cart() -> None:
    current = {"items": [{"id": "OLD", "qty": 3}], "name": "Ada"}
    order = {"items": [{"catalog_object_id": "VAR_COOKIE", "name": "Chocolate Chip Cookie", "qty": 1}]}
    result = replace_cart_from_order(current, order, CATALOG)
    if not result["ok"] or [i["id"] for i in result["items"]] != ["VAR_COOKIE"]:
        fail("reorder must replace the whole cart")
    if result["cart"]["items"][0]["id"] != "VAR_COOKIE":
        fail("replacement cart")
    if SUCCESS_REPLACE not in result["message"]:
        fail("success copy")
    ok("unrelated cart is replaced")


def test_mixed_availability() -> None:
    current = {"items": [{"id": "OLD", "qty": 1}]}
    order = {
        "items": [
            {"catalog_object_id": "VAR_COOKIE", "name": "Chocolate Chip Cookie", "qty": 1},
            {"catalog_object_id": "VAR_SOLD", "name": "Almond Croissant", "qty": 1},
        ]
    }
    result = replace_cart_from_order(current, order, CATALOG)
    if [i["id"] for i in result["items"]] != ["VAR_COOKIE"]:
        fail("only available product remains")
    if not result["skipped"] or result["skipped"][0]["name"] != "Almond Croissant":
        fail("skipped sold-out product must be explained")
    ok("mixed availability")


def test_all_unavailable_empties() -> None:
    current = {"items": [{"id": "OLD", "qty": 2}]}
    order = {"items": [{"catalog_object_id": "VAR_SOLD", "name": "Almond Croissant", "qty": 1}]}
    result = replace_cart_from_order(current, order, CATALOG)
    if result["items"] != []:
        fail("all-unavailable reorder must leave an empty cart")
    if result["message"] != EMPTY_REPLACE:
        fail("empty replace copy")
    ok("all unavailable empties cart")


def test_validation_failure_preserves() -> None:
    current = {"items": [{"id": "KEEP", "qty": 4}]}
    order = {"items": [{"catalog_object_id": "VAR_COOKIE", "qty": 1}]}
    result = replace_cart_from_order(current, order, CATALOG, validation_ok=False)
    if result["ok"] or result["replaced"]:
        fail("failed validation is not a successful empty reorder")
    if result["cart"]["items"][0]["id"] != "KEEP":
        fail("original cart must remain")
    if result["error"] != FAIL_VALIDATE:
        fail("retryable error copy")
    ok("validation failure preserves cart")


def test_quantity_reduced() -> None:
    order = {"items": [{"catalog_object_id": "VAR_LATTE", "name": "Matcha Latte", "qty": 5}]}
    result = replace_cart_from_order({"items": []}, order, CATALOG)
    if result["items"][0]["qty"] != 2:
        fail("historical qty 5 with ATS 2 must become 2")
    if not result["reduced"]:
        fail("adjustment notice")
    ok("quantity reduced to ATS")


def test_shared_pool() -> None:
    order = {
        "items": [
            {"catalog_object_id": "VAR_LATTE", "name": "Matcha Latte", "qty": 2},
            {"catalog_object_id": "VAR_LATTE", "name": "Matcha Latte", "qty": 2},
        ]
    }
    result = replace_cart_from_order({"items": []}, order, CATALOG)
    total = sum(i["qty"] for i in result["items"])
    if total > 2:
        fail("duplicate lines cannot exceed shared ATS")
    ok("shared inventory pool")


def test_untracked_excluded() -> None:
    for item in (UNTRACKED, UNKNOWN, ZERO, NEGATIVE):
        order = {"items": [{"catalog_object_id": item["id"], "name": item["name"], "qty": 1}]}
        result = replace_cart_from_order({"items": [{"id": "OLD", "qty": 1}]}, order, CATALOG)
        if result["items"]:
            fail("ineligible %s leaked into replacement" % item["id"])
    ok("untracked/unknown/zero/negative excluded from reorder")


def test_variant_and_categories() -> None:
    shown = filter_menu(CATALOG)
    names = {str(i.get("name")) for i in shown}
    if "Almond Croissant" in names or "Water" in names or "Mystery Roll" in names:
        fail("ineligible products must not appear in shopping")
    if "Tote Bag" not in names:
        fail("parent with one eligible variant should still show")
    if "Chocolate Chip Cookie" not in names or "Biscoff Coffee" not in names:
        fail("eligible products missing from filtered menu")
    cats = category_counts(CATALOG)
    if "pastry" not in cats or cats.get("more", 0) != 1:
        fail("category counts must use the eligible set only, got %s" % cats)
    if any(i["name"] == "Seasonal Macaron" for i in search_eligible(CATALOG, "macaron")):
        fail("search must not reveal sold-out items")
    if not search_eligible(CATALOG, "biscoff"):
        fail("search should find eligible Biscoff Coffee")
    ok("variants, categories, search")


def test_stale_reorder() -> None:
    current = {"items": [{"id": "NEW", "qty": 1}]}
    order = {"items": [{"catalog_object_id": "VAR_COOKIE", "qty": 1}]}
    result = replace_cart_from_order(current, order, CATALOG, request_seq=1, applied_seq=2)
    if result["ok"] or result["cart"]["items"][0]["id"] != "NEW":
        fail("older reorder must not overwrite a newer selection")
    ok("stale reorder ignored")


def main() -> int:
    test_eligibility()
    test_replace_unrelated_cart()
    test_mixed_availability()
    test_all_unavailable_empties()
    test_validation_failure_preserves()
    test_quantity_reduced()
    test_shared_pool()
    test_untracked_excluded()
    test_variant_and_categories()
    test_stale_reorder()
    print("All COS commerce checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
