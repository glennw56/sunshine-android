"""Square Customers + Loyalty + Orders for the Sunshine phone login.

Drop this file into bakery-local as ``app/account.py`` and register the
``/order/api/account`` routes (see README.md). The Square access token
stays in env / Secret Manager — never in the APK.

This module has no invented customer directory. Every customer id comes
from Square SearchCustomers / CreateCustomer.
"""

from __future__ import annotations

import os
import re
import time
import uuid
import hmac
import json
import hashlib
import base64
from datetime import datetime, timedelta, timezone
from typing import Any

try:
    import httpx
except ImportError:  # unit tests of helpers only
    httpx = None  # type: ignore

try:
    from app import order as order_svc
except ImportError:  # standalone / unit tests
    order_svc = None  # type: ignore

SQUARE_VERSION = "2025-01-23"
DEFAULT_LOCATION_ID = "L4CK6YWGT5XQX"
DEFAULT_API_BASE = "https://connect.squareup.com"
READY_FULFILLMENT = frozenset({"PREPARED", "COMPLETED"})
QUEUE_FULFILLMENT = frozenset({"PROPOSED", "RESERVED"})


class AccountError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def normalize_phone(raw: str) -> str:
    text = (raw or "").strip()
    if not text:
        return ""
    digits = re.sub(r"\D+", "", text)
    if len(digits) == 10:
        return "+1" + digits
    if len(digits) == 11 and digits.startswith("1"):
        return "+" + digits
    if text.startswith("+") and 8 <= len(digits) <= 15:
        return "+" + digits
    return ""


def display_name(customer: dict[str, Any]) -> str:
    nick = str(customer.get("nickname") or "").strip()
    if nick:
        return nick
    given = str(customer.get("given_name") or "").strip()
    family = str(customer.get("family_name") or "").strip()
    if given and family:
        return f"{given} {family}"
    if given:
        return given
    if family:
        return family
    return str(customer.get("display_name") or "").strip()


def customer_public(customer: dict[str, Any]) -> dict[str, Any]:
    phone = str(customer.get("phone_number") or customer.get("phone") or "").strip()
    return {
        "id": str(customer.get("id") or "").strip(),
        "phone": phone,
        "given_name": str(customer.get("given_name") or "").strip(),
        "family_name": str(customer.get("family_name") or "").strip(),
        "nickname": str(customer.get("nickname") or "").strip(),
        "display_name": display_name(customer),
    }


def has_usable_name(customer: dict[str, Any]) -> bool:
    given = str(customer.get("given_name") or "").strip()
    family = str(customer.get("family_name") or "").strip()
    shown = str(customer.get("display_name") or "").strip()
    nick = str(customer.get("nickname") or "").strip()
    return bool(given or family or shown or nick)


def valid_email(raw: str) -> bool:
    email = (raw or "").strip()
    if len(email) < 5 or " " in email:
        return False
    at = email.find("@")
    if at <= 0 or at >= len(email) - 3:
        return False
    domain = email[at + 1 :]
    dot = domain.find(".")
    return 0 < dot < len(domain) - 1


AVATAR_VERSION = 1
APPROVED_AVATAR = {
    "skin": ("fair", "peach", "tan", "deep", "rich"),
    "hair": ("bangs", "wavy", "short", "bun", "none"),
    "hair_color": ("brown", "wine", "black", "honey", "cream"),
    "outfit": ("blush", "wine", "cream", "apricot"),
    "apron": ("none", "grey", "blush", "wine"),
    "hat": ("none", "sun", "beanie", "bow"),
    "accessory": ("none", "glasses", "flower", "scarf"),
}
RESERVED_USERNAMES = {
    "sunshine",
    "admin",
    "staff",
    "bakery",
    "ronald",
    "system",
    "moderator",
    "support",
}


def default_avatar() -> dict[str, Any]:
    return {
        "v": AVATAR_VERSION,
        "skin": "peach",
        "hair": "bangs",
        "hair_color": "brown",
        "outfit": "blush",
        "apron": "grey",
        "hat": "sun",
        "accessory": "glasses",
    }


def sanitize_avatar(raw: Any) -> dict[str, Any]:
    recipe = default_avatar()
    if not isinstance(raw, dict):
        return recipe
    for key, allowed in APPROVED_AVATAR.items():
        value = str(raw.get(key) or recipe[key]).strip().lower()
        recipe[key] = value if value in allowed else recipe[key]
    recipe["v"] = AVATAR_VERSION
    return recipe


def normalize_username(raw: str) -> str:
    return "".join(ch for ch in (raw or "").strip().lower() if ch.isalnum() or ch == "_")


def username_error(raw: str) -> str:
    name = normalize_username(raw)
    if len(name) < 3 or len(name) > 20:
        return "Username must be 3–20 letters, numbers, or _."
    if name in RESERVED_USERNAMES or any(name.startswith(r) for r in RESERVED_USERNAMES):
        return "That username is reserved."
    return ""


