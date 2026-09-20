"""Authoritative COS patio room — movement, throws, chat. No anti-cheat beyond clamps."""

from __future__ import annotations

import hashlib
import hmac
import re
import time
import unicodedata
import uuid
from typing import Any

PROTOCOL = 1
ROOM_CAP = 16
ROOM_ID = "patio"
MAX_SPEED = 8.4
THROW_COOLDOWN = 0.34
THROW_SPEED = 12.0
CHAT_MAX = 180
CHAT_RATE = 1.2
# Hung WebSocket seats. Explicit disconnect already calls leave().
IDLE_SECONDS = 45.0
# HTTPS /explore/tick is ~0.12s. Smoke/capture ghosts must not pin the 16 cap.
HTTP_IDLE_SECONDS = 12.0
BANNED = (
    "nigger",
    "nigga",
    "faggot",
    "kike",
    "spic",
    "retard",
    "rape",
    "nazi",
    "child porn",
    "cp ",
)


def now() -> float:
    return time.time()


def new_id(prefix: str) -> str:
    return "%s_%s" % (prefix, uuid.uuid4().hex[:12])


def clamp(v: float, lo: float, hi: float) -> float:
    return lo if v < lo else hi if v > hi else v


def _norm_text(raw: str) -> str:
    text = unicodedata.normalize("NFKC", raw or "")
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def chat_blocked(raw: str) -> str:
    body = (raw or "").strip()
    if not body:
        return "Type a message first."
    if len(body) > CHAT_MAX:
        return "That message is too long."
    folded = _norm_text(body)
    for word in BANNED:
        if word in folded:
            return "That message is not allowed on the patio."
    return ""


def public_player(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "net_id": row["net_id"],
        "player_id": row["player_id"],
        "username": row.get("username") or "",
        "display_name": row.get("display_name") or "Sunshine Guest",
        "avatar": row.get("avatar") or {},
        "x": float(row.get("x", 0.0)),
        "y": float(row.get("y", 0.02)),
        "z": float(row.get("z", 11.0)),
        "yaw": float(row.get("yaw", 0.0)),
        "moving": bool(row.get("moving", False)),
    }


