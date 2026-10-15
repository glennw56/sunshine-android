#!/usr/bin/env python3
"""Pure-function checks for Square account helpers. No token, no network."""

from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "server"))

from account import (  # noqa: E402
    AccountError,
    ahead_count,
    app_order_number,
    customer_public,
    default_avatar,
    delete_account_for_session,
    display_name,
    explore_avatar_key,
    has_usable_name,
    is_in_queue,
    is_paid_making,
    is_paid_square_order,
    merge_full_orders,
    mint_session_token,
    mount,
    normalize_phone,
    order_name,
    order_status_label,
    profile_update_payload,
    public_game_profile,
    read_session_token,
    sanitize_avatar,
    square_customer_delete_enabled,
    summarize_order,
    username_error,
    upsert_account_avatar,
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
                "total_money": {"amount": 1100, "currency": "USD"},
            },
            {
                "name": "Coffee",
                "quantity": "1",
                "total_money": {"amount": 425, "currency": "USD"},
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
    if coffee.get("price_cents") != 425:
        fail("line item Square total")
    croissant = summarize_order(newer)["items"][0]
    if croissant.get("price_cents") != 1100:
        fail("pastry line Square total")
    if croissant.get("modifiers") != []:
        fail("items without Square mods still expose an empty modifiers array")
    from_strings = summarize_order({
        "id": "S",
        "created_at": "2026-09-14T10:07:00Z",
        "state": "OPEN",
        "line_items": [{
            "name": "Coffee",
            "quantity": "1",
            "modifiers": ["Oat milk", "50%"],
        }],
        "net_amounts": {"total_money": {"amount": 425}},
    })
    if [m.get("name") for m in from_strings["items"][0].get("modifiers") or []] != ["Oat milk", "50%"]:
        fail("string modifiers")
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
    with_ids = summarize_order({
        "id": "R",
        "_retrieved": True,
        "created_at": "2026-09-14T10:08:00Z",
        "state": "COMPLETED",
        "line_items": [{
            "name": "Coffee",
            "variation_name": "Hot",
            "quantity": "1",
            "catalog_object_id": "VAR_COFFEE",
            "modifiers": [{
                "name": "Oat milk",
                "catalog_object_id": "MOD_OAT",
                "base_price_money": {"amount": 75, "currency": "USD"},
            }],
            "total_money": {"amount": 425, "currency": "USD"},
        }],
        "net_amounts": {"total_money": {"amount": 425}},
    })
    if not with_ids.get("retrieved"):
        fail("RetrieveOrder summaries must flag retrieved")
    coffee_full = with_ids["items"][0]
    if coffee_full.get("catalog_object_id") != "VAR_COFFEE" or coffee_full.get("id") != "VAR_COFFEE":
        fail("line catalog_object_id from RetrieveOrder")
    if coffee_full.get("variation_name") != "Hot":
        fail("variation_name from RetrieveOrder")
    thin = {"id": "THIN", "line_items": [{"name": "Coffee", "quantity": "1"}]}
    full = {
        "id": "THIN",
        "line_items": [{
            "name": "Coffee",
            "quantity": "1",
            "catalog_object_id": "VAR_COFFEE",
            "modifiers": [{"name": "Oat milk", "catalog_object_id": "MOD_OAT"}],
        }],
    }
    merged = merge_full_orders([thin], [full])
    if merged[0].get("line_items")[0].get("modifiers")[0].get("name") != "Oat milk":
        fail("merge_full_orders should prefer RetrieveOrder payload")
    if not merged[0].get("_retrieved"):
        fail("merged retrieve payload should be marked retrieved")
    if order_status_label(ready) != "ready":
        fail("ready label")
    if is_in_queue(ready):
        fail("ready is not ahead")
    if is_paid_making(older) or is_paid_making(newer):
        fail("OPEN without tenders is not paid making")
    paid_older = dict(older)
    paid_older["tenders"] = [{"id": "T_OLD"}]
    paid_older["net_amount_due_money"] = {"amount": 0}
    paid_newer = dict(newer)
    paid_newer["tenders"] = [{"id": "T_NEW"}]
    paid_newer["net_amount_due_money"] = {"amount": 0}
    if not is_paid_making(paid_older) or not is_paid_making(paid_newer):
        fail("OPEN + tenders + due 0 is paid making")
    if is_paid_making(ready):
        fail("PREPARED is ready, not making")
    if ahead_count(paid_newer, [paid_older, paid_newer, ready, older]) != 1:
        fail("one paid making order ahead")
    if ahead_count(paid_older, [paid_older, paid_newer, ready, older]) != 0:
        fail("first paid making has 0 ahead")
    qr = dict(paid_newer)
    qr["id"] = "sq0id_ABCDEFGH1234WXYZ"
    qr["reference_id"] = "QR-13"
    if app_order_number(qr) != "13" or summarize_order(qr).get("order_number") != "13":
        fail("QR reference should become a short app order number")
    if app_order_number({"id": "sq0id_ABCDEFGH1234WXYZ"}) != "WXYZ":
        fail("missing reference_id should use a short id suffix, not the Square UUID")
    canceled = {
        "id": "X",
        "state": "CANCELED",
        "line_items": [{"name": "Coffee", "quantity": "1"}],
        "tenders": [{"amount_money": {"amount": 100}}],
    }
    draft = {"id": "D", "state": "DRAFT", "line_items": [{"name": "Coffee", "quantity": "1"}]}
    unpaid_open = {
        "id": "U",
        "state": "OPEN",
        "fulfillments": [{"state": "PROPOSED"}],
        "line_items": [{"name": "Coffee", "quantity": "1"}],
        "net_amounts": {"total_money": {"amount": 350}},
        "net_amount_due_money": {"amount": 350},
    }
    paid_completed = {
        "id": "P1",
        "state": "COMPLETED",
        "line_items": [{"name": "Coffee", "quantity": "1"}],
        "tenders": [{"id": "T1", "amount_money": {"amount": 425}}],
        "net_amount_due_money": {"amount": 0},
        "net_amounts": {"total_money": {"amount": 425}},
    }
    if is_paid_square_order(older):
        fail("OPEN unpaid without tenders must not count as paid")
    if is_paid_square_order(newer):
        fail("OPEN kitchen-looking ticket without tenders is unpaid")
    if not is_paid_square_order(ready):
        fail("PREPARED fulfillment is a paid ticket")
    if is_paid_square_order(canceled):
        fail("CANCELED is not paid")
    if is_paid_square_order(draft):
        fail("DRAFT is not paid")
    if is_paid_square_order(unpaid_open):
        fail("net_amount_due > 0 is unpaid")
    if not is_paid_square_order(paid_completed):
        fail("COMPLETED with tenders and due 0 is paid")
    if summarize_order(paid_completed).get("paid") is not True:
        fail("summarize_order should stamp paid=true")
    if summarize_order(unpaid_open).get("paid") is not False:
        fail("summarize_order should stamp paid=false for open-unpaid")


def test_avatar() -> None:
    recipe = sanitize_avatar({"skin": "NOPE", "hat": "sun", "accessory": "glasses"})
    if recipe["skin"] != "peach" or recipe["hat"] != "sun":
        fail("avatar IDs must be approved")
    if recipe["bottoms"] != "skirt" or recipe["pants"] != "wine":
        fail("missing bottoms should stay the skirt")
    pants = sanitize_avatar({"bottoms": "PANTS", "pants": "navy"})
    if pants["bottoms"] != "pants" or pants["pants"] != "navy":
        fail("pants color should stay on the recipe")
    if sanitize_avatar({"bottoms": "kilt", "pants": "gold"})["bottoms"] != "skirt":
        fail("unknown bottoms should fall back to the skirt")
    if username_error("ab") == "" or username_error("sunshine") == "":
        fail("username rules")
    pub = public_game_profile("plr_1", "Ada_1", "Ada", recipe)
    if "email" in pub or "phone" in pub or pub["username"] != "ada_1":
        fail("public profile must stay allowlisted")
    os.environ["SUNSHINE_AVATAR_STORE"] = os.path.join(ROOT, "server", "_test_avatar_store.json")
    try:
        saved = upsert_account_avatar(
            "CUST_TEST",
            {
                "player_id": "plr_test",
                "username": "ada_walk",
                "display_name": "Ada",
                "avatar_recipe": pants,
            },
        )
        if saved["public"]["player_id"] != "plr_test":
            fail("avatar upsert")
        if saved["public"]["avatar"].get("bottoms") != "pants" or saved["public"]["avatar"].get("pants") != "navy":
            fail("forever save should keep the pants slot")
        try:
            upsert_account_avatar(
                "CUST_OTHER",
                {
                    "username": "ada_walk",
                    "display_name": "Other",
                    "avatar_recipe": default_avatar(),
                },
            )
            fail("duplicate username must fail")
        except AccountError:
            pass
    finally:
        path = os.environ.get("SUNSHINE_AVATAR_STORE", "")
        if path and os.path.isfile(path):
            os.remove(path)


class _FakeResponse:
    def __init__(self, status_code: int = 200, body: dict | None = None) -> None:
        self.status_code = status_code
        payload = body if body is not None else {}
        self.content = json.dumps(payload).encode("utf-8")
        self._body = payload

    def json(self) -> dict:
        return self._body


class _FakeSquare:
    def __init__(self, status_code: int = 200) -> None:
        self.status_code = status_code
        self.calls: list[dict] = []

    def request(self, method: str, url: str, headers=None, json=None):  # noqa: A002
        self.calls.append({"method": method, "url": url, "json": json, "headers": headers})
        if self.status_code >= 400:
            return _FakeResponse(self.status_code, {"errors": [{"detail": "nope", "code": "BAD"}]})
        return _FakeResponse(200, {})


def _customer_delete_calls(fake: _FakeSquare, customer_id: str) -> list[dict]:
    suffix = "/v2/customers/" + customer_id
    return [
        call
        for call in fake.calls
        if call["method"] == "DELETE" and call["url"].rstrip("/").endswith(suffix)
    ]


def test_delete_account() -> None:
    import inspect

    source = inspect.getsource(mount)
    if '@app.delete("/order/api/account")' not in source:
        fail("DELETE /order/api/account must be registered")
    os.environ.pop("SUNSHINE_DELETE_SQUARE_CUSTOMER", None)
    if square_customer_delete_enabled():
        fail("Square customer delete must default off")
    os.environ["ACCOUNT_SESSION_SECRET"] = "unit-test-secret"
    os.environ.pop("SQUARE_ACCESS_TOKEN", None)
    tmp = tempfile.mkdtemp(prefix="sunshine_delete_")
    os.environ["SUNSHINE_AVATAR_STORE"] = os.path.join(tmp, "avatars.json")
    os.environ["SUNSHINE_SESSION_REVOCATIONS"] = os.path.join(tmp, "revocations.json")
    os.environ["EXPLORE_AVATAR_PATH"] = os.path.join(tmp, "explore.json")
    try:
        pants = sanitize_avatar({"bottoms": "pants", "pants": "navy"})
        upsert_account_avatar(
            "CUST_DEL",
            {
                "player_id": "plr_del",
                "username": "ada_walk",
                "display_name": "Ada",
                "avatar_recipe": pants,
            },
        )
        upsert_account_avatar(
            "CUST_KEEP",
            {
                "player_id": "plr_keep",
                "username": "keep_me",
                "display_name": "Keep",
                "avatar_recipe": default_avatar(),
            },
        )
        token = mint_session_token("CUST_DEL", "+12055550123")
        explore_key = explore_avatar_key(token)
        with open(os.environ["EXPLORE_AVATAR_PATH"], "w", encoding="utf-8") as fh:
            json.dump(
                {
                    explore_key: {"player_id": "plr_del", "username": "ada_walk"},
                    "plr_plr_del": {"player_id": "plr_del"},
                    "tok_other": {"player_id": "plr_keep", "username": "keep_me"},
                },
                fh,
            )
        fake = _FakeSquare()
        deleted = delete_account_for_session(token, client=fake)
        if not deleted.get("deleted") or not deleted.get("avatar_removed"):
            fail("delete should remove the forever look")
        if deleted.get("square_customer_deleted"):
            fail("Square customer delete must stay off")
        if fake.calls:
            fail("no Square calls without a token")
        if read_session_token(token) is not None:
            fail("deleted session must stop working")
        try:
            delete_account_for_session(token, client=fake)
            fail("revoked token must not delete again")
        except AccountError as exc:
            if exc.status_code != 401:
                fail("revoked delete should be 401")
        again = upsert_account_avatar(
            "CUST_NEW",
            {
                "player_id": "plr_new",
                "username": "ada_walk",
                "display_name": "Ada",
                "avatar_recipe": pants,
            },
        )
        if again["public"]["username"] != "ada_walk":
            fail("username must be free after delete")
        with open(os.environ["SUNSHINE_AVATAR_STORE"], encoding="utf-8") as fh:
            store = json.load(fh)
        accounts = store.get("accounts") or {}
        if "CUST_DEL" in accounts:
            fail("deleted customer must leave the avatar store")
        if "CUST_KEEP" not in accounts:
            fail("other customers stay in the avatar store")
        with open(os.environ["EXPLORE_AVATAR_PATH"], encoding="utf-8") as fh:
            explore = json.load(fh)
        if explore_key in explore or "plr_plr_del" in explore:
            fail("explore forever look for this session must be removed")
        if "tok_other" not in explore:
            fail("other explore rows stay")
        fresh = mint_session_token("CUST_DEL", "+12055550123")
        if read_session_token(fresh) is None:
            fail("a new sign-in after delete must mint a usable session")
        try:
            delete_account_for_session("not-a-token")
            fail("missing session")
        except AccountError as exc:
            if exc.status_code != 401:
                fail("bad token should be 401")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        os.environ.pop("SQUARE_ACCESS_TOKEN", None)
        os.environ.pop("SUNSHINE_DELETE_SQUARE_CUSTOMER", None)


def test_square_customer_delete_flag() -> None:
    os.environ["ACCOUNT_SESSION_SECRET"] = "unit-test-secret"
    os.environ["SQUARE_ACCESS_TOKEN"] = "test-token-not-live"
    tmp = tempfile.mkdtemp(prefix="sunshine_square_flag_")
    os.environ["SUNSHINE_AVATAR_STORE"] = os.path.join(tmp, "avatars.json")
    os.environ["SUNSHINE_SESSION_REVOCATIONS"] = os.path.join(tmp, "revocations.json")
    os.environ["EXPLORE_AVATAR_PATH"] = os.path.join(tmp, "explore.json")
    try:
        upsert_account_avatar(
            "CUST_SQ",
            {
                "player_id": "plr_sq",
                "username": "square_off",
                "display_name": "Off",
                "avatar_recipe": default_avatar(),
            },
        )
        token = mint_session_token("CUST_SQ", "+12055550199")
        os.environ.pop("SUNSHINE_DELETE_SQUARE_CUSTOMER", None)
        off = _FakeSquare()
        result = delete_account_for_session(token, client=off)
        if result.get("square_customer_deleted"):
            fail("flag off must not delete the Square customer")
        if _customer_delete_calls(off, "CUST_SQ"):
            fail("flag off must not call DeleteCustomer")
        avatar_calls = [
            call
            for call in off.calls
            if call["method"] == "DELETE" and "/custom-attributes/sunshine_avatar" in call["url"]
        ]
        if not avatar_calls:
            fail("flag off still removes the sunshine_avatar attribute")
        upsert_account_avatar(
            "CUST_SQ",
            {
                "player_id": "plr_sq",
                "username": "square_on",
                "display_name": "On",
                "avatar_recipe": default_avatar(),
            },
        )
        token_on = mint_session_token("CUST_SQ", "+12055550199")
        os.environ["SUNSHINE_DELETE_SQUARE_CUSTOMER"] = "true"
        if not square_customer_delete_enabled():
            fail("true enables Square customer delete")
        on = _FakeSquare()
        turned_on = delete_account_for_session(token_on, client=on)
        if not turned_on.get("square_customer_deleted"):
            fail("flag on should report the Square customer delete")
        if len(_customer_delete_calls(on, "CUST_SQ")) != 1:
            fail("flag on should DELETE /v2/customers/{id} once")
        boom = _FakeSquare(status_code=500)
        upsert_account_avatar(
            "CUST_SQ",
            {
                "player_id": "plr_sq",
                "username": "square_on",
                "display_name": "On",
                "avatar_recipe": default_avatar(),
            },
        )
        token_fail = mint_session_token("CUST_SQ", "+12055550199")
        try:
            delete_account_for_session(token_fail, client=boom)
            fail("Square failure must not report success")
        except AccountError:
            pass
        with open(os.environ["SUNSHINE_AVATAR_STORE"], encoding="utf-8") as fh:
            left = json.load(fh)
        if "CUST_SQ" not in (left.get("accounts") or {}):
            fail("failed Square delete must keep the app-side look so the user can retry")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        os.environ.pop("SQUARE_ACCESS_TOKEN", None)
        os.environ.pop("SUNSHINE_DELETE_SQUARE_CUSTOMER", None)


def main() -> int:
    test_phone()
    test_names()
    test_session_token()
    test_orders()
    test_avatar()
    test_delete_account()
    test_square_customer_delete_flag()
    print("OK  server/account helpers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
