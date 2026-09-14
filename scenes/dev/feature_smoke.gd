extends Node
## Run: godot --headless --path . res://scenes/dev/feature_smoke.tscn

func _ready() -> void:
	var code := await _run()
	await get_tree().process_frame
	get_tree().quit(code)


func _run() -> int:
	print("SMOKE autoloads AppConfig url=", AppConfig.order_url())
	if not _smoke_cart_tip():
		return 1
	if not _smoke_fresh_batch():
		return 1
	if not _smoke_account_session():
		return 1
	for path in [
		"res://scenes/account/login.tscn",
		"res://scenes/main_menu.tscn",
		"res://scenes/tip_ad/tip_ad.tscn",
		"res://scenes/order/order.tscn",
		"res://scenes/explore/explore_3d.tscn",
	]:
		print("SMOKE load ", path)
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("SMOKE FAIL load " + path)
			return 1
		var node: Node = packed.instantiate()
		add_child(node)
		await get_tree().process_frame
		await get_tree().process_frame
		if path.ends_with("login.tscn"):
			for n in ["Safe/Card/Pad/Col/Phone", "Safe/Card/Pad/Col/Continue", "Safe/Card/Pad/Col/Skip", "Safe/Card/Pad/Col/Loyalty"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL login missing " + n)
					return 1
			var photo := node.get_node_or_null("Storefront") as TextureRect
			if photo == null or photo.texture == null:
				push_error("SMOKE FAIL login should use the storefront photo")
				return 1
			print("SMOKE login phone + skip + storefront photo")
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/Scroll/VBox/OrderButton", "Safe/Scroll/VBox/TipButton", "Safe/Scroll/VBox/ExploreButton", "Storefront"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					return 1
			print("SMOKE main menu 3 buttons present")
			var store := node.get_node("Storefront") as TextureRect
			if store.texture == null:
				push_error("SMOKE FAIL main menu storefront photo missing")
				return 1
			var order_btn := node.get_node("Safe/Scroll/VBox/OrderButton") as Button
			var sb := order_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if sb == null or sb.bg_color.r < 0.32 or sb.bg_color.g > 0.35:
				push_error("SMOKE FAIL ORDER button should use wine bakery style, got %s" % str(sb.bg_color if sb else sb))
				return 1
			print("SMOKE main menu wine button ", sb.bg_color)
			if node.has_method("_refresh_account_ui"):
				node.call("_refresh_account_ui")
			await get_tree().process_frame
			var greet := node.get_node_or_null("Safe/Scroll/VBox/Greeting") as Label
			if greet == null or greet.text.find("Hi,") < 0:
				push_error("SMOKE FAIL logged-in home should greet by Square name, got %s" % (greet.text if greet else "?"))
				return 1
			var orders_box := node.get_node_or_null("Safe/Scroll/VBox/Orders") as Control
			if orders_box == null or not orders_box.visible:
				push_error("SMOKE FAIL previous orders list should show when signed in")
				return 1
			print("SMOKE main menu greeting ", greet.text)
		if path.ends_with("order.tscn"):
			var waited := 0.0
			while waited < 8.0 and OrderClient.drinks().is_empty():
				await get_tree().process_frame
				waited += get_process_delta_time()
			print("SMOKE order drinks=", OrderClient.drinks().size(), " source=", OrderClient.catalog_source(), " pay=", OrderClient.pay_mode(), " fallback=", OrderClient.used_fallback)
			if OrderClient.drinks().is_empty() or OrderClient.used_fallback or OrderClient.catalog_source() != "square":
				push_error("SMOKE FAIL Order catalog must be live Square (no invented fallback menu)")
				return 1
			var pastry_n := 0
			var invented_n := 0
			var cats := {}
			for drink in OrderClient.drinks():
				if not drink is Dictionary:
					continue
				if bool(drink.get("local", false)) or str(drink.get("offer_source", "square")) != "square":
					invented_n += 1
				var cat := str(drink.get("category", ""))
				cats[cat] = true
				if cat == "pastry":
					pastry_n += 1
			print("SMOKE order cats=", cats.keys(), " pastry=", pastry_n, " invented=", invented_n, " total=", OrderClient.drinks().size())
			if invented_n > 0:
				push_error("SMOKE FAIL Order listed non-Square invented items")
				return 1
			if pastry_n < 1 or cats.size() < 3:
				push_error("SMOKE FAIL Square catalog should include bakery-case + drink sections")
				return 1
			var square_n := 0
			var cartoon_n := 0
			for drink in OrderClient.drinks():
				if not drink is Dictionary:
					continue
				var photo_url := OrderClient.item_photo_url(drink)
				if photo_url.begins_with("https://"):
					square_n += 1
				if photo_url.find("croissant") >= 0 or photo_url.find("savory_") >= 0 or photo_url.find("loaf") >= 0:
					cartoon_n += 1
			print("SMOKE order square photos=", square_n, " cartoon=", cartoon_n)
			if square_n < 8:
				push_error("SMOKE FAIL Order rows should use Square HTTPS photos when Square has them")
				return 1
			if cartoon_n > 0:
				push_error("SMOKE FAIL Order must not use cartoon pastry tiles as product photos")
				return 1
			var photos := 0
			var content := node.get_node_or_null("Safe/VBox/Body/Content")
			if content:
				photos = _count_texture_rects(content)
			print("SMOKE order row photos=", photos)
			if photos < 3:
				push_error("SMOKE FAIL menu rows should show product photos")
				return 1
			if not await _smoke_order_prices_and_total(node):
				return 1
			if node.get_node_or_null("Safe/VBox/Jumps") == null:
				push_error("SMOKE FAIL category jump chips missing")
				return 1
			if node.get_node_or_null("Safe/VBox/CartBar") == null:
				push_error("SMOKE FAIL kiosk cart bar missing")
				return 1
			if _find_button_text(node, "Staff") != null:
				push_error("SMOKE FAIL Staff tab must be removed from the customer Order screen")
				return 1
			if _find_button_text(node, "Status") == null:
				push_error("SMOKE FAIL Status tab missing")
				return 1
			print("SMOKE order tabs have Status and no Staff")
			if not await _smoke_order_cart_tip_ui(node):
				return 1
		if path.ends_with("explore_3d.tscn"):
			GameSave.debug_unix = _chicago_morning_unix()
			print("SMOKE fresh-batch clock hour=", GameSave.chicago_datetime().get("hour"), " active=", GameSave.is_fresh_batch_active())
			node.queue_free()
			await get_tree().process_frame
			node = packed.instantiate()
			add_child(node)
			await get_tree().process_frame
			await get_tree().process_frame
			var world := node.get_node("World")
			print("SMOKE explore world children=", world.get_child_count())
			if world.get_child_count() < 8:
				push_error("SMOKE FAIL explore world too empty")
				return 1
			var pickups := 0
			var indoor_pickups := 0
			var extra_in := 0
			var extra_out := 0
			for child in world.get_children():
				if child is CollectiblePickup:
					pickups += 1
					var indoor: bool = child.position.z > 0.0 and child.position.z < 6.0
					if indoor:
						indoor_pickups += 1
					if child.is_fresh_batch:
						if indoor:
							extra_in += 1
						else:
							extra_out += 1
			print("SMOKE explore pickups=", pickups, " indoor=", indoor_pickups, " fresh_in=", extra_in, " fresh_out=", extra_out)
			if pickups < 3 or pickups > 6 or indoor_pickups < 1:
				push_error("SMOKE FAIL MVP expects 3 cube pastries (1–3 indoor+yard), got pickups=%d indoor=%d" % [pickups, indoor_pickups])
				return 1
			var cube_pastries := 0
			for child in world.get_children():
				if child is CollectiblePickup and child.get_node_or_null("PastryCube") != null:
					cube_pastries += 1
			if cube_pastries < 3:
				push_error("SMOKE FAIL collectibles should be cube pastries")
				return 1
			var npcs := 0
			for child in world.get_children():
				if child.is_in_group("village_npc"):
					npcs += 1
			print("SMOKE shop staff npcs=", npcs, " world=", world.get_child_count())
			if npcs < 3 or world.get_child_count() < 40:
				push_error("SMOKE FAIL Irondale shop should have patio + staff, npcs=%d children=%d" % [npcs, world.get_child_count()])
				return 1
			var player := node.get_node("Player") as Node3D
			if player.position.z > -1.5:
				push_error("SMOKE FAIL player should spawn outside the storefront door")
				return 1
			if abs(angle_difference(player.rotation.y, PI)) > 0.5:
				push_error("SMOKE FAIL player should face the storefront (yaw ≈ 180)")
				return 1
			if not await _smoke_explore_controls(node, player):
				return 1
			var hud := node.get_node_or_null("HUD/Root/FreshTip") as Label
			if hud == null or hud.text.to_lower().find("fresh batch") < 0:
				push_error("SMOKE FAIL Fresh Batch tip UI missing")
				return 1
			var rig := node.get_node_or_null("ReviewCameras")
			if rig == null:
				push_error("SMOKE FAIL ReviewCameras missing")
				return 1
			for shot_name in ["Entrance", "Counter", "Dining", "LeftCorner", "RightCorner", "SunshineCloseup", "PastryCase", "Exterior"]:
				var cam := rig.get_node_or_null(shot_name) as Camera3D
				if cam == null or cam.current:
					push_error("SMOKE FAIL review camera %s" % shot_name)
					return 1
			print("SMOKE review cameras=8")
			if not ResourceLoader.exists("res://assets/models/sunshine_logo_girl.glb"):
				push_error("SMOKE FAIL missing GLB stub res://assets/models/sunshine_logo_girl.glb")
				return 1
			GameSave.debug_unix = -1
		node.queue_free()
		await get_tree().process_frame
	print("SMOKE mock ad…")
	var result: Dictionary = await AdTipService.play_rewarded()
	print("SMOKE ad result=", result)
	if not result.get("ok", false) or GameSave.staff_tips < 1:
		push_error("SMOKE FAIL staff tip not credited")
		return 1
	print("SMOKE staff jar=", GameSave.staff_tips)
	print("SMOKE all features ok")
	return 0


func _smoke_explore_controls(explore: Node, player: Node3D) -> bool:
	var joy := explore.get_node_or_null("HUD/Root/Joy") as VirtualJoystick
	var pad := explore.get_node_or_null("HUD/Root/LookPad") as LookPad
	var look_left := explore.get_node_or_null("HUD/Root/LookPad/LookLeft") as BaseButton
	var look_right := explore.get_node_or_null("HUD/Root/LookPad/LookRight") as BaseButton
	var hint := explore.get_node_or_null("HUD/Root/Hint") as Label
	if joy == null or pad == null or look_left == null or look_right == null:
		push_error("SMOKE FAIL missing on-screen MOVE/LOOK controls")
		return false
	if hint == null or hint.text.to_lower().find("stick") < 0 or hint.text.to_lower().find("look") < 0:
		push_error("SMOKE FAIL HUD should document stick + look controls")
		return false
	if hint.text.to_lower().find("esc") < 0 and hint.text.to_lower().find("menu") < 0:
		push_error("SMOKE FAIL HUD should document Esc/Menu leave")
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	var plate := joy.size
	if plate.x < 8.0:
		plate = Vector2(240, 240)
	var click_at := Vector2(plate.x * 0.5, plate.y * 0.12)
	joy.apply_local_point(click_at)
	if joy.current_vector().y < 0.35:
		push_error("SMOKE FAIL clicking the top of the stick should walk forward, vec=%s" % str(joy.current_vector()))
		return false
	print("SMOKE joystick click-forward vec=", joy.current_vector())
	var body := player as PlayerExplorer
	body.joy_vector = Vector2(0, 1)
	var start := player.global_position
	for _i in 120:
		await get_tree().physics_frame
	var moved := player.global_position.distance_to(start)
	var toward_shop := player.global_position.z - start.z
	if moved < 0.25:
		push_error("SMOKE FAIL on-screen stick did not move the player (delta=%.3f)" % moved)
		return false
	if toward_shop < 0.1:
		push_error("SMOKE FAIL forward stick should walk toward the door (+Z), dz=%.3f" % toward_shop)
		return false
	if player.global_position.z < 0.35:
		push_error("SMOKE FAIL player should walk through the storefront into the shop, z=%.3f" % player.global_position.z)
		return false
	print("SMOKE joystick walked inside z=", player.global_position.z, " dist=", moved)
	body.joy_vector = Vector2.ZERO
	joy.debug_set_vector(Vector2.ZERO)
	var yaw0 := player.rotation.y
	look_left.button_down.emit()
	for _j in 24:
		await get_tree().process_frame
	look_left.button_up.emit()
	var yaw_delta := absf(angle_difference(player.rotation.y, yaw0))
	if yaw_delta < 0.06:
		push_error("SMOKE FAIL LOOK ◀ button did not yaw the camera (delta=%.4f)" % yaw_delta)
		return false
	print("SMOKE look-left yaw delta=", yaw_delta)
	pad.look_delta.emit(Vector2(30, 0))
	await get_tree().process_frame
	print("SMOKE explore on-screen MOVE + LOOK ok")
	return true


func _chicago_morning_unix() -> int:
	# 2026-04-15 15:30 UTC = 10:30 CDT (America/Chicago, DST).
	return int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 4, "day": 15, "hour": 15, "minute": 30, "second": 0
	}))


