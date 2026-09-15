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
	if not await _smoke_live_customer_route():
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
			for n in ["Safe/ProfileCard/Pad/Col/FirstName", "Safe/ProfileCard/Pad/Col/LastName", "Safe/ProfileCard/Pad/Col/Email", "Safe/ProfileCard/Pad/Col/Save"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL login profile form missing " + n)
					return 1
			var photo := node.get_node_or_null("Storefront") as TextureRect
			if photo == null or photo.texture == null:
				push_error("SMOKE FAIL login should use the storefront photo")
				return 1
			if node.has_method("show_profile_form"):
				AccountClient.logout()
				AccountClient.apply_square_payload({
					"ok": true,
					"session_token": "sess_nameless_smoke",
					"customer": {
						"id": "CUST_NAMELESS",
						"phone": "+12564525192",
						"given_name": "",
						"family_name": "",
						"nickname": "",
						"display_name": "",
					},
				})
				if not AccountClient.needs_profile():
					push_error("SMOKE FAIL nameless Square customer should need the profile form")
					return 1
				node.call("show_profile_form")
				await get_tree().process_frame
				var pcard := node.get_node_or_null("Safe/ProfileCard") as Control
				var phone_card := node.get_node_or_null("Safe/Card") as Control
				if pcard == null or not pcard.visible or (phone_card != null and phone_card.visible):
					push_error("SMOKE FAIL nameless customer should see the profile form, not the phone card")
					return 1
				print("SMOKE login profile form for nameless Square customer")
				AccountClient.apply_square_payload({
					"ok": true,
					"session_token": "sess_smoke_token",
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
						"items": [
							{"name": "Nutella Croissant", "qty": 1},
							{
								"name": "Biscoff Coffee",
								"qty": 1,
								"price_cents": 425,
								"modifiers": [
									{"name": "Oat milk", "price_cents": 75},
									"50%",
								],
								"detail": "Oat milk · 50%",
							},
						],
					}],
				})
			print("SMOKE login phone + skip + storefront photo")
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/VBox/OrderButton", "Safe/VBox/PreviousOrdersButton", "Safe/VBox/TipButton", "Safe/VBox/ExploreButton", "Storefront"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					return 1
			print("SMOKE main menu 4 buttons present")
			if node.get_node_or_null("Safe/VBox/Footer/Gear") != null or node.get_node_or_null("Settings") != null:
				push_error("SMOKE FAIL Settings must be removed from the customer main menu")
				return 1
			if _find_button_text(node, "Settings") != null:
				push_error("SMOKE FAIL Settings button must not appear on the main menu")
				return 1
			print("SMOKE main menu has no Settings")
			if node.get_node_or_null("OrdersSheet") == null:
				push_error("SMOKE FAIL Previous orders sheet missing")
				return 1
			var store := node.get_node("Storefront") as TextureRect
			if store.texture == null:
				push_error("SMOKE FAIL main menu storefront photo missing")
				return 1
			var order_btn := node.get_node("Safe/VBox/OrderButton") as Button
			var sb := order_btn.get_theme_stylebox("normal") as StyleBoxFlat
			if sb == null or sb.bg_color.r < 0.32 or sb.bg_color.g > 0.35:
				push_error("SMOKE FAIL ORDER button should use wine bakery style, got %s" % str(sb.bg_color if sb else sb))
				return 1
			print("SMOKE main menu wine button ", sb.bg_color)
			if node.has_method("_refresh_account_ui"):
				node.call("_refresh_account_ui")
			await get_tree().process_frame
			var greet := node.get_node_or_null("Safe/VBox/Greeting") as Label
			if greet == null or greet.text.find("Hi,") < 0:
				push_error("SMOKE FAIL logged-in home should greet by Square name, got %s" % (greet.text if greet else "?"))
				return 1
			var prev_btn := node.get_node("Safe/VBox/PreviousOrdersButton") as Button
			if prev_btn == null or not prev_btn.visible:
				push_error("SMOKE FAIL PREVIOUS ORDERS must stay on the lawn menu")
				return 1
			prev_btn.pressed.emit()
			await get_tree().process_frame
			var sheet := node.get_node_or_null("OrdersSheet") as Control
			if sheet == null or not sheet.visible:
				push_error("SMOKE FAIL Previous orders sheet should open when signed in")
				return 1
			if not _label_contains(sheet, "Nutella Croissant"):
				push_error("SMOKE FAIL signed-in Previous orders should list Square tickets")
				return 1
			if not _label_contains(sheet, "Oat milk"):
				push_error("SMOKE FAIL Previous orders line items should show modifiers")
				return 1
			if not _label_contains(sheet, "$0.75"):
				push_error("SMOKE FAIL Previous orders should show Square modifier prices when sent")
				return 1
			if not _label_contains(sheet, "$4.25"):
				push_error("SMOKE FAIL Previous orders should show Square line totals when sent")
				return 1
			if _label_contains(sheet, "No extras"):
				push_error("SMOKE FAIL history rows missing a modifiers field must not claim No extras")
				return 1
			if not _label_contains(sheet, "Extras not listed"):
				push_error("SMOKE FAIL stripped Square extras should say they were not listed")
				return 1
			if _count_texture_rects(sheet) < 2:
				push_error("SMOKE FAIL Previous orders lines should show Square photos or the no-photo tile")
				return 1
			print("SMOKE main menu greeting ", greet.text, " previous orders sheet open")
			AccountClient.logout()
			if node.has_method("_refresh_account_ui"):
				node.call("_refresh_account_ui")
			prev_btn.pressed.emit()
			await get_tree().process_frame
			if not sheet.visible:
				push_error("SMOKE FAIL guest Previous orders button must still open a prompt")
				return 1
			if not _label_contains(sheet, "Sign in"):
				push_error("SMOKE FAIL guest Previous orders should prompt phone login")
				return 1
			print("SMOKE guest Previous orders prompts sign-in")
		if path.ends_with("order.tscn"):
			var t0 := Time.get_ticks_msec()
			var drinks_ready := OrderClient.drinks().size()
			var busy := node.get_node_or_null("Safe/VBox/Busy") as Label
			var busy_on_open := busy.visible if busy else false
			print("SMOKE order first paint drinks=", drinks_ready, " busy=", busy_on_open, " msec=", Time.get_ticks_msec() - t0)
			if drinks_ready > 0 and busy_on_open:
				push_error("SMOKE FAIL cached Square menu should not show Loading on Order open")
				return 1
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
			if not _smoke_menu_cache():
				return 1
			if not await _smoke_photo_cache():
				return 1
			if not await _smoke_square_optional_mods(node):
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
			for _wait in 20:
				await get_tree().process_frame
			var world := node.get_node("World")
			var shop := world.get_node_or_null("ChatGPTStorefront")
			if shop == null:
				push_error("SMOKE FAIL Explore should instance the outdoor eating patio GLB as ChatGPTStorefront")
				return 1
			var glb_meshes := 0
			var stack: Array = [shop]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				if n is MeshInstance3D:
					glb_meshes += 1
				for child in n.get_children():
					stack.append(child)
			print("SMOKE explore world children=", world.get_child_count(), " glb_meshes=", glb_meshes)
			if glb_meshes < 50:
				push_error("SMOKE FAIL outdoor eating patio GLB looks empty, meshes=%d" % glb_meshes)
				return 1
			var grass := _named_mesh(shop, "Grass_Base")
			if grass == null:
				push_error("SMOKE FAIL patio missing Grass_Base")
				return 1
			var grass_box: AABB = grass.global_transform * grass.get_aabb()
			print("SMOKE grass aabb=", grass_box)
			if grass_box.size.x < 80.0 or grass_box.size.z < 70.0:
				push_error("SMOKE FAIL grass/land should be ~90×80 m, size=%s" % str(grass_box.size))
				return 1
			var logo := _named_mesh(shop, "Logo_Hero")
			if logo == null:
				logo = _named_mesh(shop, "LogoWall")
			if logo == null:
				push_error("SMOKE FAIL patio missing Logo_Hero / LogoWall")
				return 1
			if not _mesh_has_albedo_texture(_named_mesh(shop, "Logo_Hero")):
				push_error("SMOKE FAIL Sunshine logo should keep the embedded albedo texture")
				return 1
			if world.get_child_count() < 8:
				push_error("SMOKE FAIL explore world too empty")
				return 1
			var pickups := 0
			var lot_pickups := 0
			var extra_in := 0
			var extra_out := 0
			for child in world.get_children():
				if child is CollectiblePickup:
					pickups += 1
					var on_lot: bool = child.position.z > -10.0 and child.position.z < 22.0
					if on_lot:
						lot_pickups += 1
					if child.is_fresh_batch:
						if child.position.z > -5.0:
							extra_in += 1
						else:
							extra_out += 1
			print("SMOKE explore pickups=", pickups, " lot=", lot_pickups, " fresh_near=", extra_in, " fresh_out=", extra_out)
			if pickups < 3 or pickups > 6 or lot_pickups < 3:
				push_error("SMOKE FAIL MVP expects 3 cube pastries on the patio lawn, got pickups=%d lot=%d" % [pickups, lot_pickups])
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
			if npcs < 8 or world.get_child_count() < 12:
				push_error("SMOKE FAIL patio should have guests + staff, npcs=%d children=%d" % [npcs, world.get_child_count()])
				return 1
			await get_tree().process_frame
			await get_tree().physics_frame
			var floating := 0
			var empty_hands := 0
			for child in world.get_children():
				if not child.is_in_group("village_npc"):
					continue
				if child.global_position.y < -0.08 or child.global_position.y > 0.22:
					floating += 1
				var snacks := 0
				for n in child.find_children("Held_*", "", true, false):
					snacks += 1
				if snacks < 1:
					empty_hands += 1
			var snacks := 0
			for n in get_tree().get_nodes_in_group("held_snack"):
				snacks += 1
			print("SMOKE npc plant floating=", floating, " empty_hands=", empty_hands, " held=", snacks)
			if floating > 0:
				push_error("SMOKE FAIL NPCs should stand on the ground, floating=%d" % floating)
				return 1
			if empty_hands > 0 or snacks < npcs:
				push_error("SMOKE FAIL every NPC should hold a pastry or drink, empty=%d held=%d npcs=%d" % [empty_hands, snacks, npcs])
				return 1
			var sun := world.get_node_or_null("LogoSun") as Node3D
			if sun == null or sun.global_position.y < 8.0:
				push_error("SMOKE FAIL logo sun missing or not in the sky")
				return 1
			if sun.find_child("LogoDisc", true, false) == null:
				push_error("SMOKE FAIL logo sun should show the bakery logo disc")
				return 1
			print("SMOKE logo sun pos=", sun.global_position)
			var props := 0
			for child in world.get_children():
				if child.is_in_group("menu_prop"):
					props += 1
			print("SMOKE menu props=", props)
			if props != 10:
				push_error("SMOKE FAIL patio should display Ronald's 10 top-seller props, props=%d" % props)
				return 1
			if not ResourceLoader.exists("res://assets/models/sunshine_outdoor_eating.glb"):
				push_error("SMOKE FAIL missing patio res://assets/models/sunshine_outdoor_eating.glb")
				return 1
			if ResourceLoader.exists("res://assets/models/chatgpt_shop_grass.glb"):
				var world_script := FileAccess.get_file_as_string("res://scripts/explore/bakery_world.gd")
				if world_script.find("chatgpt_shop_grass.glb") >= 0:
					push_error("SMOKE FAIL chatgpt_shop_grass must not be the Explore world")
					return 1
			var player := node.get_node("Player") as Node3D
			if player.position.z < 8.0 or player.position.z > 16.0:
				push_error("SMOKE FAIL player should spawn on the south lawn facing the logo, z=%.3f" % player.position.z)
				return 1
			if absf(player.position.x) > 2.0:
				push_error("SMOKE FAIL player should spawn on the logo axis (x ≈ 0), x=%.3f" % player.position.x)
				return 1
			if abs(angle_difference(player.rotation.y, 0.0)) > 0.5:
				push_error("SMOKE FAIL player should face the Sunshine logo wall (yaw ≈ 0, looking −Z)")
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
	var hint := explore.get_node_or_null("HUD/Root/Hint") as Label
	var menu := explore.get_node_or_null("HUD/Root/Top/Back") as Button
	if joy == null or pad == null:
		push_error("SMOKE FAIL missing on-screen move stick or look drag pad")
		return false
	if explore.get_node_or_null("HUD/Root/LookPad/LookLeft") != null or explore.get_node_or_null("HUD/Root/LookPad/LookRight") != null:
		push_error("SMOKE FAIL LOOK arrow buttons must be removed")
		return false
	if explore.get_node_or_null("HUD/Root/LookPad/LookHint") != null:
		push_error("SMOKE FAIL LOOK coaching label must be removed")
		return false
	var look_plate := explore.get_node_or_null("HUD/Root/LookPad/Plate") as CanvasItem
	if look_plate != null and look_plate.visible:
		push_error("SMOKE FAIL look pad must not show a bottom-right colored square")
		return false
	if hint != null and hint.visible and hint.text.strip_edges() != "":
		push_error("SMOKE FAIL Explore HUD must not coach MOVE/LOOK/drag")
		return false
	if menu == null or menu.text != "Menu":
		push_error("SMOKE FAIL Explore needs a small Menu button without a tutorial line")
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
	var toward_logo := start.z - player.global_position.z
	if moved < 0.25:
		push_error("SMOKE FAIL on-screen stick did not move the player (delta=%.3f)" % moved)
		return false
	if toward_logo < 0.1:
		push_error("SMOKE FAIL forward stick should walk toward the logo wall (−Z), dz=%.3f" % toward_logo)
		return false
	if player.global_position.y < 0.25:
		push_error("SMOKE FAIL player fell off the grass, y=%.3f" % player.global_position.y)
		return false
	if absf(player.global_position.x) > 44.0 or absf(player.global_position.z) > 39.0:
		push_error("SMOKE FAIL player walked off the 90×80 grass, pos=%s" % str(player.global_position))
		return false
	if player.global_position.z < -7.2:
		push_error("SMOKE FAIL player clipped through the logo wall, z=%.3f" % player.global_position.z)
		return false
	print("SMOKE joystick walked toward logo without falling z=", player.global_position.z, " dist=", moved)
	body.joy_vector = Vector2.ZERO
	joy.debug_set_vector(Vector2.ZERO)
	var yaw0 := player.rotation.y
	pad.look_delta.emit(Vector2(80, 0))
	await get_tree().process_frame
	var yaw_delta := absf(angle_difference(player.rotation.y, yaw0))
	if yaw_delta < 0.06:
		push_error("SMOKE FAIL look drag pad did not yaw the camera (delta=%.4f)" % yaw_delta)
		return false
	print("SMOKE look-drag yaw delta=", yaw_delta)
	print("SMOKE explore silent MOVE stick + drag LOOK ok")
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
		"session_token": "sess_smoke_token",
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
			"items": [
				{"name": "Nutella Croissant", "qty": 1},
				{
					"name": "Biscoff Coffee",
					"qty": 1,
					"modifiers": [
						{"name": "Oat milk", "price_cents": 75},
						"50%",
					],
					"detail": "Oat milk · 50%",
				},
			],
		}],
	})
	if not ok or not AccountClient.is_logged_in() or AccountClient.hello_line() != "Hi, Ada":
		push_error("SMOKE FAIL Square payload should become a named session")
		return false
	if AccountClient.needs_profile():
		push_error("SMOKE FAIL named Square customer should skip the profile form")
		return false
	if AccountClient.profile_error("Ada", "Lovelace", "ada@example.com") != "":
		push_error("SMOKE FAIL valid profile fields should pass")
		return false
	if AccountClient.profile_error("", "Lovelace", "ada@example.com") == "":
		push_error("SMOKE FAIL first name is required")
		return false
	if AccountClient.profile_error("Ada", "Lovelace", "not-an-email") == "":
		push_error("SMOKE FAIL email should be required")
		return false
	if AppConfig.account_profile_api().find("/order/api/account/profile") < 0:
		push_error("SMOKE FAIL profile API must stay on bakery-drinks /order/api/account/profile")
		return false
	if AppConfig.customer_profile_api().find("/order/api/customer/profile") < 0:
		push_error("SMOKE FAIL profile alias must stay on /order/api/customer/profile")
		return false
	if not AccountClient.has_session_token() or GameSave.session_token != "sess_smoke_token":
		push_error("SMOKE FAIL session_token from POST login must persist")
		return false
	if AccountClient.previous_orders().is_empty():
		push_error("SMOKE FAIL previous Square orders should persist")
		return false
	var hist: Dictionary = AccountClient.previous_orders()[0]
	var hist_items: Array = hist.get("items", [])
	if hist_items.size() < 2:
		push_error("SMOKE FAIL smoke ticket should have croissant + coffee lines")
		return false
	var croissant_line := OrderClient.visible_mod_line(hist_items[0])
	if croissant_line == "No extras":
		push_error("SMOKE FAIL history line without a modifiers field must not claim No extras")
		return false
	var coffee_line := OrderClient.visible_mod_line(hist_items[1])
	if coffee_line.find("Oat milk") < 0 or coffee_line.find("$0.75") < 0:
		push_error("SMOKE FAIL history dict modifiers should keep name + price, got %s" % coffee_line)
		return false
	if AppConfig.account_phone_api().find("/order/api/account/phone") < 0:
		push_error("SMOKE FAIL account API must stay on bakery-drinks")
		return false
	if AppConfig.customer_api().find("/order/api/customer") < 0:
		push_error("SMOKE FAIL customer API must stay on bakery-drinks")
		return false
	if AppConfig.customer_orders_api().find("/order/api/orders") < 0:
		push_error("SMOKE FAIL orders API must stay on bakery-drinks")
		return false
	if not _smoke_drinks_orders_payload():
		return false
	print("SMOKE account phone + guest + Square session persist ok")
	return true


