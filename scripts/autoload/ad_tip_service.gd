extends Node
## Rewarded ad that credits a FREE TIP to the STAFF tip jar (not a customer perk).
## Android and iOS: Poing Studios AdMob plugin v5.1.0 on Godot 4.7.
## GMA Next-Gen initialize() is async; wait for on_initialization_complete before load.
## Editor/desktop: mock overlay so smokes still run without the Google SDK.
## Load Poing API scripts by path. Do not use ClassDB.class_exists("RewardedAdLoader"):
## that only sees native engine classes, so exported Android reported
## "AdMob plugin scripts missing" even when RewardedAdLoader.gdc + AARs were in the APK.

signal tip_credited(week_total: int)
signal ad_failed(message: String)

const LOAD_TIMEOUT_SEC := 20.0
const INIT_TIMEOUT_SEC := 20.0
const API := "res://addons/admob/gdscript/src/api/"
const LOADER_PATH := API + "RewardedAdLoader.gd"
const LOAD_CB_PATH := API + "listeners/RewardedAdLoadCallback.gd"
const FULLSCREEN_PATH := API + "listeners/FullScreenContentCallback.gd"
const REWARD_LISTENER_PATH := API + "listeners/OnUserEarnedRewardListener.gd"
const AD_REQUEST_PATH := API + "core/AdRequest.gd"
const MOBILE_ADS_PATH := API + "MobileAds.gd"
const INIT_LISTENER_PATH := API + "listeners/OnInitializationCompleteListener.gd"
## Desktop and the editor have no Google Mobile Ads SDK. Say so. Do not pretend an ad played.
const DESKTOP_AD_NOTICE := "This computer has no Google ad SDK, so no ad can play here. Ads play on the Android and iPhone app."

var _showing := false
var _sdk_started := false
var _init_done := false
var _loader: Object
var _rewarded_ad: Object


func has_native_admob() -> bool:
	return Engine.has_singleton("PoingGodotAdMob") and Engine.has_singleton("PoingGodotAdMobRewardedAd")


func current_mode() -> String:
	if AppConfig.is_mock_ads() or not has_native_admob():
		return "mock"
	return AppConfig.ad_mode


func uses_rewarded_ads() -> bool:
	return current_mode() != "mock" and has_native_admob()


static func tip_button_label_for(os_name: String, native_ads: bool, ad_mode: String) -> String:
	## Android and desktop keep TIP VIA AD. iOS says TIP STAFF only when the
	## rewarded SDK is not actually going to play (mock, or no plugin).
	var mock := ad_mode == "mock" or ad_mode == ""
	if os_name == "iOS" and (mock or not native_ads):
		return "TIP STAFF"
	return "TIP VIA AD"


static func cookie_refill_label_for(native_ads: bool, ad_mode: String) -> String:
	var mock := ad_mode == "mock" or ad_mode == ""
	if mock or not native_ads:
		return "Get +200"
	return "Watch ad +200"


func tip_button_label() -> String:
	return tip_button_label_for(OS.get_name(), has_native_admob(), AppConfig.ad_mode)


func describe() -> String:
	if not uses_rewarded_ads():
		return DESKTOP_AD_NOTICE
	var unit := AppConfig.effective_rewarded_unit()
	var app_id := AppConfig.effective_ios_app_id() if OS.get_name() == "iOS" else AppConfig.effective_app_id()
	var sample := AppConfig.uses_google_sample_ids()
	var kind := "official Google test" if sample else "production"
	return "AdMob rewarded · %s unit %s\nApp id %s (mode %s, init %s)" % [
		kind, unit, app_id, AppConfig.ad_mode, "ready" if _init_done else "waiting",
	]


func _ready() -> void:
	if has_native_admob():
		_ensure_sdk()


func play_rewarded() -> Dictionary:
	## Staff tip jar. Cookie refills use play_rewarded_cookies() so they do not
	## also credit a tip.
	var result := await play_rewarded_ad()
	if result.get("ok", false):
		var total := GameSave.add_staff_tip(1)
		tip_credited.emit(total)
		NoticeService.staff("A customer sent a tip.")
		NoticeService.customer("Thank you.")
		result["week_total"] = total
		result["all_time"] = GameSave.staff_tips
	return result


