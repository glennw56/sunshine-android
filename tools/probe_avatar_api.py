#!/usr/bin/env python3
"""Probe live bakery-drinks avatar forever-save.

Auth must be required. A look-recipe round-trip runs when SUNSHINE_SESSION_TOKEN
is set (Ronald's signed-in drinks session). Without a token we still prove 401
and run the in-repo file-store round-trip.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DRINKS = "https://bakery-drinks-k6uuoen7wa-ue.a.run.app/order/api/account/avatar"
RECIPE = {
    "v": 1,
    "skin": "tan",
    "hair": "wavy",
    "hair_color": "wine",
    "outfit": "wine",
    "apron": "blush",
    "hat": "beanie",
    "accessory": "flower",
}


def _request(method: str, url: str, token: str = "", body: dict | None = None) -> tuple[int, dict]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
        headers["X-Session-Token"] = token
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            raw = resp.read().decode("utf-8")
            parsed = json.loads(raw) if raw.strip() else {}
            return int(resp.status), parsed if isinstance(parsed, dict) else {"raw": parsed}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8")
        try:
            parsed = json.loads(raw) if raw.strip() else {}
        except json.JSONDecodeError:
            parsed = {"error": raw[:200]}
        return int(exc.code), parsed if isinstance(parsed, dict) else {"error": raw[:200]}


def probe_auth() -> int:
    fails = 0
    for method in ("GET", "PUT", "POST", "PATCH"):
        body = None if method == "GET" else {
            "player_id": "plr_probe",
            "username": "probe_baker",
            "display_name": "Probe",
            "avatar_recipe": RECIPE,
            "avatar": RECIPE,
        }
        code, payload = _request(method, DRINKS, body=body)
        print("LIVE %s no-token -> HTTP %s %s" % (method, code, json.dumps(payload)[:180]))
        if code != 401:
            print("FAIL: %s without Bearer should be 401, got %s" % (method, code))
            fails += 1
        else:
            print("OK  : %s requires Bearer" % method)
    return fails


def probe_session_roundtrip() -> int:
    token = os.environ.get("SUNSHINE_SESSION_TOKEN", "").strip()
    if not token:
        print("SKIP: live recipe round-trip (set SUNSHINE_SESSION_TOKEN to prove Square write)")
        return 0
    put_code, put_body = _request(
        "PUT",
        DRINKS,
        token=token,
        body={
            "player_id": "plr_probe_live",
            "username": "probe_live",
            "display_name": "Probe Live",
            "avatar_recipe": RECIPE,
            "avatar": RECIPE,
        },
    )
    print("LIVE PUT Bearer -> HTTP %s %s" % (put_code, json.dumps(put_body)[:240]))
    if put_code != 200 or not put_body.get("ok"):
        print("FAIL: signed-in PUT should save the look")
        return 1
    public = put_body.get("public") if isinstance(put_body.get("public"), dict) else {}
    avatar = public.get("avatar") if isinstance(public.get("avatar"), dict) else {}
    if avatar.get("hat") != "beanie" or avatar.get("outfit") != "wine":
        print("FAIL: PUT did not echo the look recipe")
        return 1
    get_code, get_body = _request("GET", DRINKS, token=token)
    print("LIVE GET Bearer -> HTTP %s source=%s" % (get_code, get_body.get("source")))
    got = ((get_body.get("public") or {}) if isinstance(get_body.get("public"), dict) else {}).get("avatar") or {}
    if get_code != 200 or got.get("hat") != "beanie":
        print("FAIL: GET did not return the saved look")
        return 1
    print("OK  : live drinks look-recipe round-trip source=%s" % get_body.get("source"))
    return 0


def probe_file_roundtrip() -> int:
    sys.path.insert(0, os.path.join(ROOT, "server"))
    import account as account_svc  # type: ignore

    fd, path = tempfile.mkstemp(prefix="sunshine_avatar_", suffix=".json")
    os.close(fd)
    os.environ["SUNSHINE_AVATAR_STORE"] = path
    try:
        saved = account_svc.upsert_account_avatar(
            "CUST_PROBE",
            {
                "player_id": "plr_probe_file",
                "username": "probe_file",
                "display_name": "Probe File",
                "avatar_recipe": RECIPE,
            },
        )
        got = account_svc.get_account_avatar("CUST_PROBE")
        hat = ((got.get("public") or {}).get("avatar") or {}).get("hat")
        print("FILE PUT/GET hat=%s source_put=%s" % (hat, saved.get("source")))
        if hat != "beanie" or saved["public"]["username"] != "probe_file":
            print("FAIL: in-repo avatar file-store round-trip")
            return 1
        print("OK  : in-repo look-recipe round-trip")
        return 0
    finally:
        if os.path.isfile(path):
            os.remove(path)


def main() -> int:
    fails = 0
    fails += probe_auth()
    fails += probe_file_roundtrip()
    fails += probe_session_roundtrip()
    if fails:
        print("FAIL avatar probe (%d)" % fails)
        return 1
    print("OK  avatar probe")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