def display_name_error(raw: str) -> str:
    name = (raw or "").strip()
    if not name or len(name) > 24:
        return "Display name must be 1–24 characters."
    if "@" in name:
        return "Do not use an email as a display name."
    if name.lower() in RESERVED_USERNAMES:
        return "That display name is reserved."
    return ""


def public_game_profile(player_id: str, username: str, display: str, avatar: dict[str, Any]) -> dict[str, Any]:
    return {
        "player_id": player_id,
        "username": normalize_username(username),
        "display_name": (display or "Sunshine Guest").strip()[:24],
        "avatar": sanitize_avatar(avatar),
        "displays": [],
    }


def avatar_store_path() -> str:
    return os.environ.get("SUNSHINE_AVATAR_STORE", os.path.join(os.path.dirname(__file__), "avatar_store.json"))


def load_avatar_store() -> dict[str, Any]:
    path = avatar_store_path()
    if not os.path.isfile(path):
        return {"accounts": {}}
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {"accounts": {}}
    return data if isinstance(data, dict) else {"accounts": {}}


def save_avatar_store(store: dict[str, Any]) -> None:
    path = avatar_store_path()
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(store, fh, indent=2)
    os.replace(tmp, path)


def upsert_account_avatar(customer_id: str, body: dict[str, Any]) -> dict[str, Any]:
    cid = (customer_id or "").strip()
    if not cid:
        raise AccountError("Sign in again.", 401)
    user_err = username_error(str(body.get("username") or ""))
    if user_err:
        raise AccountError(user_err)
    name_err = display_name_error(str(body.get("display_name") or "Sunshine Guest"))
    if name_err:
        raise AccountError(name_err)
    player_id = str(body.get("player_id") or "").strip() or f"plr_{uuid.uuid4().hex[:16]}"
    recipe = sanitize_avatar(body.get("avatar_recipe") or body.get("avatar"))
    store = load_avatar_store()
    accounts = store.get("accounts") if isinstance(store.get("accounts"), dict) else {}
    username = normalize_username(str(body.get("username") or ""))
    for other_id, row in accounts.items():
        if other_id == cid or not isinstance(row, dict):
            continue
        if normalize_username(str(row.get("username") or "")) == username:
            raise AccountError("That username is already used.")
    accounts[cid] = {
        "player_id": player_id,
        "username": username,
        "display_name": str(body.get("display_name") or "Sunshine Guest").strip()[:24],
        "avatar": recipe,
        "updated_unix": int(time.time()),
    }
    store["accounts"] = accounts
    save_avatar_store(store)
    row = accounts[cid]
    return {
        "ok": True,
        "player_id": row["player_id"],
        "public": public_game_profile(row["player_id"], row["username"], row["display_name"], row["avatar"]),
    }


def get_account_avatar(customer_id: str) -> dict[str, Any]:
    cid = (customer_id or "").strip()
    store = load_avatar_store()
    accounts = store.get("accounts") if isinstance(store.get("accounts"), dict) else {}
    row = accounts.get(cid) if isinstance(accounts.get(cid), dict) else {}
    if not row:
        return {"ok": True, "player_id": "", "public": public_game_profile("", "", "Sunshine Guest", default_avatar())}
    return {
        "ok": True,
        "player_id": row.get("player_id", ""),
        "public": public_game_profile(
            str(row.get("player_id") or ""),
            str(row.get("username") or ""),
            str(row.get("display_name") or "Sunshine Guest"),
            row.get("avatar") if isinstance(row.get("avatar"), dict) else {},
        ),
    }


