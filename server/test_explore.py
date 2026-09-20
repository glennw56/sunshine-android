#!/usr/bin/env python3
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from explore_sim import PatioRoom, chat_blocked, mint_ticket, ticket_ok  # noqa: E402


class PatioRoomTests(unittest.TestCase):
    def test_join_and_snapshot(self) -> None:
        room = PatioRoom()
        welcome = room.join(
            {
                "protocol": 1,
                "player_id": "plr_test",
                "display_name": "Ada",
                "avatar": {"hat": "sun"},
            }
        )
        self.assertTrue(welcome["ok"])
        self.assertEqual(welcome["room_id"], "patio")
        self.assertEqual(len(welcome["players"]), 1)
        net = welcome["net_id"]
        room.players[net]["last_move"] -= 0.25
        self.assertTrue(room.apply_state(net, {"x": 1.0, "y": 0.02, "z": 10.0, "yaw": 0.4, "moving": True}))
        snap = room.snapshot()
        self.assertAlmostEqual(snap["players"][0]["x"], 1.0, places=2)
        self.assertTrue(snap["players"][0]["moving"])

    def test_room_cap(self) -> None:
        room = PatioRoom(cap=1)
        first = room.join({"protocol": 1, "player_id": "a"})
        second = room.join({"protocol": 1, "player_id": "b"})
        self.assertTrue(first["ok"])
        self.assertFalse(second["ok"])
        self.assertEqual(second["error_code"], "room_full")

    def test_protocol_mismatch(self) -> None:
        room = PatioRoom()
        bad = room.join({"protocol": 9, "player_id": "a"})
        self.assertFalse(bad["ok"])
        self.assertEqual(bad["error_code"], "protocol")

    def test_throw_and_chat(self) -> None:
        room = PatioRoom()
        welcome = room.join({"protocol": 1, "player_id": "a", "display_name": "Ada"})
        net = welcome["net_id"]
        thrown = room.apply_throw(net, {"ox": 0.0, "oy": 0.8, "oz": 11.0, "dx": 0.0, "dy": 0.1, "dz": -1.0})
        self.assertIsNotNone(thrown)
        self.assertEqual(thrown["t"], "throw")
        self.assertTrue(thrown["proj_id"])
        ok = room.apply_chat(net, {"body": "Hi patio"})
        self.assertTrue(ok["ok"])
        self.assertEqual(ok["body"], "Hi patio")
        self.assertTrue(str(ok.get("msg_id") or "").startswith("cht_"))
        self.assertGreater(int(ok.get("ts") or 0), 0)
        stamped = room.note_event(ok)
        self.assertEqual(stamped["seq"], 1)
        self.assertEqual(stamped["msg_id"], ok["msg_id"])
        self.assertEqual(len(room.events_since(0)), 1)
        self.assertEqual(len(room.events_since(1)), 0)
        blocked = room.apply_chat(net, {"body": "nazi"})
        self.assertFalse(blocked["ok"])
        hit = room.apply_impact(
            net,
            {"proj_id": thrown["proj_id"], "x": 1.2, "y": 0.2, "z": 10.4, "hit_net_id": "net_bo"},
        )
        self.assertIsNotNone(hit)
        self.assertEqual(hit["t"], "impact")
        self.assertEqual(hit["proj_id"], thrown["proj_id"])
        self.assertEqual(hit["hit_net_id"], "net_bo")
        self.assertNotIn(thrown["proj_id"], room.projectiles)

    def test_throw_accepts_nested_origin_dir(self) -> None:
        room = PatioRoom()
        welcome = room.join({"protocol": 1, "player_id": "a", "display_name": "Ada"})
        net = welcome["net_id"]
        thrown = room.apply_throw(
            net,
            {"origin": {"x": 0.2, "y": 0.8, "z": 11.0}, "dir": {"x": 1.0, "y": 0.0, "z": 0.0}},
        )
        self.assertIsNotNone(thrown)
        self.assertGreater(thrown["dx"], 10.0)
        self.assertAlmostEqual(thrown["dz"], 0.0, places=2)

    def test_speed_clamp(self) -> None:
        room = PatioRoom()
        welcome = room.join({"protocol": 1, "player_id": "a"})
        net = welcome["net_id"]
        room.players[net]["last_move"] -= 0.05
        room.apply_state(net, {"x": 80.0, "y": 0.02, "z": 11.0})
        self.assertLess(abs(room.players[net]["x"]), 8.0)

    def test_ticket_roundtrip(self) -> None:
        ticket = mint_ticket("secret", "plr_1")
        self.assertTrue(ticket_ok("secret", ticket))
        ticket["sig"] = "nope"
        self.assertFalse(ticket_ok("secret", ticket))

    def test_chat_filter(self) -> None:
        self.assertTrue(chat_blocked("nazi"))
        self.assertEqual(chat_blocked("hello sunshine"), "")

    def test_idle_prune(self) -> None:
        room = PatioRoom()
        welcome = room.join({"protocol": 1, "player_id": "ghost"}, via="http")
        net = welcome["net_id"]
        room.players[net]["last_move"] -= 20.0
        dead = room.prune_idle()
        self.assertEqual(dead, [net])
        self.assertEqual(len(room.players), 0)

    def test_join_prunes_http_ghosts_before_cap(self) -> None:
        room = PatioRoom(cap=1)
        ghost = room.join({"protocol": 1, "player_id": "ghost"}, via="http")
        self.assertTrue(ghost["ok"])
        room.players[ghost["net_id"]]["last_move"] -= 20.0
        fresh = room.join({"protocol": 1, "player_id": "fresh"}, via="http")
        self.assertTrue(fresh["ok"])
        self.assertEqual(len(room.players), 1)
        self.assertEqual(fresh["player_id"], "fresh")

    def test_http_idle_is_shorter_than_ws(self) -> None:
        room = PatioRoom()
        http = room.join({"protocol": 1, "player_id": "http_ghost"}, via="http")
        ws = room.join({"protocol": 1, "player_id": "ws_baker"}, via="ws")
        room.players[http["net_id"]]["last_move"] -= 20.0
        room.players[ws["net_id"]]["last_move"] -= 20.0
        dead = room.prune_idle()
        self.assertEqual(dead, [http["net_id"]])
        self.assertIn(ws["net_id"], room.players)

    def test_same_player_id_reclaims_seat(self) -> None:
        room = PatioRoom(cap=1)
        first = room.join({"protocol": 1, "player_id": "plr_ada", "display_name": "Ada"}, via="http")
        again = room.join({"protocol": 1, "player_id": "plr_ada", "display_name": "Ada 2"}, via="http")
        self.assertTrue(again["ok"])
        self.assertEqual(again["net_id"], first["net_id"])
        self.assertEqual(len(room.players), 1)
        self.assertEqual(room.players[first["net_id"]]["display_name"], "Ada 2")


