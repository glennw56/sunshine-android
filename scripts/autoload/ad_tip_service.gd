extends Node
## Rewarded ad that credits a FREE TIP to the STAFF tip jar (not a customer perk).
## Android: Poing Studios AdMob plugin (Godot 4.3 / v4.3.1) + AppConfig unit ids.
## Editor/desktop: mock overlay so smokes still run without the Google SDK.
## Plugin class names are resolved at runtime so this autoload parses without addons.

signal tip_credited(week_total: int)
signal ad_failed(message: String)

const LOAD_TIMEOUT_SEC := 90.0

var _showing := false
var _sdk_started := false
var _loader: Object
var _rewarded_ad: Object


func has_native_admob() -> bool:
	return Engine.has_singleton("PoingGodotAdMob") and Engine.has_singleton("PoingGodotAdMobRewardedAd")


func current_mode() -> String:
	if AppConfig.is_mock_ads():
		return "mock"
	if not has_native_admob():
		return "mock"
	return AppConfig.ad_mode


func describe() -> String:
	var unit := AppConfig.effective_rewarded_unit()
	var app_id := AppConfig.admob_app_id
	var sample := AppConfig.uses_google_sample_ids()
	var native := has_native_admob()
	var kind := "official Google test" if sample else "production"
	if AppConfig.is_mock_ads():
		return "Mock rewarded ad · AdMob skipped (SUNSHINE_AD_MODE=mock)"
	var line := "AdMob rewarded · %s unit %s\nApp id %s (mode %s)" % [kind, unit, app_id, AppConfig.ad_mode]
	if not native:
		return line + "\n(Android plugin idle here — editor uses a mock overlay)"
	return line


func play_rewarded() -> Dictionary:
	if _showing:
		return {"ok": false, "error": "An ad is already playing."}
	_showing = true
	var result: Dictionary
	if current_mode() == "mock":
		result = await _play_mock()
	else:
		result = await _try_admob()
		if not result.get("ok", false):
			ad_failed.emit(str(result.get("error", "AdMob unavailable.")))
			# Android builds must not silently credit a mock tip when AdMob fails.
			if OS.get_name() != "Android":
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
	if not ClassDB.class_exists("RewardedAdLoader"):
		return {"ok": false, "error": "AdMob plugin scripts missing."}
	if not has_native_admob():
		return {"ok": false, "error": "AdMob Android plugin not loaded."}
	var unit := AppConfig.effective_rewarded_unit()
	if unit == "":
		return {"ok": false, "error": "Set sunshine/admob_rewarded_unit or SUNSHINE_ADMOB_REWARDED_UNIT."}
	_ensure_sdk()
	_destroy_ad()
	var done := {
		"finished": false,
		"ok": false,
		"error": "",
		"rewarded": false,
	}
	_loader = ClassDB.instantiate("RewardedAdLoader")
	if _loader == null:
		return {"ok": false, "error": "Could not create RewardedAdLoader."}
	var load_cb: Object = ClassDB.instantiate("RewardedAdLoadCallback")
	load_cb.on_ad_failed_to_load = func(ad_error: Object) -> void:
		var msg := "AdMob failed to load a rewarded ad."
		if ad_error != null and "message" in ad_error:
			msg = str(ad_error.message)
		done["error"] = msg
		done["finished"] = true
	load_cb.on_ad_loaded = func(rewarded_ad: Object) -> void:
		_rewarded_ad = rewarded_ad
		var fs: Object = ClassDB.instantiate("FullScreenContentCallback")
		fs.on_ad_dismissed_full_screen_content = func() -> void:
			if not done["rewarded"]:
				done["error"] = "Ad closed before the reward — no staff tip."
			else:
				done["ok"] = true
			done["finished"] = true
			_destroy_ad()
		fs.on_ad_failed_to_show_full_screen_content = func(ad_error: Object) -> void:
			var msg := "AdMob failed to show the rewarded ad."
			if ad_error != null and "message" in ad_error:
				msg = str(ad_error.message)
			done["error"] = msg
			done["finished"] = true
			_destroy_ad()
		_rewarded_ad.set("full_screen_content_callback", fs)
		var listener: Object = ClassDB.instantiate("OnUserEarnedRewardListener")
		listener.on_user_earned_reward = func(_item: Object) -> void:
			done["rewarded"] = true
		_rewarded_ad.call("show", listener)
	var request: Object = ClassDB.instantiate("AdRequest")
	_loader.call("load", unit, request, load_cb)
	var elapsed := 0.0
	while not done["finished"] and elapsed < LOAD_TIMEOUT_SEC:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not done["finished"]:
		_destroy_ad()
		return {"ok": false, "error": "AdMob timed out waiting for a rewarded ad."}
	if done["ok"]:
		return {"ok": true, "mode": AppConfig.ad_mode, "unit": unit}
	return {"ok": false, "error": str(done.get("error", "AdMob did not complete."))}


func _ensure_sdk() -> void:
	if _sdk_started:
		return
	var plugin := Engine.get_singleton("PoingGodotAdMob")
	if plugin != null and plugin.has_method("initialize"):
		plugin.call("initialize")
	_sdk_started = true


func _destroy_ad() -> void:
	if _rewarded_ad != null and _rewarded_ad.has_method("destroy"):
		_rewarded_ad.call("destroy")
	_rewarded_ad = null
	_loader = null


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
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", Color("f4c430"))
	var body := Label.new()
	body.text = "This overlay stands in for AdMob in the editor,\nor when SUNSHINE_AD_MODE=mock.\n\nOn an Android build the same button loads a real\nAdMob rewarded unit (production tip_reward, or Google\ntest unit when SUNSHINE_AD_MODE=test).\n\nWatching credits a FREE TIP to the STAFF jar.\nIt is not a coupon or stamp for you."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
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