func _smoke_fresh_batch() -> bool:
	var morning := _chicago_morning_unix()
	var before_nine := int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 4, "day": 15, "hour": 13, "minute": 30, "second": 0
	}))
	var at_eleven := int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 4, "day": 15, "hour": 16, "minute": 0, "second": 0
	}))
	var winter_morning := int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 1, "day": 15, "hour": 16, "minute": 30, "second": 0
	}))
	GameSave.debug_unix = morning
	GameSave.fresh_batch_day = ""
	GameSave._roll_fresh_batch_day_if_needed()
	var chi: Dictionary = GameSave.chicago_datetime()
	print("SMOKE chicago morning dict=", chi, " active=", GameSave.is_fresh_batch_active())
	if int(chi.get("hour", -1)) != 10:
		push_error("SMOKE FAIL expected Chicago hour 10, got %s" % str(chi.get("hour")))
		return false
	if not GameSave.is_fresh_batch_active():
		push_error("SMOKE FAIL 10:30 America/Chicago should be Fresh Batch")
		return false
	var at_nine := int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 4, "day": 15, "hour": 14, "minute": 0, "second": 0
	}))
	GameSave.debug_unix = at_nine
	if int(GameSave.chicago_datetime().get("hour", -1)) != 9 or not GameSave.is_fresh_batch_active():
		push_error("SMOKE FAIL 9:00 Chicago should be Fresh Batch")
		return false
	GameSave.debug_unix = before_nine
	if GameSave.is_fresh_batch_active():
		push_error("SMOKE FAIL 8:30 Chicago must be outside Fresh Batch")
		return false
	GameSave.debug_unix = at_eleven
	if GameSave.is_fresh_batch_active():
		push_error("SMOKE FAIL 11:00 Chicago must be outside Fresh Batch")
		return false
	GameSave.debug_unix = winter_morning
	var winter: Dictionary = GameSave.chicago_datetime()
	print("SMOKE chicago winter morning hour=", winter.get("hour"))
	if int(winter.get("hour", -1)) != 10 or not GameSave.is_fresh_batch_active():
		push_error("SMOKE FAIL January 10:30 CST should be Fresh Batch")
		return false
	GameSave.debug_unix = morning
	GameSave.fresh_batch_bonus_used = 0
	GameSave.fresh_batch_day = GameSave.chicago_day_key()
	var finds0 := GameSave.finds_this_week
	for i in 3:
		var row: Dictionary = GameSave.record_explore_find()
		if not bool(row.get("bonus", false)) or int(row.get("stamp_delta", 0)) != 2:
			push_error("SMOKE FAIL expected 2× stamps on Fresh Batch find %d: %s" % [i + 1, str(row)])
			return false
	var fourth: Dictionary = GameSave.record_explore_find()
	if bool(fourth.get("bonus", false)) or int(fourth.get("stamp_delta", 0)) != 1:
		push_error("SMOKE FAIL 4th morning find should be 1 stamp: %s" % str(fourth))
		return false
	if GameSave.finds_this_week != finds0 + 4:
		push_error("SMOKE FAIL weekly finder board should count 1 find each, got %d" % GameSave.finds_this_week)
		return false
	GameSave.debug_unix = before_nine
	var off_hours: Dictionary = GameSave.record_explore_find()
	if bool(off_hours.get("bonus", false)) or int(off_hours.get("stamp_delta", 0)) != 1:
		push_error("SMOKE FAIL off-window find should be 1 stamp")
		return false
	GameSave.debug_unix = -1
	print("SMOKE Fresh Batch window + 2× stamps + weekly finds ok")
	return true