func _smoke_drinks_orders_payload() -> bool:
	var thin_hist: Array = OrderClient.hydrate_history_orders([{
		"id": "ORD_DRINKS_THIN",
		"name": "Vietnamese Coffee",
		"items": [{"name": "Vietnamese Coffee", "qty": 1}],
	}])
	var thin_items: Array = thin_hist[0].get("items", [])
	if thin_items.is_empty():
		push_error("SMOKE FAIL thin drinks hydrate lost items")
		return false
	var thin_item: Dictionary = thin_items[0]
	if OrderClient.visible_mod_line(thin_item) == "No extras":
		push_error("SMOKE FAIL bakery-drinks {name,qty} tickets must not claim No extras")
		return false
	if OrderClient.visible_mod_line(thin_item).find("Extras not listed") < 0:
		push_error("SMOKE FAIL thin drinks items should say extras were not listed")
		return false
	var extras_hist: Array = OrderClient.hydrate_history_orders([{
		"id": "ORD_EXTRAS_ALIAS",
		"items": [{"name": "Coffee", "qty": 1, "extras": [{"name": "50%"}]}],
	}])
	var extras_items: Array = extras_hist[0].get("items", [])
	if extras_items.is_empty() or OrderClient.visible_mod_line(extras_items[0]).find("50%") < 0:
		push_error("SMOKE FAIL extras alias should hydrate into modifiers")
		return false
	var enrich: Array = OrderClient.hydrate_history_orders([{
		"id": "ORD_DRINKS_ENRICH",
		"items": [{"name": "Vietnamese Coffee", "qty": 1}],
		"_line_items": [{
			"name": "Vietnamese Coffee",
			"quantity": "1",
			"catalog_object_id": "CAT_VIET",
			"modifiers": [{
				"uid": "mod1",
				"name": "Oat milk",
				"catalog_object_id": "MOD_OAT",
				"base_price_money": {"amount": 75, "currency": "USD"},
			}],
			"total_money": {"amount": 575, "currency": "USD"},
		}],
	}])
	var rich_items: Array = enrich[0].get("items", [])
	if rich_items.is_empty():
		push_error("SMOKE FAIL drinks _line_items hydrate lost items")
		return false
	var rich: Dictionary = rich_items[0]
	var rich_line := OrderClient.visible_mod_line(rich)
	if rich_line.find("Oat milk") < 0 or rich_line.find("$0.75") < 0:
		push_error("SMOKE FAIL drinks _line_items Square modifiers should hydrate, got %s" % rich_line)
		return false
	if str(rich.get("catalog_object_id", "")) != "CAT_VIET":
		push_error("SMOKE FAIL _line_items catalog_object_id should survive hydrate")
		return false
	if int(rich.get("qty", 0)) != 1:
		push_error("SMOKE FAIL Square quantity should become qty")
		return false
	if int(rich.get("price_cents", 0)) != 575:
		push_error("SMOKE FAIL Square total_money should become price_cents, got %s" % str(rich.get("price_cents")))
		return false
	var live_hist: Array = OrderClient.hydrate_history_orders([{
		"id": "4UmgQDvoVqJX8zUl1JiFFmgcpmBZY",
		"order_number": "13",
		"name": "Vietnamese Coffee",
		"date": "2026-09-09",
		"total_cents": 812,
		"items": [{
			"name": "Vietnamese Coffee",
			"qty": 1,
			"catalog_object_id": "22BNXC6JLRBJ23FWCL5VJTZF",
			"catalog_variation_id": "22BNXC6JLRBJ23FWCL5VJTZF",
			"variation_name": "Regular",
			"price_cents": 687,
			"base_price_cents": 550,
			"modifiers": [
				{
					"name": "25%",
					"quantity": 1,
					"price_cents": 0,
					"base_price_cents": 0,
					"catalog_object_id": "JIPDPPAWJ44RAOYWBPXIEZJQ",
				},
				{
					"name": "Lactose Free",
					"quantity": 1,
					"price_cents": 75,
					"base_price_cents": 75,
					"catalog_object_id": "XBNRTBOKPSZQZFM42OVN7DZN",
				},
			],
		}],
	}])
	var live_items: Array = live_hist[0].get("items", [])
	if live_items.is_empty():
		push_error("SMOKE FAIL live drinks items hydrate lost QR-13 lines")
		return false
	var live_item: Dictionary = live_items[0]
	var live_line := OrderClient.visible_mod_line(live_item)
	if live_line.find("25%") < 0 or live_line.find("Lactose Free") < 0 or live_line.find("$0.75") < 0:
		push_error("SMOKE FAIL live drinks modifiers should show 25% + Lactose Free $0.75, got %s" % live_line)
		return false
	if int(live_item.get("price_cents", 0)) != 687:
		push_error("SMOKE FAIL line price_cents must win over base_price_cents, got %s" % str(live_item.get("price_cents")))
		return false
	var empty_mods := OrderClient.visible_mod_line({
		"name": "Vietnamese Coffee",
		"qty": 1,
		"catalog_object_id": "22BNXC6JLRBJ23FWCL5VJTZF",
		"modifiers": [],
	})
	if empty_mods != "No extras":
		push_error("SMOKE FAIL drinks modifiers:[] means no extras, got %s" % empty_mods)
		return false
	var viet_photo := OrderClient.history_item_photo_url({"name": "Vietnamese Coffee", "qty": 1})
	if not viet_photo.begins_with("https://"):
		push_error("SMOKE FAIL Vietnamese Coffee history photo should be Square HTTPS, got %s" % viet_photo)
		return false
	var missing_photo := OrderClient.history_item_photo_url({"name": "Totally Fake Square Item 999"})
	if missing_photo.find("no_photo") < 0:
		push_error("SMOKE FAIL unknown history item must use the no-photo tile, got %s" % missing_photo)
		return false
	print("SMOKE drinks GET /orders hydrate thin vs _line_items extras ok")
	return true