## Same AdMob rewarded flow as Tip. iOS and mock builds use the thank-you confirm.
## Does not credit the staff tip jar.
func play_rewarded_ad(title_text: String = "Tip", body_text: String = "Thank you for tipping the staff.") -> Dictionary:
	if _showing:
		return {"ok": false, "error": "An ad is already playing."}
	_showing = true
	var result: Dictionary
	if current_mode() == "mock":
		var note := DESKTOP_AD_NOTICE
		if title_text == "Tip":
			note += " A staff tip is still counted here."
		else:
			note += " Throw cookies are still added here."
		result = await _play_confirm_tip("No Google ad", note)
		result["ad_shown"] = false
	else:
		result = await _try_admob()
		if not result.get("ok", false):
			var err := str(result.get("error", "rewarded ad failed"))
			ad_failed.emit(err)
			push_warning("Rewarded ad was not shown: %s" % err)
			# Keep the staff-tip credit, but say plainly that no Google ad played.
			result = await _play_confirm_tip("No Google ad", err)
			result["ad_shown"] = false
			result["error"] = err
	_showing = false
	return result


func cookie_refill_label() -> String:
	var mode := "mock" if AppConfig.is_mock_ads() else current_mode()
	return cookie_refill_label_for(has_native_admob(), mode)


func play_rewarded_cookies() -> Dictionary:
	var body := "Thanks for watching. +200 throw cookies."
	if OS.get_name() == "iOS" and not uses_rewarded_ads():
		body = "Thank you. +200 throw cookies."
	var result := await play_rewarded_ad("Throw cookies", body)
	if result.get("ok", false):
		var total := GameSave.grant_ad_throw_cookies()
		result["throw_cookies"] = total
		result["grant"] = GameSave.AD_THROW_COOKIE_GRANT
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
		if OS.get_name() == "iOS":
			return {"ok": false, "error": "AdMob iOS plugin not loaded."}
		return {"ok": false, "error": "AdMob Android plugin not loaded."}
	if not plugin_scripts_ok():
		return {"ok": false, "error": "AdMob RewardedAdLoader.gd failed to load from the APK."}
	var unit := AppConfig.effective_rewarded_unit()
	if unit == "":
		if OS.get_name() == "iOS":
			return {"ok": false, "error": "Set sunshine/admob_ios_rewarded_unit or SUNSHINE_ADMOB_IOS_REWARDED_UNIT."}
		return {"ok": false, "error": "Set sunshine/admob_rewarded_unit or SUNSHINE_ADMOB_REWARDED_UNIT."}
	if not await _warm_sdk():
		return {
			"ok": false,
			"ad_shown": false,
			"error": "Google Mobile Ads did not finish starting, so no ad was shown.",
		}
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
	var keywords: Array[String] = []
	request.set("keywords", keywords)
	print("ADTIP load unit=%s init_done=%s" % [unit, _init_done])
	_loader.call("load", unit, request, load_cb)
	var elapsed := 0.0
	while not done["finished"] and elapsed < LOAD_TIMEOUT_SEC:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if not done["finished"]:
		_destroy_ad()
		return {"ok": false, "error": "AdMob timed out waiting for a rewarded ad."}
	if done["ok"]:
		return {"ok": true, "ad_shown": true, "mode": AppConfig.ad_mode, "unit": unit}
	return {"ok": false, "ad_shown": false, "error": str(done.get("error", "AdMob did not complete."))}


func _ensure_sdk() -> void:
	if _sdk_started or not has_native_admob():
		return
	_sdk_started = true
	var listener := _ad_new(INIT_LISTENER_PATH)
	var ads := _ad_script(MOBILE_ADS_PATH)
	if listener == null or ads == null:
		push_warning("ADTIP MobileAds.initialize unavailable")
		return
	listener.on_initialization_complete = func(_status: Variant) -> void:
		_init_done = true
		print("ADTIP init complete")
	# Official v5 path. GMA Next-Gen throws if load() runs before this callback.
	ads.initialize(listener)


func _warm_sdk() -> bool:
	_ensure_sdk()
	if _init_done:
		return true
	var elapsed := 0.0
	while not _init_done and elapsed < INIT_TIMEOUT_SEC:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if _init_done:
		return true
	push_warning("ADTIP init timed out after %.1fs" % elapsed)
	return false


func _destroy_ad() -> void:
	if _rewarded_ad != null and _rewarded_ad.has_method("destroy"):
		_rewarded_ad.call("destroy")
	_rewarded_ad = null
	_loader = null


func _play_confirm_tip(title_text: String = "Tip", body_text: String = "Thank you for tipping the staff.") -> Dictionary:
	## Non-tech fallback when ads do not fill. Always succeeds so the caller can grant.
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	get_tree().root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.42, 0.176, 0.235, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 0)
	var sheet := BakeryTheme.card_style()
	sheet.set_corner_radius_all(28)
	sheet.content_margin_left = 28
	sheet.content_margin_top = 28
	sheet.content_margin_right = 28
	sheet.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", sheet)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", Color("6b2d3c"))
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	body.add_theme_color_override("font_color", Color("3d1f24"))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 0
	bar.custom_minimum_size = Vector2(0, 18)
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