func _smoke_account_session() -> bool:
	if AccountClient.normalize_phone("(205) 555-0123") != "+12055550123":
		push_error("SMOKE FAIL US phone normalize")
		return false
	if AccountClient.normalize_phone("nope") != "":
		push_error("SMOKE FAIL junk phone must not normalize")
		return false
	AccountClient.logout()
	if AccountClient.is_logged_in() or AccountClient.display_name() != "":
		push_error("SMOKE FAIL logout must clear Square session")
		return false
	AccountClient.skip_as_guest()
	if not AccountClient.is_guest() or AccountClient.is_logged_in():
		push_error("SMOKE FAIL skip must be guest, not a Square customer")
		return false
	var ok := AccountClient.apply_square_payload({
		"ok": true,
		"created": false,
		"customer": {
			"id": "CUST_SMOKE",
			"phone": "+12055550123",
			"given_name": "Ada",
			"family_name": "Lovelace",
			"nickname": "",
			"display_name": "Ada Lovelace",
		},
		"orders": [{
			"id": "ORD_SMOKE",
			"name": "Nutella Croissant",
			"date": "2026-09-14",
			"total_cents": 600,
			"items": [{"name": "Nutella Croissant", "qty": 1}],
		}],
	})
	if not ok or not AccountClient.is_logged_in() or AccountClient.hello_line() != "Hi, Ada Lovelace":
		push_error("SMOKE FAIL Square payload should become a named session")
		return false
	if AccountClient.previous_orders().is_empty():
		push_error("SMOKE FAIL previous Square orders should persist")
		return false
	if AppConfig.account_phone_api().find("/order/api/account/phone") < 0:
		push_error("SMOKE FAIL account API must stay on bakery-drinks")
		return false
	print("SMOKE account phone + guest + Square session persist ok")
	return true


