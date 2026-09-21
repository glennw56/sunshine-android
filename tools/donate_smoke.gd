extends SceneTree
## Donate parse + scene compile. No patio.
##   godot --headless --path . -s res://tools/donate_smoke.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var Link := load("res://scripts/donate/donation_link.gd")
	if Link == null:
		push_error("DONATE SMOKE FAIL donation_link.gd did not compile")
		quit(1)
		return
	if Link.SQUARE_URL != "https://square.link/u/9tUzPJZQ":
		push_error("DONATE SMOKE FAIL URL")
		quit(1)
		return
	var named: String = Link.checkout_url("Ada")
	if named.find("note=") < 0:
		push_error("DONATE SMOKE FAIL note=")
		quit(1)
		return
	var html := 'window.bootstrap = {"checkoutTitle":"Sunshine\'s Bakery","donationGoalProgress":0,"checkoutLink":{"checkout_link_data":{"name":"New store improvements","link_type":"DONATION_LINK","donation_goal":{"target":{"amount":1000000,"currency":"USD"}}}}};'
	var row: Dictionary = Link.parse_bootstrap_html(html)
	if int(row.get("goal_cents", 0)) != 1000000 or int(row.get("raised_cents", -1)) != 0 or int(row.get("donor_count", -1)) != 0:
		push_error("DONATE SMOKE FAIL public parse %s" % str(row))
		quit(1)
		return
	var api: Dictionary = Link.parse_donations_api({
		"ok": true,
		"raised_cents": 2500,
		"donor_count": 1,
		"goal_cents": 1000000,
		"donors": [{"name": "Ada", "amount_cents": 2500, "at": "2026-09-20T12:01:00Z"}],
	})
	if int(api.get("raised_cents", 0)) != 2500:
		push_error("DONATE SMOKE FAIL api parse %s" % str(api))
		quit(1)
		return
	if change_scene_to_file("res://scenes/donate/donate.tscn") != OK:
		push_error("DONATE SMOKE FAIL load donate.tscn")
		quit(1)
		return
	for _i in 8:
		await process_frame
	var scene := current_scene
	if scene == null or scene.get_script() == null:
		push_error("DONATE SMOKE FAIL donate script missing")
		quit(1)
		return
	if scene.get_node_or_null("Safe/Stack/Center/Card/Pad/Col/Donors") == null:
		push_error("DONATE SMOKE FAIL Donors node")
		quit(1)
		return
	if scene.get_node_or_null("Safe/Stack/Center/Card/Pad/Col/BarWrap/Bar") == null:
		push_error("DONATE SMOKE FAIL Bar node")
		quit(1)
		return
	if scene.get_node_or_null("Safe/Stack/Center/Card/Pad/Col/BarWrap/BarAmount") == null:
		push_error("DONATE SMOKE FAIL BarAmount dollars")
		quit(1)
		return
	if Link.progress_label(0, 1000000) != "Raised $0 of $10,000":
		push_error("DONATE SMOKE FAIL dollar progress label")
		quit(1)
		return
	print("DONATE SMOKE ok")
	quit(0)