func _smoke_menu_cache() -> bool:
	if not OrderClient.has_menu() or OrderClient.catalog_source() != "square":
		push_error("SMOKE FAIL cannot cache a non-Square menu")
		return false
	var n := OrderClient.drinks().size()
	OrderClient.remember_successful_menu()
	OrderClient.menu = {}
	if OrderClient.has_menu():
		push_error("SMOKE FAIL clearing menu should empty drinks")
		return false
	if not OrderClient.restore_cached_menu() or OrderClient.drinks().size() != n:
		push_error("SMOKE FAIL last Square menu should restore from cache")
		return false
	if OrderClient.catalog_source() != "square":
		push_error("SMOKE FAIL restored menu must stay Square-sourced")
		return false
	print("SMOKE last Square menu cache restore ok n=", n)
	var fp := OrderClient.menu_fingerprint()
	if fp == "" or fp.find("#") < 0:
		push_error("SMOKE FAIL menu fingerprint should include item count")
		return false
	var t0 := Time.get_ticks_usec()
	if not OrderClient.restore_cached_menu():
		push_error("SMOKE FAIL second cache restore should stay instant")
		return false
	var dt := Time.get_ticks_usec() - t0
	print("SMOKE cache restore usec=", dt, " fp_len=", fp.length())
	return true


