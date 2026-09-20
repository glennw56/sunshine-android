#!/usr/bin/env python3
"""Two-client patio proof (CI + Ronald laptop).

Default: in-process FastAPI (no network). Pass an origin to hit a live room:

    python3 tools/two_client_patio.py
    python3 tools/two_client_patio.py https://sunshine-explore-xxxxx-ue.a.run.app
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "server"))


def _http_json(url: str, payload: dict) -> dict:
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=12) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _names(players: list) -> set[str]:
    return {str(p.get("display_name") or "") for p in players}


def prove_live(origin: str) -> None:
    origin = origin.rstrip("/")
    health = urllib.request.urlopen(origin + "/explore/health", timeout=12).read().decode("utf-8")
    print("health", health)
    ada = _http_json(
        origin + "/explore/tick",
        {"protocol": 1, "player_id": "plr_two_ada", "display_name": "Ada", "x": 1.0, "y": 0.02, "z": 11.0},
    )
    bo = _http_json(
        origin + "/explore/tick",
        {"protocol": 1, "player_id": "plr_two_bo", "display_name": "Bo", "x": -1.2, "y": 0.02, "z": 10.4},
    )
    ada2 = _http_json(
        origin + "/explore/tick",
        {
            "protocol": 1,
            "net_id": ada.get("net_id"),
            "player_id": "plr_two_ada",
            "display_name": "Ada",
            "x": 1.1,
            "y": 0.02,
            "z": 10.8,
        },
    )
    names = _names(ada2.get("players") or [])
    print("ada net", ada.get("net_id"), "bo net", bo.get("net_id"), "names", sorted(names))
    if "Ada" not in names or "Bo" not in names:
        raise SystemExit("FAIL live room did not show both clients")
    for nid in (ada.get("net_id"), bo.get("net_id")):
        if nid:
            try:
                _http_json(origin + "/explore/leave", {"net_id": nid, "leave": True})
            except urllib.error.HTTPError:
                pass
    print("OK two HTTPS clients share", origin)


def prove_in_process() -> None:
    from fastapi.testclient import TestClient

    import explore_app

    explore_app.reset_room_for_tests()
    client = TestClient(explore_app.app)
    health = client.get("/explore/health").json()
    assert health.get("ok") is True
    ada = client.post(
        "/explore/tick",
        json={"protocol": 1, "player_id": "plr_two_ada", "display_name": "Ada", "x": 1.0, "y": 0.02, "z": 11.0},
    ).json()
    bo = client.post(
        "/explore/tick",
        json={"protocol": 1, "player_id": "plr_two_bo", "display_name": "Bo", "x": -1.2, "y": 0.02, "z": 10.4},
    ).json()
    assert ada.get("ok") and bo.get("ok")
    with client.websocket_connect("/explore/ws") as ws:
        ws.send_text(
            json.dumps(
                {
                    "t": "hello",
                    "protocol": 1,
                    "player_id": "plr_two_cam",
                    "display_name": "Cam",
                }
            )
        )
        welcome = ws.receive_json()
    ada2 = client.post(
        "/explore/tick",
        json={
            "protocol": 1,
            "net_id": ada["net_id"],
            "player_id": "plr_two_ada",
            "display_name": "Ada",
            "x": 1.2,
            "y": 0.02,
            "z": 10.6,
        },
    ).json()
    names = _names(ada2.get("players") or [])
    print("in-process names", sorted(names), "welcome", welcome.get("t"), "players", len(welcome.get("players") or []))
    if not {"Ada", "Bo"} <= names:
        raise SystemExit("FAIL in-process HTTP clients missed each other")
    if welcome.get("t") != "welcome" or len(welcome.get("players") or []) < 3:
        raise SystemExit("FAIL websocket client did not see the HTTP pair")
    client.post("/explore/leave", json={"net_id": ada["net_id"]})
    client.post("/explore/leave", json={"net_id": bo["net_id"]})
    print("OK two HTTPS + one WSS client share one in-process patio")


def main() -> None:
    if len(sys.argv) > 1:
        prove_live(sys.argv[1])
        return
    prove_in_process()


if __name__ == "__main__":
    main()
