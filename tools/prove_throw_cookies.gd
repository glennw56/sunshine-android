extends SceneTree
## Throw-cookie economy: start at 50, spend on a successful toss, block at 0,
## rewarded refill grants +200 (mock confirm off Android), and the count persists.
##
##   godot --headless --path . --rendering-method gl_compatibility -s res://tools/prove_throw_cookies.gd

var _save_backup := ""

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save := root.get_node_or_null("GameSave")
	var ads := root.get_node_or_null("AdTipService")
	if save == null or ads == null:
		_fail("autoloads missing")
		return
	if not _prove_persistence(save):
		return
	save.throw_cookies = int(save.STARTING_THROW_COOKIES)
	save.call("persist")
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	if packed == null:
		_fail("explore scene did not load")
		return
	var explore := packed.instantiate()
	root.add_child(explore)
	for _i in 8:
		await process_frame
		await physics_frame
	var hud := explore.get_node_or_null("HUD")
	var player := explore.get_node_or_null("Player")
	var count_lbl := explore.get_node_or_null("HUD/Root/CookieCount") as Label
	var toss := explore.get_node_or_null("HUD/Root/TossCookie") as Button
	var refill := explore.get_node_or_null("HUD/Root/CookieRefill") as Button
	if hud == null or player == null or count_lbl == null or toss == null or refill == null:
		_fail("cookie HUD missing")
		return
	if count_lbl.text != "50 cookies":
		_fail("HUD should start at 50 cookies, text=%s count=%s" % [count_lbl.text, str(save.throw_cookies)])
		return
	if toss.text != "Toss cookie":
		_fail("Toss label should stay Toss cookie while stock remains, text=%s" % toss.text)
		return
	if refill.text.find("+200") < 0:
		_fail("refill label should offer +200, text=%s" % refill.text)
		return
	if count_lbl.get_global_rect().intersects(toss.get_global_rect()):
		_fail("cookie count overlaps Toss")
		return
	if refill.get_global_rect().intersects(toss.get_global_rect()):
		_fail("refill overlaps Toss")
		return
	if not player.toss_cookie():
		_fail("first toss should succeed from 50")
		return
	if int(save.throw_cookies) != 49 or count_lbl.text != "49 cookies":
		_fail("HUD should show 49 after one toss, text=%s count=%s" % [count_lbl.text, str(save.throw_cookies)])
		return
	while int(save.throw_cookies) > 1:
		if not save.spend_throw_cookie():
			_fail("spend should work above 0")
			return
	player._toss_cool = 0.0
	player._throw_arming = 0.0
	if not player.toss_cookie():
		_fail("last cookie should still toss")
		return
	for _wait in 30:
		await physics_frame
		if player._throw_arming <= 0.0:
			break
	if int(save.throw_cookies) != 0 or count_lbl.text != "0 cookies" or toss.text != "Out of cookies":
		_fail("empty state missing, text=%s toss=%s count=%s" % [count_lbl.text, toss.text, str(save.throw_cookies)])
		return
	var flying_before := get_nodes_in_group("cookie_projectile").size()
	player._toss_cool = 0.0
	player._throw_arming = 0.0
	if player.toss_cookie():
		_fail("toss at 0 should return false")
		return
	if int(save.throw_cookies) != 0:
		_fail("blocked toss must not change the count")
		return
	await process_frame
	if get_nodes_in_group("cookie_projectile").size() != flying_before:
		_fail("blocked toss spawned a cookie")
		return
	if not hud.has_method("refill_throw_cookies"):
		_fail("HUD refill missing")
		return
	var tips_before := int(save.staff_tips)
	var result: Dictionary = await hud.refill_throw_cookies()
	if not result.get("ok", false):
		_fail("rewarded refill failed: %s" % str(result.get("error", result)))
		return
	if int(result.get("grant", 0)) != 200 or int(save.throw_cookies) != 200:
		_fail("refill should grant +200, result=%s count=%s" % [str(result), str(save.throw_cookies)])
		return
	if count_lbl.text != "200 cookies" or toss.text != "Toss cookie":
		_fail("HUD should show 200 after refill, text=%s toss=%s" % [count_lbl.text, toss.text])
		return
	if int(save.staff_tips) != tips_before:
		_fail("cookie refill must not credit the staff tip jar, before=%d after=%d" % [tips_before, int(save.staff_tips)])
		return
	save.throw_cookies = 200
	save.call("persist")
	save.throw_cookies = 3
	save._load()
	if int(save.throw_cookies) != 200:
		_fail("reload should keep 200 throw cookies, got %s" % str(save.throw_cookies))
		return
	print("THROW-COOKIES ok start=50 spend toss block refill=+200 persist")
	_restore(save)
	quit(0)


func _prove_persistence(save: Node) -> bool:
	var path := str(save.SAVE_PATH)
	var raw := ""
	if FileAccess.file_exists(path):
		raw = FileAccess.get_file_as_string(path)
	_save_backup = raw
	var parsed: Variant = JSON.parse_string(raw) if raw != "" else {}
	if not parsed is Dictionary:
		parsed = {}
	var payload: Dictionary = (parsed as Dictionary).duplicate(true)
	payload.erase("throw_cookies")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("could not write save")
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	save.throw_cookies = 0
	save._load()
	if int(save.throw_cookies) != int(save.STARTING_THROW_COOKIES):
		_fail("missing save key should start at 50, got %s" % str(save.throw_cookies))
		return false
	payload["throw_cookies"] = 0
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f.close()
	save._load()
	if int(save.throw_cookies) != 0:
		_fail("saved 0 should stay 0, got %s" % str(save.throw_cookies))
		return false
	print("THROW-COOKIES persist default=50 saved-zero=0")
	return true


func _restore(save: Node) -> void:
	var path := str(save.SAVE_PATH)
	if _save_backup != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(_save_backup)
			f.close()
			save._load()
			return
	save.throw_cookies = int(save.STARTING_THROW_COOKIES)
	save.call("persist")


func _fail(msg: String) -> void:
	push_error("THROW-COOKIES FAIL " + msg)
	var save := root.get_node_or_null("GameSave")
	if save:
		_restore(save)
	quit(1)
