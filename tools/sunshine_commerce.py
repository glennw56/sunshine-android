"""Shared shopping eligibility + cart-replacement rules (COS pack §10).

This module is the automated source of truth for cart replacement, inventory
eligibility, and race handling. Godot OrderClient must stay aligned.

Inventory interpretation (2026-09-20):
  "Has inventory" means tracking is enabled AND a known, positive
  available-to-sell quantity exists at the selected fulfillment location
  (Square location L4CK6YWGT5XQX / Irondale). A mere inventory record is
  not enough. Untracked, unlimited, unknown, zero, negative, archived,
  disabled, and explicitly sold-out variants are excluded from purchasing.

  Live bakery-drinks GET /order/api/menu (sampled 2026-09-20) returns drinks
  with Square ids/prices/modifiers and NO inventory object. Until drinks
  exposes InventoryCounts, those rows use the provider sold_out / available
  flags so the Irondale menu is not emptied. That fallback is
  ``provider_flag_until_inventory``, not a claim that untracked stock is
  unlimited.
"""

from __future__ import annotations

from typing import Any

IRONDALE_LOCATION = "L4CK6YWGT5XQX"
SUCCESS_REPLACE = "Cart replaced with available items from your previous order"
EMPTY_REPLACE = "None of the items in this order are currently available."
FAIL_VALIDATE = "Could not check availability. Your cart was not changed."


def _as_int(value: Any, default: int | None = None) -> int | None:
    if value is None:
        return default
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str) and value.strip().lstrip("-").isdigit():
        return int(value.strip())
    if isinstance(value, dict):
        for key in ("quantity", "available", "available_quantity", "count", "in_stock", "amount"):
            if key in value:
                return _as_int(value.get(key), default)
    return default


def _truthy_flag(item: dict[str, Any], *keys: str) -> bool:
    for key in keys:
        if key in item and bool(item.get(key)):
            return True
    return False


def _falsey_flag(item: dict[str, Any], *keys: str) -> bool:
    for key in keys:
        if key in item and item.get(key) is False:
            return True
    return False


def inventory_block(item: dict[str, Any]) -> dict[str, Any] | None:
    raw = item.get("inventory")
    if isinstance(raw, dict):
        return raw
    return None


def inventory_state(item: dict[str, Any], location_id: str = IRONDALE_LOCATION) -> dict[str, Any]:
    """Normalize inventory. source is counts | flags | missing."""
    block = inventory_block(item)
    loc = (location_id or IRONDALE_LOCATION).strip()
    if block:
        loc_map = block.get("locations") or block.get("by_location") or {}
        loc_row = loc_map.get(loc) if isinstance(loc_map, dict) else None
        src = loc_row if isinstance(loc_row, dict) else block
        tracking = src.get("tracking_enabled", src.get("tracked", src.get("inventory_tracking")))
        qty = _as_int(
            src.get(
                "available_to_sell",
                src.get(
                    "available_quantity",
                    src.get("quantity", src.get("available", src.get("count"))),
                ),
            )
        )
        unlimited = bool(src.get("unlimited") or src.get("untracked") or tracking is False)
        known = qty is not None and not unlimited
        return {
            "source": "counts",
            "tracking_enabled": bool(tracking) and not unlimited,
            "quantity": qty,
            "known": known,
            "unlimited": unlimited,
            "location_id": loc,
        }
    for key in ("available_to_sell", "available_quantity", "inventory_quantity"):
        if key in item:
            qty = _as_int(item.get(key))
            tracking = item.get("inventory_tracking", item.get("tracking_enabled", True))
            unlimited = tracking is False or bool(item.get("unlimited"))
            return {
                "source": "counts",
                "tracking_enabled": bool(tracking) and not unlimited,
                "quantity": qty,
                "known": qty is not None and not unlimited,
                "unlimited": unlimited,
                "location_id": loc,
            }
    return {
        "source": "flags" if _has_provider_flags(item) else "missing",
        "tracking_enabled": False,
        "quantity": None,
        "known": False,
        "unlimited": False,
        "location_id": loc,
    }