class PatioRoom:
    def __init__(self, room_id: str = ROOM_ID, cap: int = ROOM_CAP) -> None:
        self.room_id = room_id
        self.cap = cap
        self.players: dict[str, dict[str, Any]] = {}
        self.projectiles: dict[str, dict[str, Any]] = {}
        self.seq = 0

    def join(self, hello: dict[str, Any], via: str = "ws") -> dict[str, Any]:
        # Drop idle HTTPS ghosts before the cap so smoke cannot pin the patio.
        self.prune_idle()
        proto = int(hello.get("protocol") or 0)
        if proto != PROTOCOL:
            return {"ok": False, "error": "Update the app to join this patio.", "error_code": "protocol"}
        player_id = str(hello.get("player_id") or "").strip()
        transport = "http" if via == "http" else "ws"
        if player_id:
            for row in self.players.values():
                if row.get("player_id") == player_id:
                    row["via"] = transport
                    row["last_move"] = now()
                    if hello.get("display_name"):
                        row["display_name"] = str(hello.get("display_name"))[:24]
                    if isinstance(hello.get("avatar"), dict):
                        row["avatar"] = hello["avatar"]
                    return self._welcome(row)
        if len(self.players) >= self.cap:
            return {"ok": False, "error": "Patio is full (16 bakers).", "error_code": "room_full"}
        net_id = new_id("net")
        if not player_id:
            player_id = new_id("plr")
        row = {
            "net_id": net_id,
            "player_id": player_id,
            "username": str(hello.get("username") or "")[:20],
            "display_name": str(hello.get("display_name") or "Sunshine Guest")[:24],
            "avatar": hello.get("avatar") if isinstance(hello.get("avatar"), dict) else {},
            "via": transport,
            "x": 0.0,
            "y": 0.02,
            "z": 11.0,
            "yaw": 0.0,
            "moving": False,
            "last_chat": 0.0,
            "last_throw": 0.0,
            "last_move": now(),
        }
        self.players[net_id] = row
        self.seq += 1
        return self._welcome(row)

    def _welcome(self, row: dict[str, Any]) -> dict[str, Any]:
        return {
            "ok": True,
            "t": "welcome",
            "protocol": PROTOCOL,
            "room_id": self.room_id,
            "net_id": row["net_id"],
            "player_id": row["player_id"],
            "cap": self.cap,
            "players": [public_player(p) for p in self.players.values()],
            "projectiles": list(self.projectiles.values()),
        }

    def leave(self, net_id: str) -> dict[str, Any] | None:
        if net_id in self.players:
            del self.players[net_id]
            self.seq += 1
            return {"t": "leave", "net_id": net_id}
        return None

    def prune_idle(self, max_idle: float | None = None) -> list[str]:
        """Drop seats that stopped sending. HTTPS ghosts use a shorter window than WSS."""
        dead: list[str] = []
        t = now()
        for nid, row in list(self.players.items()):
            limit = max_idle if max_idle is not None else self._idle_limit(row)
            if t - float(row.get("last_move") or 0.0) > limit:
                dead.append(nid)
                self.leave(nid)
        return dead

    def _idle_limit(self, row: dict[str, Any]) -> float:
        if str(row.get("via") or "ws") == "http":
            return HTTP_IDLE_SECONDS
        return IDLE_SECONDS

    def apply_state(self, net_id: str, msg: dict[str, Any]) -> bool:
        row = self.players.get(net_id)
        if row is None:
            return False
        x = float(msg.get("x", row["x"]))
        y = float(msg.get("y", row["y"]))
        z = float(msg.get("z", row["z"]))
        dt = max(0.016, now() - float(row["last_move"]))
        dx = x - float(row["x"])
        dz = z - float(row["z"])
        dist = (dx * dx + dz * dz) ** 0.5
        if dist > MAX_SPEED * dt * 1.8:
            scale = (MAX_SPEED * dt * 1.8) / dist
            x = float(row["x"]) + dx * scale
            z = float(row["z"]) + dz * scale
        row["x"] = clamp(x, -88.0, 88.0)
        row["y"] = clamp(y, -0.05, 2.4)
        row["z"] = clamp(z, -78.0, 98.0)
        row["yaw"] = float(msg.get("yaw", row["yaw"]))
        row["moving"] = bool(msg.get("moving", False))
        if isinstance(msg.get("avatar"), dict):
            row["avatar"] = msg["avatar"]
        if msg.get("display_name"):
            row["display_name"] = str(msg["display_name"])[:24]
        row["last_move"] = now()
        return True

    def apply_throw(self, net_id: str, msg: dict[str, Any]) -> dict[str, Any] | None:
        row = self.players.get(net_id)
        if row is None:
            return None
        if now() - float(row["last_throw"]) < THROW_COOLDOWN:
            return None
        ox = float(msg.get("ox", row["x"]))
        oy = float(msg.get("oy", row["y"] + 0.72))
        oz = float(msg.get("oz", row["z"]))
        dx = float(msg.get("dx", 0.0))
        dy = float(msg.get("dy", 0.08))
        dz = float(msg.get("dz", -1.0))
        length = (dx * dx + dy * dy + dz * dz) ** 0.5 or 1.0
        dx, dy, dz = dx / length, dy / length, dz / length
        if ((ox - row["x"]) ** 2 + (oz - row["z"]) ** 2) ** 0.5 > 2.8:
            ox, oy, oz = row["x"], row["y"] + 0.72, row["z"]
        proj_id = str(msg.get("proj_id") or new_id("ck"))
        row["last_throw"] = now()
        payload = {
            "t": "throw",
            "proj_id": proj_id,
            "net_id": net_id,
            "ox": ox,
            "oy": oy,
            "oz": oz,
            "dx": dx * THROW_SPEED,
            "dy": dy * THROW_SPEED,
            "dz": dz * THROW_SPEED,
            "item_id": "practice_cookie",
        }
        self.projectiles[proj_id] = payload
        if len(self.projectiles) > 24:
            oldest = next(iter(self.projectiles))
            self.projectiles.pop(oldest, None)
        return payload

    def apply_chat(self, net_id: str, msg: dict[str, Any]) -> dict[str, Any]:
        row = self.players.get(net_id)
        if row is None:
            return {"ok": False, "error": "Join the patio first."}
        if now() - float(row["last_chat"]) < CHAT_RATE:
            return {"ok": False, "error": "Slow down a second."}
        err = chat_blocked(str(msg.get("body") or ""))
        if err:
            return {"ok": False, "error": err}
        row["last_chat"] = now()
        return {
            "ok": True,
            "t": "chat",
            "net_id": net_id,
            "display_name": row["display_name"],
            "body": str(msg.get("body") or "").strip()[:CHAT_MAX],
        }

    def snapshot(self) -> dict[str, Any]:
        self.prune_idle()
        self.seq += 1
        return {
            "t": "snapshot",
            "seq": self.seq,
            "room_id": self.room_id,
            "players": [public_player(p) for p in self.players.values()],
        }


def mint_ticket(secret: str, player_id: str, room_id: str = ROOM_ID) -> dict[str, Any]:
    issued = int(now())
    expires = issued + 300
    nonce = uuid.uuid4().hex[:16]
    ticket_id = new_id("tkt")
    msg = "%s|%s|%s|%s|%s" % (ticket_id, player_id, room_id, issued, nonce)
    sig = hmac.new(secret.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).hexdigest()
    return {
        "ok": True,
        "ticket_id": ticket_id,
        "player_id": player_id,
        "room_id": room_id,
        "issued_unix": issued,
        "expires_unix": expires,
        "nonce": nonce,
        "protocol": PROTOCOL,
        "sig": sig,
    }


def ticket_ok(secret: str, ticket: dict[str, Any]) -> bool:
    if not isinstance(ticket, dict):
        return False
    if int(ticket.get("expires_unix") or 0) < int(now()) - 5:
        return False
    msg = "%s|%s|%s|%s|%s" % (
        ticket.get("ticket_id"),
        ticket.get("player_id"),
        ticket.get("room_id"),
        ticket.get("issued_unix"),
        ticket.get("nonce"),
    )
    expect = hmac.new(secret.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).hexdigest()
    got = str(ticket.get("sig") or "")
    return hmac.compare_digest(expect, got)
