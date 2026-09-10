extends Node
## Rewarded ad that credits a FREE TIP to the STAFF tip jar (not a customer perk).
## Modes: mock (default, no keys), test (official AdMob test unit), live (env unit id).

signal tip_credited(week_total: int)
signal ad_failed(message: String)

var _showing := false


func current_mode() -> String:
	if ClassDB.class_exists("RewardedAdLoader") and not AppConfig.is_mock_ads():
		return AppConfig.ad_mode
	return "mock"


func describe() -> String:
	match current_mode():
		"test":
			return "AdMob rewarded · official test unit %s" % AppConfig.admob_rewarded_unit
		"live":
			return "AdMob rewarded · live unit from env (keep the id off git)"
		_:
			return "Mock rewarded ad · no Google SDK required"


func play_rewarded() -> Dictionary:
	if _showing:
		return {"ok": false, "error": "An ad is already playing."}
	_showing = true
	var result: Dictionary
	if current_mode() != "mock":
		result = await _try_admob()
		if not result.get("ok", false):
			ad_failed.emit(str(result.get("error", "AdMob unavailable; using mock.")))
			result = await _play_mock()
	else:
		result = await _play_mock()
	_showing = false
	if result.get("ok", false):
		var total := GameSave.add_staff_tip(1)
		tip_credited.emit(total)
		NoticeService.staff("A customer sent a FREE TIP to the staff jar.")
		NoticeService.customer("You tipped the staff — not a discount for you. Thank you!")
		result["week_total"] = total
		result["all_time"] = GameSave.staff_tips
	return result


func _try_admob() -> Dictionary:
	# Optional Poing Studios AdMob plugin (MIT). Present only if the user installed it.
	if not ClassDB.class_exists("RewardedAdLoader"):
		return {"ok": false, "error": "AdMob plugin not installed."}
	# Plugin APIs vary by version; keep this path defensive and fall back to mock.
	return {"ok": false, "error": "AdMob plugin detected but runtime wiring is opt-in; using mock overlay."}


func _play_mock() -> Dictionary:
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	get_tree().root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.04, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 14)
	dim.add_child(box)
	var title := Label.new()
	title.text = "Rewarded ad (mock)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f4c430"))
	var body := Label.new()
	body.text = "This overlay stands in for AdMob when SUNSHINE_AD_MODE=mock\nor the plugin is missing.\n\nWatching credits a FREE TIP to the STAFF jar.\nIt is not a coupon or stamp for you."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color("fff6ea"))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 0
	bar.custom_minimum_size = Vector2(0, 22)
	var skip := Button.new()
	skip.text = "Skip (no tip)"
	box.add_child(title)
	box.add_child(body)
	box.add_child(bar)
	box.add_child(skip)
	var done := {"ok": false, "skipped": false}
	skip.pressed.connect(func():
		done["skipped"] = true
	)
	var elapsed := 0.0
	var duration := 5.0
	while elapsed < duration and not done["skipped"] and is_instance_valid(overlay):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		bar.value = clampf(elapsed / duration, 0.0, 1.0)
	var skipped: bool = done["skipped"]
	overlay.queue_free()
	if skipped:
		return {"ok": false, "error": "Ad skipped — no staff tip.", "skipped": true}
	return {"ok": true, "mode": "mock"}