class TwoClientPatioTests(unittest.TestCase):
    def test_http_and_ws_share_room(self) -> None:
        from fastapi.testclient import TestClient

        import explore_app

        explore_app.reset_room_for_tests()
        client = TestClient(explore_app.app)
        ada = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "a", "display_name": "Ada", "x": 1.0, "y": 0.02, "z": 11.0},
        ).json()
        bo = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "b", "display_name": "Bo", "x": -1.0, "y": 0.02, "z": 10.0},
        ).json()
        self.assertTrue(ada["ok"])
        self.assertTrue(bo["ok"])
        names = {p["display_name"] for p in bo["players"]}
        self.assertIn("Ada", names)
        self.assertIn("Bo", names)
        with client.websocket_connect("/explore/ws") as ws:
            ws.send_json({"t": "hello", "protocol": 1, "player_id": "c", "display_name": "Cam"})
            welcome = ws.receive_json()
        self.assertEqual(welcome["t"], "welcome")
        self.assertGreaterEqual(len(welcome["players"]), 3)

    def test_http_leave_frees_seat(self) -> None:
        from fastapi.testclient import TestClient

        import explore_app

        explore_app.reset_room_for_tests()
        client = TestClient(explore_app.app)
        ada = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_leave_ada", "display_name": "Ada"},
        ).json()
        self.assertTrue(ada["ok"])
        left = client.post("/explore/leave", json={"net_id": ada["net_id"]}).json()
        self.assertTrue(left["left"])
        health = client.get("/explore/health").json()
        self.assertEqual(health["players"], 0)
        self.assertEqual(health["idle_http_seconds"], 12.0)
        self.assertEqual(health["idle_ws_seconds"], 45.0)
        tick_leave = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_leave_bo", "display_name": "Bo"},
        ).json()
        gone = client.post(
            "/explore/tick",
            json={"net_id": tick_leave["net_id"], "leave": True},
        ).json()
        self.assertEqual(gone["t"], "leave")
        self.assertEqual(client.get("/explore/health").json()["players"], 0)

    def test_http_tick_relays_impact(self) -> None:
        from fastapi.testclient import TestClient

        import explore_app

        explore_app.reset_room_for_tests()
        client = TestClient(explore_app.app)
        ada = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_impact_ada", "display_name": "Ada"},
        ).json()
        tossed = client.post(
            "/explore/tick",
            json={
                "protocol": 1,
                "net_id": ada["net_id"],
                "player_id": "plr_impact_ada",
                "throw": {
                    "proj_id": "ck_test_1",
                    "ox": 0.0,
                    "oy": 0.8,
                    "oz": 11.0,
                    "dx": 0.0,
                    "dy": 0.1,
                    "dz": -1.0,
                },
            },
        ).json()
        kinds = {str(ev.get("t")) for ev in tossed.get("events") or []}
        self.assertIn("throw", kinds)
        hit = client.post(
            "/explore/tick",
            json={
                "protocol": 1,
                "net_id": ada["net_id"],
                "player_id": "plr_impact_ada",
                "impact": {"proj_id": "ck_test_1", "x": 1.0, "y": 0.2, "z": 10.0},
            },
        ).json()
        impact_events = [ev for ev in hit.get("events") or [] if ev.get("t") == "impact"]
        self.assertEqual(len(impact_events), 1)
        self.assertEqual(impact_events[0]["proj_id"], "ck_test_1")
        client.post("/explore/leave", json={"net_id": ada["net_id"]})

    def test_http_throw_reaches_other_http_and_ws(self) -> None:
        from fastapi.testclient import TestClient

        import explore_app

        explore_app.reset_room_for_tests()
        client = TestClient(explore_app.app)
        ada = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_relay_ada", "display_name": "Ada"},
        ).json()
        bo = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_relay_bo", "display_name": "Bo"},
        ).json()
        with client.websocket_connect("/explore/ws") as ws:
            ws.send_json({"t": "hello", "protocol": 1, "player_id": "plr_relay_cam", "display_name": "Cam"})
            welcome = ws.receive_json()
            self.assertEqual(welcome["t"], "welcome")
            tossed = client.post(
                "/explore/tick",
                json={
                    "protocol": 1,
                    "net_id": ada["net_id"],
                    "player_id": "plr_relay_ada",
                    "throw": {
                        "proj_id": "ck_relay_1",
                        "ox": 0.0,
                        "oy": 0.8,
                        "oz": 11.0,
                        "dx": 0.0,
                        "dy": 0.1,
                        "dz": -1.0,
                    },
                },
            ).json()
            self.assertTrue(any(str(ev.get("t")) == "throw" for ev in tossed.get("events") or []))
            seen = ws.receive_json()
            self.assertEqual(seen.get("t"), "throw")
            self.assertEqual(seen.get("proj_id"), "ck_relay_1")
        bo_tick = client.post(
            "/explore/tick",
            json={
                "protocol": 1,
                "net_id": bo["net_id"],
                "player_id": "plr_relay_bo",
                "event_seq": int(bo.get("event_seq") or 0),
            },
        ).json()
        throws = [ev for ev in bo_tick.get("events") or [] if ev.get("t") == "throw"]
        self.assertEqual(len(throws), 1)
        self.assertEqual(throws[0]["proj_id"], "ck_relay_1")
        client.post("/explore/leave", json={"net_id": ada["net_id"]})
        client.post("/explore/leave", json={"net_id": bo["net_id"]})

    def test_http_chat_reaches_other_http_and_ws_once(self) -> None:
        from fastapi.testclient import TestClient

        import explore_app

        explore_app.reset_room_for_tests()
        client = TestClient(explore_app.app)
        ada = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_chat_ada", "display_name": "Ada"},
        ).json()
        bo = client.post(
            "/explore/tick",
            json={"protocol": 1, "player_id": "plr_chat_bo", "display_name": "Bo"},
        ).json()
        with client.websocket_connect("/explore/ws") as ws:
            ws.send_json({"t": "hello", "protocol": 1, "player_id": "plr_chat_cam", "display_name": "Cam"})
            welcome = ws.receive_json()
            self.assertEqual(welcome["t"], "welcome")
            sent = client.post(
                "/explore/tick",
                json={
                    "protocol": 1,
                    "net_id": ada["net_id"],
                    "player_id": "plr_chat_ada",
                    "event_seq": int(ada.get("event_seq") or 0),
                    "chat": "Hi patio",
                },
            ).json()
            chats = [ev for ev in sent.get("events") or [] if ev.get("t") == "chat"]
            self.assertEqual(len(chats), 1)
            self.assertEqual(chats[0]["body"], "Hi patio")
            self.assertTrue(str(chats[0].get("msg_id") or "").startswith("cht_"))
            seen = ws.receive_json()
            self.assertEqual(seen.get("t"), "chat")
            self.assertEqual(seen.get("msg_id"), chats[0]["msg_id"])
            replay = client.post(
                "/explore/tick",
                json={
                    "protocol": 1,
                    "net_id": ada["net_id"],
                    "player_id": "plr_chat_ada",
                    "event_seq": int(sent.get("event_seq") or chats[0]["seq"]),
                },
            ).json()
            self.assertEqual([ev for ev in replay.get("events") or [] if ev.get("t") == "chat"], [])
        bo_tick = client.post(
            "/explore/tick",
            json={
                "protocol": 1,
                "net_id": bo["net_id"],
                "player_id": "plr_chat_bo",
                "event_seq": int(bo.get("event_seq") or 0),
            },
        ).json()
        bo_chats = [ev for ev in bo_tick.get("events") or [] if ev.get("t") == "chat"]
        self.assertEqual(len(bo_chats), 1)
        self.assertEqual(bo_chats[0]["msg_id"], chats[0]["msg_id"])
        client.post("/explore/leave", json={"net_id": ada["net_id"]})
        client.post("/explore/leave", json={"net_id": bo["net_id"]})


if __name__ == "__main__":
    unittest.main()