func _smoke_photo_cache() -> bool:
	var url := "https://items-images-production.s3.amazonaws.com/perf-cache-test"
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color(0.8, 0.2, 0.2))
	var tex := ImageTexture.create_from_image(img)
	OrderClient.photo_cache[url] = tex
	var t0 := Time.get_ticks_usec()
	var hit := OrderClient.cached_photo(url)
	var dt := Time.get_ticks_usec() - t0
	if hit != tex:
		push_error("SMOKE FAIL photo memory cache should return the same texture")
		return false
	print("SMOKE photo memory cache hit usec=", dt)
	if dt > 5000:
		push_error("SMOKE FAIL cached photo should be instant, usec=%d" % dt)
		return false
	var coalesced: Texture2D = await OrderClient.fetch_photo(url)
	if coalesced != tex:
		push_error("SMOKE FAIL fetch_photo should reuse the memory cache")
		return false
	print("SMOKE photo fetch_photo memory reuse ok")
	return true


func _smoke_live_customer_route() -> bool:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(AppConfig.account_api())
	if err != OK:
		push_error("SMOKE FAIL could not start live account GET")
		http.queue_free()
		return false
	var completed: Array = await http.request_completed
	http.queue_free()
	var code: int = completed[1]
	var text := (completed[3] as PackedByteArray).get_string_from_utf8()
	print("SMOKE live account GET (no session) HTTP ", code, " body=", text.substr(0, 120))
	if code == 200:
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and parsed.get("customer") is Dictionary:
			push_error("SMOKE FAIL unauthenticated GET /order/api/account dumped a customer")
			return false
	print("SMOKE live login is POST /order/api/account/phone (no phone GET, no OTP)")
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