def _has_provider_flags(item: dict[str, Any]) -> bool:
    return any(
        key in item
        for key in (
            "sold_out",
            "is_sold_out",
            "unavailable",
            "available",
            "is_available",
            "in_stock",
            "status",
            "archived",
            "disabled",
        )
    )


def is_explicitly_sold_out(item: dict[str, Any]) -> bool:
    if _truthy_flag(item, "sold_out", "is_sold_out", "unavailable", "archived", "disabled"):
        return True
    if _falsey_flag(item, "available", "is_available", "in_stock"):
        return True
    status = str(item.get("status") or "").strip().lower()
    if status in {"sold_out", "sold-out", "unavailable", "inactive", "archived", "disabled"}:
        return True
    return False


def is_purchase_eligible(item: dict[str, Any], location_id: str = IRONDALE_LOCATION) -> bool:
    if not isinstance(item, dict) or not item:
        return False
    if is_explicitly_sold_out(item):
        return False
    state = inventory_state(item, location_id)
    if state["source"] == "counts":
        if state["unlimited"] or not state["tracking_enabled"]:
            return False
        if not state["known"]:
            return False
        return int(state["quantity"] or 0) > 0
    # provider_flag_until_inventory: drinks currently omits counts.
    return True


def purchasable_quantity(item: dict[str, Any], location_id: str = IRONDALE_LOCATION) -> int:
    if not is_purchase_eligible(item, location_id):
        return 0
    state = inventory_state(item, location_id)
    if state["source"] == "counts" and state["known"]:
        return max(0, int(state["quantity"] or 0))
    return 99


def eligible_variants(product: dict[str, Any], location_id: str = IRONDALE_LOCATION) -> list[dict[str, Any]]:
    variants = product.get("variations")
    if isinstance(variants, list) and variants:
        return [v for v in variants if isinstance(v, dict) and is_purchase_eligible(v, location_id)]
    return [product] if is_purchase_eligible(product, location_id) else []


def product_is_shown(product: dict[str, Any], location_id: str = IRONDALE_LOCATION) -> bool:
    return bool(eligible_variants(product, location_id))


