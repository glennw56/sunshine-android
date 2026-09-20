#!/usr/bin/env python3
"""Copy Square phone-account routes onto a bakery-local checkout.

Usage:
  python3 server/apply_to_bakery_local.py /path/to/bakery-local

Then deploy bakery-drinks the same way you already do (Secret Manager token
stays on Cloud Run). This repo cannot push glennw56/bakery-local.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

IMPORT_LINE = "from app import account as account_svc\n"


def _insert_import(text: str) -> str:
    if "from app import account as account_svc" in text:
        return text
    needle = "from app import order as order_svc\n"
    if needle in text:
        return text.replace(needle, needle + IMPORT_LINE, 1)
    raise SystemExit("Could not find `from app import order as order_svc` in app/main.py")


def _insert_mount(text: str) -> str:
    if "account_svc.mount(app)" in text:
        return text
    idx = text.find("@app.get(\"/order/api/status\")")
    if idx < 0:
        raise SystemExit("Could not find /order/api/status in app/main.py")
    after = text.find("\n\n\ndef ", idx)
    if after < 0:
        after = text.find("\n\ndef ", idx)
    if after < 0:
        raise SystemExit("Could not find insertion point after /order/api/status")
    return text[:after] + "\n\naccount_svc.mount(app)\n" + text[after:]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    dest = Path(sys.argv[1]).expanduser().resolve()
    src = Path(__file__).resolve().parent / "account.py"
    main_py = dest / "app" / "main.py"
    if not src.is_file():
        raise SystemExit(f"missing {src}")
    if not main_py.is_file():
        raise SystemExit(f"not a bakery-local checkout: {dest}")
    target = dest / "app" / "account.py"
    shutil.copy2(src, target)
    text = main_py.read_text(encoding="utf-8")
    text = _insert_import(text)
    text = _insert_mount(text)
    main_py.write_text(text, encoding="utf-8")
    print(f"wrote {target}")
    print(f"mounted account routes in {main_py}")
    print("Next: redeploy Cloud Run bakery-drinks, then:")
    print("  python3 tools/probe_square_login.py --phone <10digits>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
