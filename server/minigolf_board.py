"""Test-world mini-golf board.

One best round per player. The score route never reads a display name from
the client. Names come from the account record on this server.

Storage is a JSON file, the same idea as the patio avatar store. No Firestore
and no new paid service. Set MINIGOLF_SCORES_PATH to keep the file.
"""

from __future__ import annotations

import json
import os
import threading
import time
from typing import Any

PAR_TOTAL = 53
HOLE_COUNT = 18
MIN_STROKE = 1
MAX_STROKE = 10
# A real 18-hole round cannot finish instantly, and a parked phone should not
# count a multi-day timer as one round.
MIN_DURATION_SEC = 45
MAX_DURATION_SEC = 4 * 60 * 60
# Eighteen 1s is a script, not a round. Par is 53.
MIN_BELIEVABLE_TOTAL = 36
RATE_INTERVAL_SEC = 20
RATE_PER_HOUR = 12
IDEMPOTENT_SEC = 120

MONTHS = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

_LOCK = threading.RLock()
_PATH = os.environ.get("MINIGOLF_SCORES_PATH", "/tmp/minigolf_scores.json")
_ACCOUNTS: dict[str, str] = {}
_BEST: dict[str, dict[str, Any]] = {}
_HITS: dict[str, list[float]] = {}


def reset_for_tests(path: str | None = None) -> None:
    global _PATH, _ACCOUNTS, _BEST, _HITS
    with _LOCK:
        if path:
            _PATH = path
        _ACCOUNTS = {}
        _BEST = {}
        _HITS = {}
        _save_locked()


def remember_account(player_id: str, display_name: str) -> str:
    """Store the name that belongs to this player. Not used by the score body."""
    pid = (player_id or "").strip()
    name = " ".join((display_name or "").split())
    if not pid:
        raise ValueError("player id is missing")
    if not name or len(name) > 24:
        raise ValueError("account name is missing")
    with _LOCK:
        _load_locked()
        _ACCOUNTS[pid] = name
        row = _BEST.get(pid)
        if isinstance(row, dict):
            row["name"] = name
        _save_locked()
    return name


def account_name(player_id: str) -> str:
    pid = (player_id or "").strip()
    with _LOCK:
        _load_locked()
        return _ACCOUNTS.get(pid, "")


def submit(
    player_id: str,
    holes: Any,
    total: Any,
    par: Any,
    duration_sec: Any,
    client_version: Any,
    *,
    now: float | None = None,
) -> dict[str, Any]:
    pid = (player_id or "").strip()
    if not pid:
        return _err(401, "Sign in to post a score.")
    stamp = time.time() if now is None else float(now)
    parsed = _validate(holes, total, par, duration_sec, client_version)
    if parsed.get("error"):
        return parsed
    with _LOCK:
        _load_locked()
        name = _ACCOUNTS.get(pid, "")
        if not name:
            return _err(403, "Set your name on the account before posting a score.")
        previous = _BEST.get(pid)
        if previous and _same_round(previous, parsed) and stamp - float(previous.get("unix") or 0) <= IDEMPOTENT_SEC:
            return _ok(pid, name, previous, bool(previous.get("new_best")), int(parsed["total"]))
        limited = _rate_limited(pid, stamp)
        if limited:
            return limited
        _HITS.setdefault(pid, []).append(stamp)
        is_new = previous is None or int(parsed["total"]) < int(previous.get("strokes") or 0)
        if is_new:
            row = {
                "player_id": pid,
                "name": name,
                "strokes": int(parsed["total"]),
                "plus": int(parsed["total"]) - PAR_TOTAL,
                "par": PAR_TOTAL,
                "holes": list(parsed["holes"]),
                "duration_sec": int(parsed["duration_sec"]),
                "client_version": parsed["client_version"],
                "unix": int(stamp),
                "date": _date(stamp),
                "new_best": True,
            }
            _BEST[pid] = row
        elif previous is not None:
            previous["new_best"] = False
        _save_locked()
        current = _BEST[pid]
        return _ok(pid, name, current, is_new, int(parsed["total"]))


def top(limit: int = 10) -> list[dict[str, Any]]:
    try:
        count = int(limit)
    except (TypeError, ValueError):
        count = 10
    count = max(1, min(count, 10))
    with _LOCK:
        _load_locked()
        rows = list(_BEST.values())
    rows.sort(key=lambda row: (int(row.get("strokes") or 0), int(row.get("unix") or 0)))
    out: list[dict[str, Any]] = []
    for index, row in enumerate(rows[:count], start=1):
        out.append(_public(row, index))
    return out


def rank_for(player_id: str) -> int:
    pid = (player_id or "").strip()
    with _LOCK:
        _load_locked()
        return _rank_of(pid)