def catalog_by_id(catalog: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for item in catalog:
        if not isinstance(item, dict):
            continue
        for field in ("id", "catalog_object_id", "square_id", "item_id", "catalog_variation_id", "variation_id"):
            key = str(item.get(field) or "").strip()
            if key:
                out[key] = item
        variants = item.get("variations")
        if isinstance(variants, list):
            for var in variants:
                if not isinstance(var, dict):
                    continue
                for field in ("id", "catalog_object_id", "variation_id"):
                    key = str(var.get(field) or "").strip()
                    if key:
                        out[key] = var
    return out


def match_catalog_item(line: dict[str, Any], catalog: list[dict[str, Any]]) -> dict[str, Any]:
    index = catalog_by_id(catalog)
    for field in ("catalog_object_id", "catalog_variation_id", "id", "variation_id", "item_id"):
        key = str(line.get(field) or "").strip()
        if key and key in index:
            return index[key]
    needle = str(line.get("name") or "").strip().lower()
    variation = str(line.get("variation_name") or "").strip().lower()
    hits = []
    for item in catalog:
        if not isinstance(item, dict):
            continue
        label = str(item.get("name") or "").strip().lower()
        if needle and label == needle:
            hits.append(item)
        elif variation and label == variation:
            hits.append(item)
    if len(hits) == 1:
        return hits[0]
    return {}


def _line_qty(line: dict[str, Any]) -> int:
    q = line.get("qty", line.get("quantity", 1))
    try:
        return max(1, int(float(q)))
    except (TypeError, ValueError):
        return 1


def _stock_pool_key(item: dict[str, Any]) -> str:
    for field in ("inventory_pool_id", "item_id", "catalog_object_id", "id"):
        key = str(item.get(field) or "").strip()
        if key:
            return key
    return str(item.get("name") or "").strip().lower()


def replace_cart_from_order(
    current_cart: dict[str, Any],
    order: dict[str, Any],
    catalog: list[dict[str, Any]],
    *,
    location_id: str = IRONDALE_LOCATION,
    request_seq: int = 1,
    applied_seq: int = 0,
    validation_ok: bool = True,
) -> dict[str, Any]:
    """Atomic cart replacement. Failed validation preserves the original cart."""
    if request_seq < applied_seq:
        return {
            "ok": False,
            "stale": True,
            "replaced": False,
            "cart": current_cart,
            "items": list(current_cart.get("items") or []),
            "skipped": [],
            "reduced": [],
            "message": "",
            "error": "Stale reorder ignored.",
            "applied_seq": applied_seq,
        }
    if not validation_ok:
        return {
            "ok": False,
            "replaced": False,
            "cart": current_cart,
            "items": list(current_cart.get("items") or []),
            "skipped": [],
            "reduced": [],
            "message": "",
            "error": FAIL_VALIDATE,
            "applied_seq": applied_seq,
        }

    remaining: dict[str, int] = {}
    replacement: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    reduced: list[dict[str, Any]] = []

    for line in order.get("items") or []:
        if not isinstance(line, dict):
            continue
        drink = match_catalog_item(line, catalog)
        name = str(line.get("name") or drink.get("name") or "Item")
        wanted = _line_qty(line)
        if not drink:
            skipped.append({"name": name, "reason": "not on the live menu"})
            continue
        if not is_purchase_eligible(drink, location_id):
            skipped.append({"name": name, "reason": "not currently available"})
            continue
        pool = _stock_pool_key(drink)
        if pool not in remaining:
            remaining[pool] = purchasable_quantity(drink, location_id)
        available = remaining[pool]
        if available <= 0:
            skipped.append({"name": name, "reason": "not currently available"})
            continue
        take = min(wanted, available)
        remaining[pool] = available - take
        if take < wanted:
            reduced.append({"name": name, "wanted": wanted, "qty": take})
        replacement.append(
            {
                "id": str(drink.get("id") or ""),
                "qty": take,
                "modifiers": line.get("modifiers") if isinstance(line.get("modifiers"), dict) else {},
                "mod_labels": list(line.get("mod_labels") or []),
                "name": str(drink.get("name") or name),
            }
        )

    next_cart = dict(current_cart)
    next_cart["items"] = replacement
    next_cart["focus_cart"] = True
    if not replacement:
        message = EMPTY_REPLACE
    else:
        bits = [SUCCESS_REPLACE]
        if skipped:
            bits.append(
                "Skipped: " + ", ".join("%s (%s)" % (s["name"], s["reason"]) for s in skipped)
            )
        if reduced:
            bits.append(
                "Reduced: "
                + ", ".join("%s to %d" % (r["name"], r["qty"]) for r in reduced)
            )
        message = " ".join(bits)
    return {
        "ok": True,
        "replaced": True,
        "cart": next_cart,
        "items": replacement,
        "skipped": skipped,
        "reduced": reduced,
        "message": message,
        "error": "",
        "applied_seq": request_seq,
    }


def filter_menu(catalog: list[dict[str, Any]], location_id: str = IRONDALE_LOCATION) -> list[dict[str, Any]]:
    return [item for item in catalog if isinstance(item, dict) and product_is_shown(item, location_id)]


def category_counts(
    catalog: list[dict[str, Any]], location_id: str = IRONDALE_LOCATION
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for item in filter_menu(catalog, location_id):
        cat = str(item.get("category") or "more").strip().lower()
        counts[cat] = counts.get(cat, 0) + 1
    return counts


def search_eligible(
    catalog: list[dict[str, Any]], query: str, location_id: str = IRONDALE_LOCATION
) -> list[dict[str, Any]]:
    needle = (query or "").strip().lower()
    rows = filter_menu(catalog, location_id)
    if not needle:
        return rows
    return [item for item in rows if needle in str(item.get("name") or "").lower()]
