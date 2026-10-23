#!/usr/bin/env python3
"""Mini-golf board: two accounts, one best each, and rejected fake scores."""

import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import minigolf_board  # noqa: E402
from account import mint_session_token  # noqa: E402
from explore_app import app  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402


def holes_for(total: int) -> list[int]:
    holes = [2] * 18
    extra = total - 36
    index = 0
    while extra > 0:
        room = 8
        add = min(room, extra)
        holes[index] += add
        extra -= add
        index += 1
    return holes


class BoardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.NamedTemporaryFile(prefix="minigolf-", suffix=".json", delete=False)
        self.tmp.close()
        minigolf_board.reset_for_tests(self.tmp.name)
        self.client = TestClient(app)
        self.ada = mint_session_token("cust_ada", "+12055550101")
        self.bea = mint_session_token("cust_bea", "+12055550102")

    def tearDown(self) -> None:
        try:
            os.remove(self.tmp.name)
        except OSError:
            pass

    def _account(self, token: str, name: str) -> None:
        response = self.client.post(
            "/minigolf/account",
            headers={"Authorization": f"Bearer {token}"},
            json={"display_name": name},
        )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["name"], name)

    def _score(self, token: str, total: int, extra: dict | None = None):
        body = {
            "total": total,
            "par": 53,
            "holes": holes_for(total),
            "duration_sec": 180,
            "client_version": "0.1.114-test",
        }
        if extra:
            body.update(extra)
        return self.client.post(
            "/minigolf/score",
            headers={"Authorization": f"Bearer {token}"},
            json=body,
        )

    def test_two_accounts_show_on_the_board(self) -> None:
        self._account(self.ada, "Ada")
        self._account(self.bea, "Bea")
        ada = self._score(self.ada, 70)
        bea = self._score(self.bea, 62)
        self.assertEqual(ada.status_code, 200, ada.text)
        self.assertEqual(bea.status_code, 200, bea.text)
        self.assertTrue(ada.json()["new_best"])
        self.assertEqual(ada.json()["rank"], 1)
        self.assertEqual(bea.json()["rank"], 1)
        self.assertEqual(minigolf_board.rank_for("cust_ada"), 2)
        self.assertEqual(minigolf_board.rank_for("cust_bea"), 1)
        top = self.client.get("/minigolf/top?limit=10")
        self.assertEqual(top.status_code, 200)
        rows = top.json()["rows"]
        self.assertEqual([row["name"] for row in rows], ["Bea", "Ada"])
        self.assertEqual(rows[0]["strokes"], 62)
        self.assertEqual(rows[0]["plus"], 9)
        self.assertTrue(rows[0]["date"])
        self.assertEqual(rows[1]["strokes"], 70)
        worse = self._score(self.bea, 80, {"duration_sec": 200})
        # Rate limit: the second post is a different round inside 20s.
        self.assertEqual(worse.status_code, 429, worse.text)
        again = minigolf_board.submit(
            "cust_bea",
            holes_for(80),
            80,
            53,
            200,
            "0.1.114-test",
            now=10_000.0,
        )
        self.assertTrue(again["ok"])
        self.assertFalse(again["new_best"])
        self.assertEqual(again["strokes"], 62)
        better = minigolf_board.submit(
            "cust_bea",
            holes_for(60),
            60,
            53,
            200,
            "0.1.114-test",
            now=10_100.0,
        )
        self.assertTrue(better["new_best"])
        self.assertEqual(better["strokes"], 60)
        names = [row["name"] for row in self.client.get("/minigolf/top").json()["rows"]]
        self.assertEqual(names, ["Bea", "Ada"])

    def test_same_round_retry_is_idempotent(self) -> None:
        self._account(self.ada, "Ada")
        first = self._score(self.ada, 68)
        self.assertEqual(first.status_code, 200, first.text)
        second = self._score(self.ada, 68)
        self.assertEqual(second.status_code, 200, second.text)
        self.assertEqual(second.json()["strokes"], 68)
        self.assertEqual(len(self.client.get("/minigolf/top").json()["rows"]), 1)

    def test_name_comes_from_the_account(self) -> None:
        self._account(self.ada, "Ada")
        forged = self._score(self.ada, 64, {"display_name": "Hacker"})
        self.assertEqual(forged.status_code, 400, forged.text)
        self.assertEqual(self.client.get("/minigolf/top").json()["rows"], [])
        posted = self._score(self.ada, 64)
        self.assertEqual(posted.status_code, 200, posted.text)
        self.assertEqual(posted.json()["name"], "Ada")
        mismatch = self._score(self.ada, 66, {"player_id": "cust_bea"})
        self.assertEqual(mismatch.status_code, 403)

    def test_fake_scores_are_rejected(self) -> None:
        self._account(self.ada, "Ada")
        cases = [
            {"holes": holes_for(60)[:-1]},
            {"holes": [0] + holes_for(60)[1:]},
            {"holes": [11] + [3] * 17, "total": 11 + 51},
            {"holes": [True] + holes_for(60)[1:]},
            {"total": 99},
            {"total": 18, "holes": [1] * 18},
            {"par": 18},
            {"duration_sec": 10},
            {"duration_sec": 5 * 60 * 60},
            {"client_version": ""},
            {"client_version": "not-a-version"},
        ]
        for body in cases:
            response = self._score(self.ada, 60, body)
            self.assertEqual(response.status_code, 400, (body, response.text))
        self.assertEqual(self.client.get("/minigolf/top").json()["rows"], [])
        unsigned = self.client.post(
            "/minigolf/score",
            json={
                "total": 60,
                "par": 53,
                "holes": holes_for(60),
                "duration_sec": 180,
                "client_version": "0.1.114-test",
                "display_name": "Ada",
            },
        )
        self.assertEqual(unsigned.status_code, 401)
        missing_name = self.client.post(
            "/minigolf/score",
            headers={"Authorization": f"Bearer {self.bea}"},
            json={
                "total": 60,
                "par": 53,
                "holes": holes_for(60),
                "duration_sec": 180,
                "client_version": "0.1.114-test",
            },
        )
        self.assertEqual(missing_name.status_code, 403, missing_name.text)

    def test_limit_caps_at_ten(self) -> None:
        rows = minigolf_board.top(99)
        self.assertEqual(rows, [])
        self.assertEqual(minigolf_board.top(0), [])
        self._account(self.ada, "Ada")
        self.assertEqual(self._score(self.ada, 70).status_code, 200)
        self.assertEqual(len(self.client.get("/minigolf/top?limit=1").json()["rows"]), 1)


if __name__ == "__main__":
    unittest.main()
