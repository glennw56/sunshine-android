extends Node
## Rewarded ad that credits a FREE TIP to the STAFF tip jar (not a customer perk).
## Android: Poing Studios AdMob plugin (Godot 4.3 / v4.3.1) + AppConfig unit ids.
## Editor/desktop: mock overlay so smokes still run without the Google SDK.
## Load Poing API scripts by path. Do not use ClassDB.class_exists("RewardedAdLoader"):
## that only sees native engine classes, so exported Android reported
## "AdMob plugin scripts missing" even when RewardedAdLoader.gdc + AARs were in the APK.

signal tip_credited(week_total: int)
signal ad_failed(message: String)

const LOAD_TIMEOUT_SEC := 12.0
const SDK_WARM_SEC := 1.5
const API := "res://addons/admob/gdscript/src/api/"
const LOADER_PATH := API + "RewardedAdLoader.gd"
const LOAD_CB_PATH := API + "listeners/RewardedAdLoadCallback.gd"
const FULLSCREEN_PATH := API + "listeners/FullScreenContentCallback.gd"
const REWARD_LISTENER_PATH := API + "listeners/OnUserEarnedRewardListener.gd"
const AD_REQUEST_PATH := API + "core/AdRequest.gd"

var _showing := false
var _sdk_started := false
var _sdk_warmed := false
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


func _ready() -> void:
	if has_native_admob():
		_ensure_sdk()


func play_rewarded() -> Dictionary:
	if _showing:
		return {"ok": false, "error": "An ad is already playing."}
	_showing = true
	var result: Dictionary
	if current_mode() == "mock":
		result = await _play_confirm_tip()
	else:
		result = await _try_admob()
		if not result.get("ok", false):
			ad_failed.emit(str(result.get("error", "tip load failed")))
			push_warning("TIP load failed (not shown): %s" % str(result.get("error", "")))
			# Debug sideload and unlinked Play ads must not leave a dead button.
			result = await _play_confirm_tip()
	_showing = false
	if result.get("ok", false):
		var total := GameSave.add_staff_tip(1)
		tip_credited.emit(total)
		NoticeService.staff("A customer sent a tip.")
		NoticeService.customer("Thank you.")
		result["week_total"] = total
		result["all_time"] = GameSave.staff_tips
	return result


func plugin_scripts_ok() -> bool:
	return _ad_script(LOADER_PATH) != null and _ad_script(AD_REQUEST_PATH) != null


func _ad_script(path: String) -> Script:
	return load(path) as Script


func _ad_new(path: String) -> Object:
	var script := _ad_script(path)
	if script == null:
		return null
	return script.new()


func _try_admob() -> Dictionary:
	if not has_native_admob():
		return {"ok": false, "error": "AdMob Android plugin not loaded."}
	if not plugin_scripts_ok():
		return {"ok": false, "error": "AdMob RewardedAdLoader.gd failed to load from the APK."}
	var unit := AppConfig.effective_rewarded_unit()
	if unit == "":
		return {"ok": false, "error": "Set sunshine/admob_rewarded_unit or SUNSHINE_ADMOB_REWARDED_UNIT."}
	await _warm_sdk()
	_destroy_ad()
	var done := {
		"finished": false,
		"ok": false,
		"error": "",
		"rewarded": false,
	}
	_loader = _ad_new(LOADER_PATH)
	if _loader == null:
		return {"ok": false, "error": "Could not create RewardedAdLoader."}
	var load_cb: Object = _ad_new(LOAD_CB_PATH)
	if load_cb == null:
		return {"ok": false, "error": "Could not create RewardedAdLoadCallback."}
	load_cb.on_ad_failed_to_load = func(ad_error: Object) -> void:
		var msg := "AdMob failed to load a rewarded ad."
		if ad_error != null and "message" in ad_error:
			msg = str(ad_error.message)
		done["error"] = msg
		done["finished"] = true
	load_cb.on_ad_loaded = func(rewarded_ad: Object) -> void:
		_rewarded_ad = rewarded_ad
		var fs: Object = _ad_new(FULLSCREEN_PATH)
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
		var listener: Object = _ad_new(REWARD_LISTENER_PATH)
		listener.on_user_earned_reward = func(_item: Object) -> void:
			done["rewarded"] = true
		_rewarded_ad.call("show", listener)
	var request: Object = _ad_new(AD_REQUEST_PATH)
	if request == null:
		return {"ok": false, "error": "Could not create AdRequest."}
	# Typed Array[String] is null until assigned; the native load() call needs [].
	var keywords: Array[String] = []
	request.set("keywords", keywords)
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


func _warm_sdk() -> void:
	_ensure_sdk()
	if _sdk_warmed:
		return
	await get_tree().create_timer(SDK_WARM_SEC).timeout
	_sdk_warmed = true


func _destroy_ad() -> void:
	if _rewarded_ad != null and _rewarded_ad.has_method("destroy"):
		_rewarded_ad.call("destroy")
	_rewarded_ad = null
	_loader = null


func _play_confirm_tip() -> Dictionary:
	## Non-tech fallback when ads do not fill. Always credits — no skip-deny.
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
	box.offset_top = -160
	box.offset_bottom = 160
	box.add_theme_constant_override("separation", 14)
	dim.add_child(box)
	var title := Label.new()
	title.text = "Tip"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", Color("f4c430"))
	var body := Label.new()
	body.text = "Thank you for tipping the staff."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	body.add_theme_color_override("font_color", Color("fff6ea"))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 0
	bar.custom_minimum_size = Vector2(0, 22)
	box.add_child(title)
	box.add_child(body)
	box.add_child(bar)
	var elapsed := 0.0
	var duration := 2.0
	while elapsed < duration and is_instance_valid(overlay):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		bar.value = clampf(elapsed / duration, 0.0, 1.0)
	overlay.queue_free()
	return {"ok": true, "mode": "confirm"}