func _smoke_cart_tip() -> bool:
	var saved: Dictionary = OrderClient.cart.duplicate(true)
	OrderClient.cart = {"items": [], "pickup": "to-go", "name": "", "phone": "", "tip": {"type": "none"}}
	var ok := true
	if not OrderClient.is_checkout_tip_valid({"type": "none"}):
		push_error("SMOKE FAIL none tip payload should be valid")
		ok = false
	if str(OrderClient.checkout_payload().get("tip", {}).get("type", "")) != "none":
		push_error("SMOKE FAIL default checkout tip must be none")
		ok = false
	for percent in OrderClient.TIP_PERCENTS:
		OrderClient.set_tip_percent(percent)
		var payload: Dictionary = OrderClient.checkout_tip()
		if str(payload.get("type", "")) != "percent" or int(payload.get("percent", 0)) != percent:
			push_error("SMOKE FAIL percent %d payload %s" % [percent, str(payload)])
			ok = false
		if not OrderClient.is_checkout_tip_valid(payload):
			push_error("SMOKE FAIL percent %d should be valid" % percent)
			ok = false
	OrderClient.set_tip_percent(16)
	if OrderClient.is_checkout_tip_valid() or OrderClient.tip_error() == "":
		push_error("SMOKE FAIL percent 16 must be rejected")
		ok = false
	if OrderClient.is_checkout_tip_valid({"type": "custom", "cents": 100}):
		push_error("SMOKE FAIL custom cents key is rejected by bakery-drinks; use amount_cents")
		ok = false
	OrderClient.set_tip_custom_cents(100)
	var custom: Dictionary = OrderClient.checkout_tip()
	if str(custom.get("type", "")) != "custom" or int(custom.get("amount_cents", -1)) != 100:
		push_error("SMOKE FAIL custom amount_cents payload %s" % str(custom))
		ok = false
	if custom.has("cents") or not OrderClient.is_checkout_tip_valid(custom):
		push_error("SMOKE FAIL custom payload must use amount_cents only: %s" % str(custom))
		ok = false
	OrderClient.set_custom_tip_input("1.50")
	if int(OrderClient.checkout_tip().get("amount_cents", -1)) != 150:
		push_error("SMOKE FAIL $1.50 should be 150 cents")
		ok = false
	OrderClient.set_custom_tip_input("150c")
	if int(OrderClient.checkout_tip().get("amount_cents", -1)) != 150:
		push_error("SMOKE FAIL 150c should be 150 cents")
		ok = false
	OrderClient.set_custom_tip_input("nope")
	if OrderClient.tip_error() == "":
		push_error("SMOKE FAIL nonsense custom tip must be rejected")
		ok = false
	OrderClient.set_custom_tip_input("100.01")
	if OrderClient.tip_error().find("$100") < 0:
		push_error("SMOKE FAIL custom tip over $100 must be rejected")
		ok = false
	if OrderClient.percent_tip_cents(850, 15) != 128:
		push_error("SMOKE FAIL 15% of 850 cents should estimate 128 (bakery-drinks rounding)")
		ok = false
	OrderClient.set_tip_none()
	if str(OrderClient.checkout_payload()["tip"].get("type", "")) != "none":
		push_error("SMOKE FAIL reset to none failed")
		ok = false
	OrderClient.cart = saved
	if ok:
		print("SMOKE cart tip payloads none/percent/custom ok")
	return ok