func _button_contains(root: Node, needle: String) -> bool:
	if root is Button and (root as Button).text.find(needle) >= 0:
		return true
	for child in root.get_children():
		if _button_contains(child, needle):
			return true
	return false


func _find_button_text(root: Node, text: String) -> Button:
	if root is Button:
		var shown := (root as Button).text
		if shown == text or shown == ("✓  " + text):
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


func _smoke_square_optional_mods(order_node: Node) -> bool:
	var croissant: Dictionary = {}
	var coffee: Dictionary = {}
	var tote: Dictionary = {}
	var food_with_groups := 0
	for row in OrderClient.drinks():
		if not row is Dictionary:
			continue
		var nm := str(row.get("name", ""))
		var groups: Array = row.get("groups", []) if row.get("groups") is Array else []
		if nm == "Nutella Croissant":
			croissant = row
		if nm == "Coffee":
			coffee = row
		if nm == "Tote Bag":
			tote = row
		var cat := str(row.get("category", ""))
		if cat in ["pastry", "savory", "bread", "more"] and groups.size() > 0:
			food_with_groups += 1
	if croissant.is_empty() or not croissant.get("groups") is Array or (croissant.get("groups") as Array).size() < 1:
		push_error("SMOKE FAIL Nutella Croissant must list Square Reheat extras, got %s" % str(croissant.get("groups", [])))
		return false
	var coffee_opts := 0
	var coffee_groups := 0
	if coffee.get("groups") is Array:
		coffee_groups = (coffee.get("groups") as Array).size()
		for g in coffee.get("groups", []):
			if g is Dictionary and g.get("options") is Array:
				coffee_opts += (g.get("options") as Array).size()
	if coffee_groups < 5 or coffee_opts < 20:
		push_error("SMOKE FAIL Coffee must list all Square extra groups/options, groups=%d options=%d" % [coffee_groups, coffee_opts])
		return false
	if food_with_groups < 10:
		push_error("SMOKE FAIL Square food items should keep optional modifier groups, got %d" % food_with_groups)
		return false
	if tote.is_empty() or not tote.get("groups") is Array or (tote.get("groups") as Array).size() < 2:
		push_error("SMOKE FAIL Tote Bag must list Designs + Color from Square")
		return false
	var stripped := OrderClient.visible_mod_line({"name": "Vietnamese Coffee", "qty": 1})
	if stripped == "No extras":
		push_error("SMOKE FAIL live history tickets that omit modifiers must not claim No extras")
		return false
	var priced := OrderClient.visible_mod_line({
		"name": "Coffee",
		"qty": 1,
		"modifiers": [{"name": "Oat milk", "price_cents": 75}],
	})
	if priced.find("Oat milk") < 0 or priced.find("$0.75") < 0:
		push_error("SMOKE FAIL history dict modifiers should show name + Square price, got %s" % priced)
		return false
	print("SMOKE catalog extras croissant=", (croissant.get("groups") as Array).size(), " coffee_opts=", coffee_opts, " food_groups=", food_with_groups)
	if order_node.has_method("_open_detail"):
		order_node.call("_open_detail", croissant)
		await order_node.get_tree().process_frame
		await order_node.get_tree().process_frame
		if not _label_contains(order_node, "Reheat"):
			push_error("SMOKE FAIL croissant detail should list Square Reheat options")
			return false
		if not _label_contains(order_node, "optional"):
			push_error("SMOKE FAIL croissant Reheat group is optional and should be labeled")
			return false
		print("SMOKE croissant detail shows optional Reheat")
		order_node.call("_open_detail", tote)
		await order_node.get_tree().process_frame
		await order_node.get_tree().process_frame
		if not _label_contains(order_node, "Designs") or not _label_contains(order_node, "Color"):
			push_error("SMOKE FAIL Tote Bag detail should list both Square modifier groups")
			return false
		print("SMOKE tote detail shows Designs + Color")
		order_node.set("_detail_drink", {})
		order_node.set("_cart_edit_idx", -1)
		order_node.set("_tab", 0)
		if order_node.has_method("_render"):
			order_node.call("_render")
		await order_node.get_tree().process_frame
	return true