def profile_update_payload(body: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(body, dict):
        raise AccountError("First name, last name, and email are required.")
    given = str(body.get("given_name") or "").strip()
    family = str(body.get("family_name") or "").strip()
    email = str(body.get("email") or body.get("email_address") or "").strip()
    if not given:
        raise AccountError("First name is required.")
    if not family:
        raise AccountError("Last name is required.")
    if not valid_email(email):
        raise AccountError("Enter an email address.")
    return {
        "given_name": given[:100],
        "family_name": family[:100],
        "email_address": email[:254],
    }


def _session_secret() -> bytes:
    raw = (
        os.environ.get("ACCOUNT_SESSION_SECRET")
        or os.environ.get("SESSION_SECRET")
        or square_token()
        or "bakery-dev-session"
    )
    return hashlib.sha256(raw.encode("utf-8")).digest()


def mint_session_token(customer_id: str, phone: str, *, ttl_seconds: int = 60 * 60 * 24 * 30) -> str:
    body = json.dumps(
        {
            "cid": (customer_id or "").strip(),
            "phone": (phone or "").strip(),
            "exp": int(time.time()) + int(ttl_seconds),
        },
        separators=(",", ":"),
    ).encode("utf-8")
    payload = base64.urlsafe_b64encode(body).rstrip(b"=").decode("ascii")
    sig = hmac.new(_session_secret(), payload.encode("ascii"), hashlib.sha256).hexdigest()[:32]
    return f"{payload}.{sig}"


def read_session_token(token: str) -> dict[str, str] | None:
    raw = (token or "").strip()
    if raw.lower().startswith("bearer "):
        raw = raw[7:].strip()
    if "." not in raw:
        return None
    payload, sig = raw.rsplit(".", 1)
    expect = hmac.new(_session_secret(), payload.encode("ascii"), hashlib.sha256).hexdigest()[:32]
    if not hmac.compare_digest(sig, expect):
        return None
    pad = "=" * ((4 - len(payload) % 4) % 4)
    try:
        data = json.loads(base64.urlsafe_b64decode(payload + pad).decode("utf-8"))
    except (ValueError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    try:
        exp = int(data.get("exp") or 0)
    except (TypeError, ValueError):
        return None
    if exp and exp < int(time.time()):
        return None
    cid = str(data.get("cid") or "").strip()
    if not cid:
        return None
    return {"customer_id": cid, "phone": str(data.get("phone") or "").strip()}


def bearer_from_headers(authorization: str = "", x_session_token: str = "") -> str:
    raw = (authorization or "").strip()
    if raw.lower().startswith("bearer "):
        return raw[7:].strip()
    return (x_session_token or "").strip()


def _money_cents(blob: Any) -> int:
    if not isinstance(blob, dict):
        return 0
    money = blob.get("total_money") if "total_money" in blob else blob
    if not isinstance(money, dict):
        return 0
    try:
        return int(money.get("amount") or 0)
    except (TypeError, ValueError):
        return 0


def _line_items(order: dict[str, Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for item in order.get("line_items") or []:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        try:
            qty = int(float(item.get("quantity") or 1))
        except (TypeError, ValueError):
            qty = 1
        mods: list[dict[str, Any]] = []
        for mod in item.get("modifiers") or []:
            parsed = _square_line_modifier(mod)
            if parsed:
                mods.append(parsed)
        note = str(item.get("note") or "").strip()
        names = [str(m.get("name") or "") for m in mods]
        if note and note not in names:
            mods.append({"name": note})
            names.append(note)
        row = {"name": name, "qty": max(1, qty)}
        row["modifiers"] = mods
        oid = str(item.get("catalog_object_id") or item.get("catalog_id") or "").strip()
        if oid:
            row["catalog_object_id"] = oid
            row["id"] = oid
        variation = str(item.get("variation_name") or "").strip()
        if variation:
            row["variation_name"] = variation
        line_cents = _money_cents(item)
        if line_cents <= 0:
            gross = item.get("gross_sales_money")
            if isinstance(gross, dict):
                line_cents = _money_cents({"total_money": gross})
        if line_cents > 0:
            row["price_cents"] = line_cents
        if names:
            row["detail"] = " · ".join(names)
        items.append(row)
    return items


def _square_line_modifier(mod: Any) -> dict[str, Any] | None:
    if isinstance(mod, str):
        label = mod.strip()
        return {"name": label} if label else None
    if not isinstance(mod, dict):
        return None
    label = str(
        mod.get("name") or mod.get("display_name") or mod.get("label") or ""
    ).strip()
    if not label:
        return None
    row_mod: dict[str, Any] = {"name": label}
    oid = str(mod.get("catalog_object_id") or mod.get("uid") or mod.get("id") or "").strip()
    if oid:
        row_mod["id"] = oid
    money = mod.get("total_price_money") or mod.get("base_price_money") or {}
    if isinstance(money, dict):
        try:
            cents = int(money.get("amount") or 0)
        except (TypeError, ValueError):
            cents = 0
        if cents > 0:
            row_mod["price_cents"] = cents
    return row_mod


def order_name(order: dict[str, Any]) -> str:
    items = _line_items(order)
    if not items:
        return "Order"
    first = items[0]["name"]
    extra = len(items) - 1
    return first if extra < 1 else f"{first} + {extra} more"


def fulfillment_state(order: dict[str, Any]) -> str:
    for ful in order.get("fulfillments") or []:
        if not isinstance(ful, dict):
            continue
        state = str(ful.get("state") or "").upper()
        if state:
            return state
    return ""


def order_status_label(order: dict[str, Any]) -> str:
    if str(order.get("state") or "").upper() == "CANCELED":
        return "canceled"
    if str(order.get("state") or "").upper() == "COMPLETED":
        return "ready"
    ful = fulfillment_state(order)
    if ful in READY_FULFILLMENT:
        return "ready"
    if ful in QUEUE_FULFILLMENT or str(order.get("state") or "").upper() == "OPEN":
        return "making"
    return "pending"


def is_in_queue(order: dict[str, Any]) -> bool:
    state = str(order.get("state") or "").upper()
    if state in ("CANCELED", "COMPLETED"):
        return False
    ful = fulfillment_state(order)
    if ful in READY_FULFILLMENT:
        return False
    return state == "OPEN" or ful in QUEUE_FULFILLMENT


def is_making(order: dict[str, Any]) -> bool:
    return order_status_label(order) == "making"


def is_paid_making(order: dict[str, Any]) -> bool:
    ## Status + kitchen ahead: paid AND still making. Unpaid OPEN checkouts out.
    return is_paid_square_order(order) and is_making(order)


def ahead_count(this_order: dict[str, Any], others: list[dict[str, Any]]) -> int:
    this_id = str(this_order.get("id") or "")
    this_at = str(this_order.get("created_at") or "")
    n = 0
    for other in others:
        if not isinstance(other, dict):
            continue
        if str(other.get("id") or "") == this_id:
            continue
        if not is_paid_making(other):
            continue
        other_at = str(other.get("created_at") or "")
        if other_at and this_at and other_at < this_at:
            n += 1
    return n


def _short_display_token(raw: str) -> str:
    text = str(raw or "").strip()
    if not text:
        return ""
    for prefix in ("QR-", "QR", "APP-", "APP ", "APP"):
        if text.upper().startswith(prefix):
            text = text[len(prefix) :].strip(" -_")
            break
    text = text.strip()
    if not text or len(text) > 12:
        return ""
    if len(text) >= 20 or text.count("-") >= 2:
        return ""
    return text


def app_order_number(order: dict[str, Any]) -> str:
    ## Short counter number customers can say. Never a Square UUID.
    for key in ("order_number", "reference_id", "ticket_name", "display_id"):
        token = _short_display_token(str(order.get(key) or ""))
        if token:
            return token
    for ful in order.get("fulfillments") or []:
        if not isinstance(ful, dict):
            continue
        token = _short_display_token(str(ful.get("ticket_name") or ""))
        if token:
            return token
    oid = re.sub(r"[^A-Za-z0-9]", "", str(order.get("id") or ""))
    if len(oid) >= 4:
        return oid[-4:].upper()
    return oid.upper()


def _tender_rows(order: dict[str, Any]) -> list[dict[str, Any]]:
    raw = order.get("tenders")
    if isinstance(raw, list):
        return [row for row in raw if isinstance(row, dict)]
    return []


def _net_amount_due_cents(order: dict[str, Any]) -> int | None:
    for key in ("net_amount_due_money", "net_amount_due"):
        blob = order.get(key)
        if isinstance(blob, dict) and blob.get("amount") is not None:
            try:
                return int(blob.get("amount") or 0)
            except (TypeError, ValueError):
                return None
        if isinstance(blob, (int, float)):
            return int(blob)
    return None


def is_paid_square_order(order: dict[str, Any]) -> bool:
    ## Square payment: tenders + due==0, or COMPLETED/PREPARED. Never DRAFT/CANCELED.
    state = str(order.get("state") or "").upper()
    if state in ("CANCELED", "CANCELLED", "DRAFT"):
        return False
    if str(order_status_label(order) or "").lower() in ("canceled", "cancelled", "draft"):
        return False
    tenders = _tender_rows(order)
    due = _net_amount_due_cents(order)
    if tenders:
        return due is None or due <= 0
    if due is not None and due > 0:
        return False
    if state == "COMPLETED":
        return True
    if fulfillment_state(order) in READY_FULFILLMENT:
        return True
    return False


def summarize_order(order: dict[str, Any], *, ahead: int | None = None) -> dict[str, Any]:
    net = order.get("net_amounts") if isinstance(order.get("net_amounts"), dict) else {}
    total = _money_cents(net) or _money_cents(order.get("total_money"))
    items = _line_items(order)
    display_no = app_order_number(order)
    due = _net_amount_due_cents(order)
    paid = is_paid_square_order(order)
    row = {
        "id": str(order.get("id") or ""),
        "order_id": str(order.get("id") or ""),
        "order_number": display_no,
        "app_order_number": display_no,
        "name": order_name(order),
        "date": str(order.get("created_at") or "")[:10],
        "created_at": str(order.get("created_at") or ""),
        "total_cents": total,
        "status": order_status_label(order),
        "state": str(order.get("state") or ""),
        "tender_count": len(_tender_rows(order)),
        "paid": paid,
        "items": items,
        "retrieved": bool(order.get("_retrieved") or _order_has_line_modifiers(order)),
    }
    if due is not None:
        row["net_amount_due_cents"] = due
    if ahead is not None:
        row["ahead"] = ahead
        row["ahead_count"] = ahead
    return row


def square_token() -> str:
    if order_svc is not None and hasattr(order_svc, "square_token"):
        return str(order_svc.square_token() or "").strip()
    return (os.environ.get("SQUARE_ACCESS_TOKEN") or "").strip()


def location_id() -> str:
    if order_svc is not None and hasattr(order_svc, "irondale_location_id"):
        return str(order_svc.irondale_location_id() or DEFAULT_LOCATION_ID)
    for key in ("SQUARE_LOCATION_ID_IRONDALE", "LOCATION_ID", "SQUARE_LOCATION_ID"):
        val = (os.environ.get(key) or "").strip()
        if val:
            return val
    return DEFAULT_LOCATION_ID


def square_api_base() -> str:
    if order_svc is not None and hasattr(order_svc, "square_api_base"):
        return str(order_svc.square_api_base())
    return (os.environ.get("SQUARE_API_BASE") or DEFAULT_API_BASE).rstrip("/")


def square_headers(token: str) -> dict[str, str]:
    if order_svc is not None and hasattr(order_svc, "square_headers"):
        return order_svc.square_headers(token)
    return {
        "Authorization": f"Bearer {token}",
        "Square-Version": SQUARE_VERSION,
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def _require_token() -> str:
    token = square_token()
    if not token:
        raise AccountError(
            "Square customer lookup is not configured on this drinks service.",
            503,
        )
    return token


def _square_json(
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    *,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    token = _require_token()
    own = client is None
    http = client or httpx.Client(timeout=20.0)
    try:
        response = http.request(
            method,
            f"{square_api_base()}{path}",
            headers=square_headers(token),
            json=payload,
        )
    finally:
        if own:
            http.close()
    body: Any = {}
    if response.content:
        try:
            body = response.json()
        except ValueError:
            body = {}
    if response.status_code >= 400:
        err = "Square request failed."
        code = "UNKNOWN"
        if isinstance(body, dict):
            errors = body.get("errors")
            if isinstance(errors, list) and errors and isinstance(errors[0], dict):
                err = str(errors[0].get("detail") or errors[0].get("code") or err)
                code = str(errors[0].get("code") or "")
        if response.status_code in (401, 403) or code in ("UNAUTHORIZED", "FORBIDDEN", "INSUFFICIENT_SCOPES"):
            raise AccountError(
                "Square token needs CUSTOMERS_READ, CUSTOMERS_WRITE, ORDERS_READ"
                " (LOYALTY_READ / LOYALTY_WRITE to enroll).",
                403,
            )
        raise AccountError(err, 502 if response.status_code >= 500 else response.status_code)
    return body if isinstance(body, dict) else {}


def search_customer_by_phone(phone: str, *, client: httpx.Client | None = None) -> dict[str, Any] | None:
    body = _square_json(
        "POST",
        "/v2/customers/search",
        {"query": {"filter": {"phone_number": {"exact": phone}}}},
        client=client,
    )
    customers = body.get("customers") if isinstance(body.get("customers"), list) else []
    for row in customers:
        if isinstance(row, dict) and row.get("id"):
            return row
    return None


def create_customer(phone: str, body: dict[str, Any], *, client: httpx.Client | None = None) -> dict[str, Any]:
    payload = {
        "idempotency_key": str(uuid.uuid4()),
        "phone_number": phone,
    }
    given = str(body.get("given_name") or "").strip()
    family = str(body.get("family_name") or "").strip()
    if given:
        payload["given_name"] = given[:100]
    if family:
        payload["family_name"] = family[:100]
    created = _square_json("POST", "/v2/customers", payload, client=client)
    customer = created.get("customer")
    if not isinstance(customer, dict) or not customer.get("id"):
        raise AccountError("Square did not create a customer.", 502)
    return customer


def retrieve_customer(customer_id: str, *, client: httpx.Client | None = None) -> dict[str, Any] | None:
    cid = (customer_id or "").strip()
    if not cid:
        return None
    try:
        body = _square_json("GET", f"/v2/customers/{cid}", client=client)
    except AccountError:
        return None
    customer = body.get("customer")
    return customer if isinstance(customer, dict) else None


def _loyalty_program_id(client: httpx.Client | None = None) -> str:
    body = _square_json("GET", "/v2/loyalty/programs", client=client)
    programs = body.get("programs") if isinstance(body.get("programs"), list) else []
    for prog in programs:
        if isinstance(prog, dict) and str(prog.get("status") or "").upper() == "ACTIVE" and prog.get("id"):
            return str(prog["id"])
    for prog in programs:
        if isinstance(prog, dict) and prog.get("id"):
            return str(prog["id"])
    return ""


def _search_loyalty(phone: str, program_id: str, *, client: httpx.Client | None = None) -> dict[str, Any]:
    body = _square_json(
        "POST",
        "/v2/loyalty/accounts/search",
        {"query": {"mappings": [{"phone_number": phone}]}},
        client=client,
    )
    accounts = body.get("loyalty_accounts") if isinstance(body.get("loyalty_accounts"), list) else []
    for row in accounts:
        if isinstance(row, dict) and (not program_id or str(row.get("program_id") or "") == program_id):
            return row
    return {}


def enroll_loyalty(phone: str, join: bool, *, client: httpx.Client | None = None) -> dict[str, Any]:
    try:
        program_id = _loyalty_program_id(client)
    except AccountError:
        return {"enrolled": False, "account_id": "", "points": 0, "program_id": ""}
    if not program_id:
        return {"enrolled": False, "account_id": "", "points": 0, "program_id": ""}
    existing = {}
    try:
        existing = _search_loyalty(phone, program_id, client=client)
    except AccountError:
        existing = {}
    if existing.get("id"):
        return {
            "enrolled": True,
            "account_id": str(existing.get("id") or ""),
            "points": int(existing.get("balance") or 0),
            "program_id": program_id,
        }
    if not join:
        return {"enrolled": False, "account_id": "", "points": 0, "program_id": program_id}
    try:
        created = _square_json(
            "POST",
            "/v2/loyalty/accounts",
            {
                "idempotency_key": str(uuid.uuid4()),
                "loyalty_account": {
                    "program_id": program_id,
                    "mapping": {"phone_number": phone},
                },
            },
            client=client,
        )
    except AccountError:
        return {"enrolled": False, "account_id": "", "points": 0, "program_id": program_id}
    account = created.get("loyalty_account") if isinstance(created.get("loyalty_account"), dict) else {}
    return {
        "enrolled": bool(account.get("id")),
        "account_id": str(account.get("id") or ""),
        "points": int(account.get("balance") or 0),
        "program_id": program_id,
    }


def _order_has_line_modifiers(order: dict[str, Any]) -> bool:
    for item in order.get("line_items") or []:
        if isinstance(item, dict) and "modifiers" in item:
            return True
    return False


def merge_full_orders(listed: list[dict[str, Any]], retrieved: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id: dict[str, dict[str, Any]] = {}
    for row in retrieved:
        if not isinstance(row, dict):
            continue
        oid = str(row.get("id") or "").strip()
        if oid:
            tagged = dict(row)
            tagged["_retrieved"] = True
            by_id[oid] = tagged
    out: list[dict[str, Any]] = []
    for row in listed:
        if not isinstance(row, dict):
            continue
        oid = str(row.get("id") or "").strip()
        full = by_id.get(oid)
        out.append(full if full is not None else row)
    return out


def retrieve_order(order_id: str, *, client: httpx.Client | None = None) -> dict[str, Any]:
    oid = (order_id or "").strip()
    if not oid:
        raise AccountError("Order id is required.")
    body = _square_json("GET", f"/v2/orders/{oid}", client=client)
    order = body.get("order")
    if not isinstance(order, dict) or not order.get("id"):
        raise AccountError("Square order not found.", 404)
    tagged = dict(order)
    tagged["_retrieved"] = True
    return tagged


def retrieve_orders(order_ids: list[str], *, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    ids = [str(oid).strip() for oid in order_ids if str(oid).strip()]
    if not ids:
        return []
    body = _square_json(
        "POST",
        "/v2/orders/batch-retrieve",
        {"location_id": location_id(), "order_ids": ids},
        client=client,
    )
    rows = body.get("orders") if isinstance(body.get("orders"), list) else []
    out: list[dict[str, Any]] = []
    for row in rows:
        if isinstance(row, dict) and row.get("id"):
            tagged = dict(row)
            tagged["_retrieved"] = True
            out.append(tagged)
    return out


def fill_orders_from_square(
    listed: list[dict[str, Any]],
    *,
    client: httpx.Client | None = None,
) -> list[dict[str, Any]]:
    """Replace SearchOrders summaries with RetrieveOrder / BatchRetrieve payloads."""
    ids = [str(row.get("id") or "").strip() for row in listed if isinstance(row, dict)]
    ids = [oid for oid in ids if oid]
    retrieved: list[dict[str, Any]] = []
    if ids:
        try:
            retrieved = retrieve_orders(ids, client=client)
        except AccountError:
            retrieved = []
        have = {str(row.get("id") or "") for row in retrieved}
        if len(have) < len(ids):
            for oid in ids:
                if oid in have:
                    continue
                try:
                    retrieved.append(retrieve_order(oid, client=client))
                    have.add(oid)
                except AccountError:
                    continue
    return merge_full_orders(listed, retrieved)


def _order_belongs_to(order: dict[str, Any], session: dict[str, Any]) -> bool:
    cid = str(session.get("customer_id") or "").strip()
    if cid and str(order.get("customer_id") or "").strip() == cid:
        return True
    want = _phone_digits(str(session.get("phone") or ""))
    if want and _phone_digits(_order_phone(order)) == want:
        return True
    # Square Online tickets sometimes omit customer_id on RetrieveOrder.
    if cid and not str(order.get("customer_id") or "").strip():
        return True
    return False


def get_order_for_session(
    token: str,
    order_id: str,
    *,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    session = read_session_token(token)
    if session is None:
        raise AccountError("Sign in again.", 401)
    raw = retrieve_order(order_id, client=client)
    if not _order_belongs_to(raw, session):
        raise AccountError("Square order not found.", 404)
    summary = summarize_order(raw)
    summary["retrieved"] = True
    return {"ok": True, "order": summary, "orders": [summary]}


def _search_orders(query: dict[str, Any], *, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    body = _square_json(
        "POST",
        "/v2/orders/search",
        {
            "location_ids": [location_id()],
            "query": query,
            "limit": 50,
        },
        client=client,
    )
    rows = body.get("orders") if isinstance(body.get("orders"), list) else []
    return [row for row in rows if isinstance(row, dict)]


def _phone_digits(raw: str) -> str:
    return re.sub(r"\D+", "", raw or "")


def _order_phone(order: dict[str, Any]) -> str:
    for ful in order.get("fulfillments") or []:
        if not isinstance(ful, dict):
            continue
        details = ful.get("pickup_details") or {}
        if not isinstance(details, dict):
            continue
        recipient = details.get("recipient") or {}
        if isinstance(recipient, dict):
            phone = str(recipient.get("phone_number") or "")
            if phone:
                return phone
    return ""


def customer_orders(customer_id: str, phone: str, *, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    found: dict[str, dict[str, Any]] = {}
    if customer_id:
        rows = _search_orders(
            {
                "filter": {"customer_filter": {"customer_ids": [customer_id]}},
                "sort": {"sort_field": "CREATED_AT", "sort_order": "DESC"},
            },
            client=client,
        )
        for row in rows:
            found[str(row.get("id") or "")] = row
    if phone:
        start = (datetime.now(timezone.utc) - timedelta(days=180)).strftime("%Y-%m-%dT00:00:00Z")
        recent = _search_orders(
            {
                "filter": {
                    "date_time_filter": {"created_at": {"start_at": start}},
                },
                "sort": {"sort_field": "CREATED_AT", "sort_order": "DESC"},
            },
            client=client,
        )
        want = _phone_digits(phone)
        for row in recent:
            oid = str(row.get("id") or "")
            if not oid or oid in found:
                continue
            if customer_id and str(row.get("customer_id") or "") == customer_id:
                found[oid] = row
                continue
            if want and _phone_digits(_order_phone(row)) == want:
                found[oid] = row
    rows = [row for oid, row in found.items() if oid]
    rows.sort(key=lambda row: str(row.get("created_at") or ""), reverse=True)
    return fill_orders_from_square(rows[:20], client=client)


def open_queue_orders(*, client: httpx.Client | None = None) -> list[dict[str, Any]]:
    return _search_orders(
        {
            "filter": {"state_filter": {"states": ["OPEN"]}},
            "sort": {"sort_field": "CREATED_AT", "sort_order": "ASC"},
        },
        client=client,
    )


def _account_payload(
    customer: dict[str, Any],
    *,
    created: bool,
    join_loyalty: bool,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    public = customer_public(customer)
    phone = public["phone"] or normalize_phone(str(customer.get("phone_number") or ""))
    loyalty = enroll_loyalty(phone, join_loyalty, client=client) if phone else {
        "enrolled": False,
        "account_id": "",
        "points": 0,
        "program_id": "",
    }
    raw_orders = customer_orders(public["id"], phone, client=client)
    queue = open_queue_orders(client=client)
    summaries = [summarize_order(row, ahead=ahead_count(row, queue)) for row in raw_orders]
    paid_orders = [row for row in summaries if row.get("paid")]
    ## Status: this customer's paid making tickets only. History stays paid (any state).
    open_orders = [row for row in summaries if row.get("paid") and row.get("status") == "making"]
    return {
        "ok": True,
        "created": created,
        "session_token": mint_session_token(public["id"], phone),
        "customer": public,
        "loyalty": loyalty,
        "orders": paid_orders,
        "open_orders": open_orders,
    }


def login_or_signup(body: dict[str, Any], *, client: httpx.Client | None = None) -> dict[str, Any]:
    if not isinstance(body, dict):
        raise AccountError("Phone is required.")
    phone = normalize_phone(str(body.get("phone") or ""))
    if not phone:
        raise AccountError("Enter a US phone number (10 digits).")
    join = bool(body.get("join_loyalty", True))
    existing = search_customer_by_phone(phone, client=client)
    if existing:
        return _account_payload(existing, created=False, join_loyalty=join, client=client)
    created = create_customer(phone, body, client=client)
    return _account_payload(created, created=True, join_loyalty=join, client=client)


def get_account(customer_id: str = "", phone: str = "", *, client: httpx.Client | None = None) -> dict[str, Any]:
    e164 = normalize_phone(phone)
    customer = retrieve_customer(customer_id, client=client) if customer_id else None
    if customer is None and e164:
        customer = search_customer_by_phone(e164, client=client)
    if customer is None:
        raise AccountError("Square customer not found.", 404)
    return _account_payload(customer, created=False, join_loyalty=True, client=client)


def get_account_for_session(token: str, *, client: httpx.Client | None = None) -> dict[str, Any]:
    session = read_session_token(token)
    if session is None:
        raise AccountError("Sign in again.", 401)
    return get_account(session.get("customer_id") or "", session.get("phone") or "", client=client)


def update_customer_profile(
    token: str,
    body: dict[str, Any],
    *,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    session = read_session_token(token)
    if session is None:
        raise AccountError("Sign in again.", 401)
    cid = str(session.get("customer_id") or "").strip()
    if not cid:
        raise AccountError("Sign in again.", 401)
    payload = profile_update_payload(body)
    customer = retrieve_customer(cid, client=client)
    if customer is None:
        raise AccountError("Square customer not found.", 404)
    version = customer.get("version")
    if version is not None:
        payload["version"] = version
    updated = _square_json("PUT", f"/v2/customers/{cid}", payload, client=client)
    row = updated.get("customer")
    if not isinstance(row, dict) or not row.get("id"):
        raise AccountError("Square did not update the customer.", 502)
    return _account_payload(row, created=False, join_loyalty=False, client=client)


def get_status(customer_id: str = "", phone: str = "", *, client: httpx.Client | None = None) -> dict[str, Any]:
    payload = get_account(customer_id, phone, client=client)
    return {
        "ok": True,
        "customer": payload["customer"],
        "open_orders": payload["open_orders"],
        "orders": payload["orders"],
    }


def list_orders(customer_id: str = "", phone: str = "", *, client: httpx.Client | None = None) -> dict[str, Any]:
    payload = get_account(customer_id, phone, client=client)
    return {
        "ok": True,
        "customer": payload["customer"],
        "orders": payload["orders"],
        "open_orders": payload["open_orders"],
    }


def _json_error(exc: AccountError):
    from fastapi.responses import JSONResponse

    return JSONResponse({"ok": False, "error": exc.message}, status_code=exc.status_code)


def mount(app) -> None:
    """Register Square customer routes on a FastAPI app (bakery-drinks).

    Login is POST-only. GET profile/orders require Authorization: Bearer
    <session_token> from that POST. Query-string phone is not accepted.
    """
    from fastapi import Body, Header

    @app.post("/order/api/account/phone")
    @app.post("/order/api/account/login")
    @app.post("/order/api/customer")
    @app.post("/order/api/login")
    @app.post("/order/api/session")
    def order_api_customer_write(body: dict = Body(...)):
        try:
            return login_or_signup(body)
        except AccountError as exc:
            return _json_error(exc)

    def _authed(authorization: str, x_session_token: str):
        token = bearer_from_headers(authorization, x_session_token)
        if not token:
            raise AccountError("Sign in again.", 401)
        return get_account_for_session(token)

    @app.get("/order/api/account")
    @app.get("/order/api/customer")
    @app.get("/order/api/session")
    @app.get("/order/api/me")
    def order_api_customer_read(
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            return _authed(authorization, x_session_token)
        except AccountError as exc:
            return _json_error(exc)

    @app.get("/order/api/account/status")
    def order_api_account_status(
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            payload = _authed(authorization, x_session_token)
            return {
                "ok": True,
                "customer": payload["customer"],
                "open_orders": payload["open_orders"],
                "orders": payload["orders"],
            }
        except AccountError as exc:
            return _json_error(exc)

    @app.get("/order/api/orders")
    def order_api_orders(
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            payload = _authed(authorization, x_session_token)
            return {
                "ok": True,
                "customer": payload["customer"],
                "orders": payload["orders"],
                "open_orders": payload["open_orders"],
            }
        except AccountError as exc:
            return _json_error(exc)

    @app.get("/order/api/account/orders/{order_id}")
    @app.get("/order/api/orders/{order_id}")
    def order_api_order_detail(
        order_id: str,
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            token = bearer_from_headers(authorization, x_session_token)
            if not token:
                raise AccountError("Sign in again.", 401)
            return get_order_for_session(token, order_id)
        except AccountError as exc:
            return _json_error(exc)

    @app.post("/order/api/account/profile")
    @app.patch("/order/api/account/profile")
    @app.put("/order/api/account/profile")
    @app.post("/order/api/customer/profile")
    @app.patch("/order/api/customer/profile")
    @app.put("/order/api/customer/profile")
    def order_api_account_profile(
        body: dict = Body(...),
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            token = bearer_from_headers(authorization, x_session_token)
            if not token:
                raise AccountError("Sign in again.", 401)
            return update_customer_profile(token, body)
        except AccountError as exc:
            return _json_error(exc)

    @app.get("/order/api/account/avatar")
    def order_api_account_avatar_get(
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            payload = _authed(authorization, x_session_token)
            cid = str((payload.get("customer") or {}).get("id") or "")
            return get_account_avatar(cid)
        except AccountError as exc:
            return _json_error(exc)

    @app.put("/order/api/account/avatar")
    @app.post("/order/api/account/avatar")
    def order_api_account_avatar_put(
        body: dict = Body(...),
        authorization: str = Header(""),
        x_session_token: str = Header(""),
    ):
        try:
            payload = _authed(authorization, x_session_token)
            cid = str((payload.get("customer") or {}).get("id") or "")
            return upsert_account_avatar(cid, body)
        except AccountError as exc:
            return _json_error(exc)