def _validate(holes: Any, total: Any, par: Any, duration_sec: Any, client_version: Any) -> dict[str, Any]:
    if not isinstance(holes, list) or len(holes) != HOLE_COUNT:
        return _err(400, "A round is 18 holes.")
    parsed: list[int] = []
    for hole in holes:
        stroke = _whole(hole)
        if stroke is None:
            return _err(400, "Each hole needs a stroke count.")
        if stroke < MIN_STROKE or stroke > MAX_STROKE:
            return _err(400, "Each hole must be from 1 to 10 strokes.")
        parsed.append(stroke)
    total_n = _whole(total)
    if total_n is None:
        return _err(400, "Total strokes are missing.")
    if total_n != sum(parsed):
        return _err(400, "Total strokes must equal the holes.")
    par_n = _whole(par)
    if par_n is None or par_n != PAR_TOTAL:
        return _err(400, "Par must be 53.")
    duration_n = _whole(duration_sec)
    if duration_n is None:
        return _err(400, "Round duration is missing.")
    if duration_n < MIN_DURATION_SEC or duration_n > MAX_DURATION_SEC:
        return _err(400, "Round duration is not believable.")
    if total_n < MIN_BELIEVABLE_TOTAL:
        return _err(400, "That score is not a believable round.")
    version = str(client_version or "").strip()
    if not version or len(version) > 40 or any(ch in version for ch in "\n\r\t"):
        return _err(400, "Client version is missing.")
    if version[0].isdigit() is False or "." not in version:
        return _err(400, "Client version is missing.")
    return {"holes": parsed, "total": total_n, "duration_sec": duration_n, "client_version": version}


def _rate_limited(player_id: str, stamp: float) -> dict[str, Any] | None:
    hits = [item for item in _HITS.get(player_id, []) if 0 <= stamp - item < 3600]
    _HITS[player_id] = hits
    if hits and stamp - hits[-1] < RATE_INTERVAL_SEC:
        return _err(429, "Wait a moment before posting another round.")
    if len(hits) >= RATE_PER_HOUR:
        return _err(429, "Too many rounds from this player.")
    return None


def _same_round(row: dict[str, Any], parsed: dict[str, Any]) -> bool:
    return int(row.get("strokes") or 0) == int(parsed["total"]) and list(row.get("holes") or []) == list(parsed["holes"])


def _ok(player_id: str, name: str, row: dict[str, Any], is_new: bool, posted: int) -> dict[str, Any]:
    # Caller already holds _LOCK. Do not reload the file here.
    public = _public(row, _rank_of(player_id))
    public["ok"] = True
    public["new_best"] = is_new
    public["name"] = name
    public["posted_strokes"] = posted
    return public


def _rank_of(player_id: str) -> int:
    rows = list(_BEST.values())
    rows.sort(key=lambda row: (int(row.get("strokes") or 0), int(row.get("unix") or 0)))
    for index, row in enumerate(rows, start=1):
        if row.get("player_id") == player_id:
            return index
    return 0


def _whole(value: Any) -> int | None:
    """JSON clients sometimes send 68.0. A boolean is not a stroke count."""
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return None


def _public(row: dict[str, Any], rank: int) -> dict[str, Any]:
    return {
        "rank": rank,
        "player_id": row.get("player_id") or "",
        "name": row.get("name") or "",
        "strokes": int(row.get("strokes") or 0),
        "plus": int(row.get("plus") or 0),
        "par": PAR_TOTAL,
        "date": row.get("date") or "",
    }


def _err(status: int, message: str) -> dict[str, Any]:
    return {"ok": False, "status": status, "error": message}


def _date(stamp: float) -> str:
    when = time.gmtime(stamp)
    return f"{MONTHS[when.tm_mon - 1]} {when.tm_mday}"


def _load_locked() -> None:
    global _ACCOUNTS, _BEST, _HITS
    try:
        with open(_PATH, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return
    if not isinstance(data, dict):
        return
    accounts = data.get("accounts")
    best = data.get("best")
    hits = data.get("hits")
    if isinstance(accounts, dict):
        _ACCOUNTS = {str(k): str(v) for k, v in accounts.items()}
    if isinstance(best, dict):
        _BEST = {str(k): v for k, v in best.items() if isinstance(v, dict)}
    if isinstance(hits, dict):
        _HITS = {}
        for key, values in hits.items():
            if isinstance(values, list):
                _HITS[str(key)] = [float(item) for item in values if isinstance(item, (int, float))]


def _save_locked() -> None:
    try:
        os.makedirs(os.path.dirname(_PATH) or ".", exist_ok=True)
        with open(_PATH, "w", encoding="utf-8") as fh:
            json.dump({"accounts": _ACCOUNTS, "best": _BEST, "hits": _HITS}, fh)
    except OSError:
        pass