func _count_texture_rects(root: Node) -> int:
	var n := 0
	if root is TextureRect and (root as TextureRect).texture != null:
		n += 1
	for child in root.get_children():
		n += _count_texture_rects(child)
	return n


func _find_button_text(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root
	for child in root.get_children():
		var found := _find_button_text(child, text)
		if found:
			return found
	return null


func _smoke_order_prices_and_total(order_node: Node) -> bool:
	var priced_n := 0
	var pastry_priced := 0
	var pick: Dictionary = {}
	for drink in OrderClient.drinks():
		if not drink is Dictionary:
			continue
		if OrderClient.has_square_price(drink) and int(drink.get("price_cents", 0)) > 0:
			priced_n += 1
			if str(drink.get("category", "")) == "pastry":
				pastry_priced += 1
				if pick.is_empty() or str(pick.get("category", "")) != "pastry":
					pick = drink
			elif pick.is_empty():
				pick = drink
	print("SMOKE order priced=", priced_n, " pastry_priced=", pastry_priced, " total=", OrderClient.drinks().size())
	if priced_n < 20 or pastry_priced < 5:
		push_error("SMOKE FAIL Square food + drink rows must show prices, priced=%d pastry=%d" % [priced_n, pastry_priced])
		return false
	if pick.is_empty():
		push_error("SMOKE FAIL no Square-priced item to add")
		return false
	var saved: Dictionary = OrderClient.cart.duplicate(true)
	OrderClient.clear_cart()
	OrderClient.set_tip_none()
	OrderClient.add_cart_item(str(pick.get("id", "")), {}, 1)
	var due := OrderClient.cart_subtotal_cents()
	if OrderClient.cart_count() != 1 or due < 1:
		push_error("SMOKE FAIL adding a priced item must update cart count + dollars, count=%d cents=%d" % [OrderClient.cart_count(), due])
		OrderClient.cart = saved
		return false
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	await get_tree().process_frame
	var summary := order_node.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	if summary == null:
		push_error("SMOKE FAIL cart summary label missing")
		OrderClient.cart = saved
		return false
	var text := summary.text
	print("SMOKE cart bar after add: ", text, " item=", pick.get("name"), " cents=", due)
	if text.find("0 items") >= 0 or text.find("$0.00") >= 0 or text.find("$") < 0:
		push_error("SMOKE FAIL sticky cart must show item count + dollar total after add: %s" % text)
		OrderClient.cart = saved
		return false
	if text.find(OrderClient.money(due)) < 0:
		push_error("SMOKE FAIL sticky total should include %s, got %s" % [OrderClient.money(due), text])
		OrderClient.cart = saved
		return false
	OrderClient.cart = saved
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	print("SMOKE order list prices + sticky cart total ok")
	return true


func _smoke_order_cart_tip_ui(order_node: Node) -> bool:
	var drink: Dictionary = OrderClient.drinks()[0]
	var saved: Dictionary = OrderClient.cart.duplicate(true)
	OrderClient.clear_cart()
	OrderClient.set_tip_none()
	OrderClient.add_cart_item(str(drink.get("id", "")), {}, 1)
	if order_node.has_method("_set_tab"):
		order_node.call("_set_tab", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	for label in ["15%", "18%", "20%", "Custom", "No tip"]:
		if _find_button_text(order_node, label) == null:
			push_error("SMOKE FAIL cart missing tip button " + label)
			OrderClient.cart = saved
			return false
	var fifteen := _find_button_text(order_node, "15%")
	fifteen.pressed.emit()
	await get_tree().process_frame
	var payload: Dictionary = OrderClient.checkout_payload().get("tip", {})
	if str(payload.get("type", "")) != "percent" or int(payload.get("percent", 0)) != 15:
		push_error("SMOKE FAIL cart 15% did not set checkout tip: %s" % str(payload))
		OrderClient.cart = saved
		return false
	var custom_btn := _find_button_text(order_node, "Custom")
	custom_btn.pressed.emit()
	await get_tree().process_frame
	OrderClient.set_custom_tip_input("2.00")
	payload = OrderClient.checkout_payload().get("tip", {})
	if str(payload.get("type", "")) != "custom" or int(payload.get("amount_cents", -1)) != 200:
		push_error("SMOKE FAIL cart custom tip payload %s" % str(payload))
		OrderClient.cart = saved
		return false
	var none_btn := _find_button_text(order_node, "No tip")
	none_btn.pressed.emit()
	await get_tree().process_frame
	payload = OrderClient.checkout_payload().get("tip", {})
	if str(payload.get("type", "")) != "none":
		push_error("SMOKE FAIL No tip did not reset payload: %s" % str(payload))
		OrderClient.cart = saved
		return false
	print("SMOKE order cart tip UI + checkout payload ok")
	OrderClient.cart = saved
	return true

