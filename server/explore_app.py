"""Sunshine patio room + forever-avatar fallback.

Designed for the existing bakery Cloud Run pattern: one process, scale-to-zero,
--max-instances 1 so every phone lands in the same patio.

Monthly add: $0 on bakery-drinks if mounted there, or one extra Cloud Run
service with min-instances 0 / max-instances 1 (still scale-to-zero).
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import threading
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Header, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

sys.path.insert(0, str(Path(__file__).resolve().parent))
from explore_sim import PatioRoom, mint_ticket, ticket_ok

TICKET_SECRET = os.environ.get("EXPLORE_TICKET_SECRET", "sunshine-patio-staging")
AVATAR_PATH = os.environ.get("EXPLORE_AVATAR_PATH", "/tmp/sunshine_avatar_store.json")

app = FastAPI(title="Sunshine Explore Patio")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

_room = PatioRoom()
_sockets: dict[str, WebSocket] = {}
_avatars: dict[str, dict[str, Any]] = {}
_lock = threading.Lock()


def _load_avatars() -> None:
    global _avatars
    try:
        with open(AVATAR_PATH, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            _avatars = data
    except (OSError, json.JSONDecodeError):
        _avatars = {}


def _save_avatars() -> None:
    try:
        os.makedirs(os.path.dirname(AVATAR_PATH) or ".", exist_ok=True)
        with open(AVATAR_PATH, "w", encoding="utf-8") as fh:
            json.dump(_avatars, fh)
    except OSError:
        pass


_load_avatars()


def _account_key(authorization: str | None, player_id: str) -> str:
    token = (authorization or "").replace("Bearer", "").strip()
    if token:
        return "tok_" + hashlib.sha256(token.encode("utf-8")).hexdigest()[:24]
    pid = (player_id or "").strip()
    if pid:
        return "plr_" + pid
    return ""


def _avatar_payload(row: dict[str, Any], source: str) -> dict[str, Any]:
    public = {
        "player_id": row.get("player_id") or "",
        "username": row.get("username") or "",
        "display_name": row.get("display_name") or "Sunshine Guest",
        "avatar": row.get("avatar") or {},
        "displays": [],
    }
    return {
        "ok": True,
        "player_id": public["player_id"],
        "customized": bool(row.get("customized")),
        "source": source,
        "public": public,
    }


@app.get("/health")
@app.get("/explore/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "sunshine-explore",
        "room": _room.room_id,
        "players": len(_room.players),
        "cap": _room.cap,
        "cost": "scale-to-zero Cloud Run, max-instances 1",
    }


@app.post("/explore/ticket")
def ticket(body: dict[str, Any] | None = None) -> dict[str, Any]:
    body = body or {}
    player_id = str(body.get("player_id") or "").strip() or "plr_guest"
    return mint_ticket(TICKET_SECRET, player_id, str(body.get("room_id") or "patio"))


def _avatar_get(authorization: str | None, player_id: str) -> JSONResponse:
    key = _account_key(authorization, player_id)
    if not key:
        return JSONResponse({"ok": False, "error": "Sign in or send a player_id."}, status_code=401)
    with _lock:
        row = _avatars.get(key)
    if not row:
        return JSONResponse(_avatar_payload({"player_id": player_id, "customized": False}, "empty"))
    return JSONResponse(_avatar_payload(row, "explore"))


def _avatar_put(body: dict[str, Any] | None, authorization: str | None, player_id: str) -> JSONResponse:
    body = body or {}
    key = _account_key(authorization, player_id or str(body.get("player_id") or ""))
    if not key:
        return JSONResponse({"ok": False, "error": "Sign in or send a player_id."}, status_code=401)
    row = {
        "player_id": str(body.get("player_id") or player_id or ""),
        "username": str(body.get("username") or ""),
        "display_name": str(body.get("display_name") or "Sunshine Guest"),
        "avatar": body.get("avatar_recipe") or body.get("avatar") or {},
        "customized": True,
    }
    with _lock:
        _avatars[key] = row
        _save_avatars()
    return JSONResponse(_avatar_payload(row, "explore"))


@app.get("/order/api/account/avatar")
@app.get("/api/account/avatar")
def get_avatar(
    authorization: str | None = Header(default=None),
    player_id: str = "",
) -> JSONResponse:
    return _avatar_get(authorization, player_id)


@app.put("/order/api/account/avatar")
@app.post("/order/api/account/avatar")
@app.put("/api/account/avatar")
@app.post("/api/account/avatar")
def put_avatar(
    body: dict[str, Any] | None = None,
    authorization: str | None = Header(default=None),
    player_id: str = "",
) -> JSONResponse:
    return _avatar_put(body, authorization, player_id)


async def _broadcast(payload: dict[str, Any], skip: str = "") -> None:
    dead: list[str] = []
    blob = json.dumps(payload)
    for nid, ws in list(_sockets.items()):
        if nid == skip:
            continue
        try:
            await ws.send_text(blob)
        except Exception:
            dead.append(nid)
    for nid in dead:
        _sockets.pop(nid, None)
        _room.leave(nid)


@app.websocket("/explore/ws")
async def patio_ws(ws: WebSocket) -> None:
    await ws.accept()
    net_id = ""
    try:
        raw = await ws.receive_text()
        hello = json.loads(raw)
        if hello.get("t") not in ("hello", "join"):
            await ws.send_text(json.dumps({"ok": False, "error": "Send hello first."}))
            await ws.close()
            return
        ticket = hello.get("ticket") if isinstance(hello.get("ticket"), dict) else None
        if ticket and not ticket_ok(TICKET_SECRET, ticket):
            await ws.send_text(json.dumps({"ok": False, "error": "Join ticket expired. Try again."}))
            await ws.close()
            return
        welcome = _room.join(hello)
        if not welcome.get("ok"):
            await ws.send_text(json.dumps(welcome))
            await ws.close()
            return
        net_id = str(welcome["net_id"])
        _sockets[net_id] = ws
        await ws.send_text(json.dumps(welcome))
        await _broadcast({"t": "join", "player": welcome["players"][-1]}, skip=net_id)
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            kind = str(msg.get("t") or "")
            if kind in ("state", "move"):
                if _room.apply_state(net_id, msg):
                    await _broadcast(_room.snapshot())
            elif kind == "throw":
                thrown = _room.apply_throw(net_id, msg)
                if thrown:
                    await _broadcast(thrown)
            elif kind == "chat":
                chat = _room.apply_chat(net_id, msg)
                if chat.get("ok"):
                    await _broadcast(chat)
                else:
                    await ws.send_text(json.dumps(chat))
            elif kind == "ping":
                await ws.send_text(json.dumps({"t": "pong"}))
    except WebSocketDisconnect:
        pass
    finally:
        if net_id:
            _sockets.pop(net_id, None)
            left = _room.leave(net_id)
            if left:
                await _broadcast(left)