func _smoke_order_cart_tip_ui(order_node: Node) -> bool:
	var drink: Dictionary = {}
	for row in OrderClient.drinks():
		if row is Dictionary and row.get("groups") is Array and (row.get("groups") as Array).size() > 0:
			drink = row
			break
	if drink.is_empty():
		drink = OrderClient.drinks()[0]
	var saved: Dictionary = OrderClient.cart.duplicate(true)
	OrderClient.clear_cart()
	OrderClient.set_tip_none()
	var mods: Dictionary = OrderClient.example_checkout_mods(drink)
	var extras := OrderClient.available_mod_preview(drink)
	if extras != "":
		order_node.set("_detail_drink", {})
		order_node.set("_cart_edit_idx", -1)
		order_node.set("_tab", 0)
		if order_node.has_method("_render"):
			order_node.call("_render")
		await get_tree().process_frame
		await get_tree().process_frame
		if not _label_contains(order_node, "Extras:"):
			push_error("SMOKE FAIL menu rows should preview Square extra groups")
			OrderClient.cart = saved
			return false
		print("SMOKE menu extras preview ", extras)
	if drink.get("groups") is Array and (drink.get("groups") as Array).size() > 0 and order_node.has_method("_open_detail"):
		order_node.call("_open_detail", drink, mods, 1)
		await get_tree().process_frame
		await get_tree().process_frame
		if not _label_contains(order_node, "Selected:"):
			push_error("SMOKE FAIL item detail should list selected extras")
			OrderClient.cart = saved
			return false
		if not _button_contains(order_node, "✓"):
			push_error("SMOKE FAIL selected modifier chips should show a check")
			OrderClient.cart = saved
			return false
		print("SMOKE item detail selected mods")
		order_node.set("_detail_drink", {})
		order_node.set("_cart_edit_idx", -1)
	OrderClient.add_cart_item(str(drink.get("id", "")), mods, 1)
	var summary := OrderClient.line_mod_summary(OrderClient.cart["items"][0])
	if drink.get("groups") is Array and (drink.get("groups") as Array).size() > 0 and summary.strip_edges() == "":
		push_error("SMOKE FAIL cart line should list selected mods for %s" % str(drink.get("name")))
		OrderClient.cart = saved
		return false
	if order_node.has_method("_set_tab"):
		order_node.call("_set_tab", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	if summary != "" and not _label_contains(order_node, summary.split(" · ")[0]):
		push_error("SMOKE FAIL cart UI missing modifier text %s" % summary)
		OrderClient.cart = saved
		return false
	print("SMOKE cart mods ", drink.get("name"), " → ", summary)
	var bar := order_node.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	if bar == null or (summary != "" and bar.text.find(str(drink.get("name", ""))) < 0):
		push_error("SMOKE FAIL sticky cart bar should list line items")
		OrderClient.cart = saved
		return false
	if summary != "" and bar.text.find(summary.split(" · ")[0]) < 0:
		push_error("SMOKE FAIL sticky cart bar missing modifier text %s" % summary)
		OrderClient.cart = saved
		return false
	print("SMOKE sticky cart bar shows mods")
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
	if order_node.has_method("_render"):
		order_node.set("_detail_drink", {})
		order_node.set("_cart_edit_idx", -1)
		order_node.set("_tab", 2)
		order_node.set("_my_status", {
			"open_orders": [{
				"name": "Ada",
				"status": "making",
				"order_number": "42",
				"ahead": 1,
				"items": [{
					"name": str(drink.get("name", "Coffee")),
					"qty": 1,
					"modifiers": ["Oat milk"],
					"detail": "Oat milk",
				}],
			}],
		})
		order_node.call("_render")
		await get_tree().process_frame
		await get_tree().process_frame
		if not _label_contains(order_node, "Oat milk"):
			push_error("SMOKE FAIL Status tab should list line-item modifiers")
			OrderClient.cart = saved
			return false
		print("SMOKE status tab shows mods")
		order_node.set("_tab", 1)
		order_node.call("_render")
		await get_tree().process_frame
	if summary != "":
		var hist := {
			"items": [{
				"name": str(drink.get("name", "")),
				"qty": 1,
				"modifiers": [summary.split(" · ")[0]],
				"detail": summary,
			}],
		}
		OrderClient.clear_cart()
		var added := await AccountClient.reorder(hist)
		if added < 1:
			push_error("SMOKE FAIL order-again should re-add the drink")
			OrderClient.cart = saved
			return false
		var again := OrderClient.visible_mod_line(OrderClient.cart["items"][0])
		if again == "No extras":
			push_error("SMOKE FAIL order-again should keep modifier labels")
			OrderClient.cart = saved
			return false
		print("SMOKE order-again preselect mods → ", again)
		var id_hist := {
			"id": "ORD_RETRIEVE",
			"retrieved": true,
			"items": [
				{
					"name": "Not A Real Menu Name",
					"qty": 1,
					"catalog_object_id": str(drink.get("id", "")),
					"id": str(drink.get("id", "")),
					"modifiers": [
						{"name": "Oat milk", "price_cents": 75},
					],
				},
				{
					"name": str(drink.get("name", "")),
					"qty": 2,
					"modifiers": [{"name": "50%"}],
				},
			],
		}
		OrderClient.clear_cart()
		var sold := drink.duplicate(true)
		sold["sold_out"] = true
		# Force-add even if the live row later flips sold_out.
		added = await AccountClient.reorder(id_hist)
		if added != 2:
			push_error("SMOKE FAIL order-again should add every RetrieveOrder line, got %d" % added)
			OrderClient.cart = saved
			return false
		if OrderClient.cart_count() < 3:
			push_error("SMOKE FAIL order-again qty should include both retrieved lines")
			OrderClient.cart = saved
			return false
		print("SMOKE order-again retrieve ids + all lines → ", added, " cart=", OrderClient.cart_count())
	OrderClient.cart = saved
	return true


func _label_contains(root: Node, needle: String) -> bool:
	if needle.strip_edges() == "":
		return true
	if root is Label and (root as Label).text.find(needle) >= 0:
		return true
	for child in root.get_children():
		if _label_contains(child, needle):
			return true
	return false


func _named_mesh(root: Node, mesh_name: String) -> MeshInstance3D:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and str(n.name) == mesh_name:
			return n as MeshInstance3D
		for child in n.get_children():
			stack.append(child)
	return null


func _mesh_has_albedo_texture(mi: MeshInstance3D) -> bool:
	if mi == null or mi.mesh == null:
		return false
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(i)
		if mat == null:
			mat = mi.mesh.surface_get_material(i)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture != null:
			return true
	return false

