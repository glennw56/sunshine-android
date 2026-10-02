extends SceneTree
## Headless trace of the rewarded-ad sequence.
## Desktop has no AdMob SDK: the tip path must say so and must not claim an ad played.
## The phone path waits for MobileAds initialization, then load, then show.
## This machine can only run the editor mock of that second path.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fail := false
	var ads: Node = root.get_node("AdTipService")
	var save: Node = root.get_node("GameSave")
	var cfg: Node = root.get_node("AppConfig")
	var desktop: Dictionary = await ads.play_rewarded()
	print("TRACE desktop ad_shown=", desktop.get("ad_shown", "missing"), " ok=", desktop.get("ok", false))
	print("TRACE desktop notice=", ads.describe())
	if desktop.get("ad_shown", true):
		push_error("TRACE desktop claimed a Google ad played")
		fail = true
	if ads.DESKTOP_AD_NOTICE not in ads.describe():
		push_error("TRACE desktop notice missing")
		fail = true
	if not desktop.get("ok", false) or save.staff_tips < 1:
		push_error("TRACE desktop should still count a staff tip")
		fail = true

	var order: PackedStringArray = PackedStringArray()
	var ads_script: Script = load("res://addons/admob/gdscript/src/api/MobileAds.gd")
	var listener_script: Script = load("res://addons/admob/gdscript/src/api/listeners/OnInitializationCompleteListener.gd")
	var listener: Object = listener_script.new()
	listener.on_initialization_complete = func(_status: Variant) -> void:
		order.append("init_complete")
		print("TRACE init_complete")
	order.append("initialize_called")
	ads_script.initialize(listener)
	var started := Time.get_ticks_msec()
	while order.size() < 2 and Time.get_ticks_msec() - started < 5000:
		await process_frame
	if order.size() < 2 or order[0] != "initialize_called" or order[1] != "init_complete":
		push_error("TRACE init did not finish before load: %s" % str(order))
		fail = true

	var box := {"ad": null, "rewarded": false}
	var load_cb: Object = load("res://addons/admob/gdscript/src/api/listeners/RewardedAdLoadCallback.gd").new()
	load_cb.on_ad_loaded = func(ad: Object) -> void:
		box["ad"] = ad
		order.append("loaded")
		print("TRACE loaded")
	load_cb.on_ad_failed_to_load = func(ad_error: Object) -> void:
		order.append("load_failed")
		print("TRACE load_failed ", ad_error)
	var request: Object = load("res://addons/admob/gdscript/src/api/core/AdRequest.gd").new()
	var keywords: Array[String] = []
	request.keywords = keywords
	order.append("load_called")
	load("res://addons/admob/gdscript/src/api/RewardedAdLoader.gd").new().load(
		cfg.GOOGLE_TEST_REWARDED_UNIT, request, load_cb
	)
	started = Time.get_ticks_msec()
	while box["ad"] == null and Time.get_ticks_msec() - started < 5000:
		await process_frame
	if box["ad"] == null:
		push_error("TRACE rewarded load did not complete after init")
		fail = true
	else:
		var reward_listener: Object = load("res://addons/admob/gdscript/src/api/listeners/OnUserEarnedRewardListener.gd").new()
		reward_listener.on_user_earned_reward = func(_item: Object) -> void:
			box["rewarded"] = true
			order.append("reward")
			print("TRACE reward")
		box["ad"].show(reward_listener)
		order.append("show_called")
		var plugin: Object = load("res://addons/admob/internal/mock/mock_admob_factory.gd").get_mock_plugin("PoingGodotAdMobRewardedAd")
		plugin.on_rewarded_ad_user_earned_reward.emit(box["ad"]._uid, {"amount": 1, "type": "coins"})
		await process_frame
		await process_frame
		if not box["rewarded"]:
			push_error("TRACE show did not deliver the reward callback")
			fail = true
	print("TRACE order=", " ".join(order))
	if fail:
		quit(1)
	else:
		print("TRACE rewarded sequence ok")
		quit(0)
