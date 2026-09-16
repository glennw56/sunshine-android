extends SceneTree
## Time bakery-drinks vs Square Online vs OrderClient.fetch_menu.
##   DISPLAY=:1 godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --resolution 720x1280 -s res://tools/diag_menu_fetch.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var oc := root.get_node("OrderClient")
	var gs := root.get_node("GameSave")
	var cfg := root.get_node("AppConfig")
	print("DIAG menu_api=", cfg.call("menu_api"))
	gs.set("cached_square_menu", {})
	oc.set("menu", {})
	oc.set("_last_menu_fingerprint", "")
	oc.set("_menu_fetching", false)
	print("DIAG isolated drinks")
	var d0 := Time.get_ticks_msec()
	var drinks_http: HTTPRequest = oc.call(
		"_begin_http",
		cfg.call("menu_api"),
		HTTPClient.METHOD_GET,
		"",
		oc.call("_json_headers"),
		12.0
	)
	var drinks_res: Dictionary = await oc.call("_finish_json", drinks_http)
	print(
		"DIAG drinks isolated msec=",
		Time.get_ticks_msec() - d0,
		" ok=",
		drinks_res.get("ok"),
		" code=",
		drinks_res.get("code"),
		" err=",
		drinks_res.get("error", "")
	)
	if drinks_res.get("data") is Dictionary:
		var raw: Variant = drinks_res["data"].get("drinks", [])
		print("DIAG drinks isolated count=", (raw as Array).size() if raw is Array else -1)
	print("DIAG isolated store")
	var s0 := Time.get_ticks_msec()
	var store_headers: PackedStringArray = oc.call(
		"_json_headers", oc.call("_square_online_headers")
	)
	var store_http: HTTPRequest = oc.call(
		"_begin_http",
		"%s&page=1" % cfg.call("square_store_catalog"),
		HTTPClient.METHOD_GET,
		"",
		store_headers,
		12.0
	)
	var store_res: Dictionary = await oc.call("_finish_json", store_http)
	print(
		"DIAG store isolated msec=",
		Time.get_ticks_msec() - s0,
		" ok=",
		store_res.get("ok"),
		" code=",
		store_res.get("code"),
		" err=",
		store_res.get("error", "")
	)
	oc.set("menu", {})
	oc.set("_menu_fetching", false)
	oc.set("_last_fetch_result", {})
	print("DIAG fetch_menu (current implementation, empty cache)")
	var t0 := Time.get_ticks_msec()
	var result: Dictionary = await oc.call("fetch_menu")
	var msec := Time.get_ticks_msec() - t0
	var drinks: Array = oc.call("drinks")
	print(
		"DIAG fetch_menu msec=",
		msec,
		" ok=",
		result.get("ok"),
		" err=",
		result.get("error", ""),
		" count=",
		drinks.size(),
		" source=",
		oc.call("catalog_source")
	)
	for item in drinks:
		if item is Dictionary:
			print(
				"DIAG item ",
				item.get("name"),
				" cents=",
				item.get("price_cents"),
				" cat=",
				item.get("category")
			)
	if msec >= 8000:
		print("DIAG HANG: fetch_menu took ", msec, "ms — likely blocked on Square Online")
	if drinks.is_empty() or not bool(result.get("ok", false)):
		push_error("DIAG FAIL catalog did not load")
		quit(1)
		return
	print("DIAG OK")
	quit(0)
