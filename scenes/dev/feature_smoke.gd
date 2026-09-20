extends Node
## Run: godot --headless --path . res://scenes/dev/feature_smoke.tscn

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")
const CosContractsLib := preload("res://scripts/contracts/cos_contracts.gd")

func _ready() -> void:
	var code := await _run()
	await get_tree().process_frame
	get_tree().quit(code)


func _run() -> int:
	print("SMOKE autoloads AppConfig url=", AppConfig.order_url())
	if not await _smoke_explore_origin():
		return 1
	if not _smoke_cart_tip():
		return 1
	if not _smoke_fresh_batch():
		return 1
	if not _smoke_account_session():
		return 1
	if not _smoke_cos_contracts():
		return 1
	if not await _smoke_live_customer_route():
		return 1
	for path in [
		"res://scenes/account/login.tscn",
		"res://scenes/main_menu.tscn",
		"res://scenes/tip_ad/tip_ad.tscn",
		"res://scenes/order/order.tscn",
		"res://scenes/explore/explore_3d.tscn",
		"res://scenes/explore/customize.tscn",
	]:
		print("SMOKE load ", path)
		if path.ends_with("customize.tscn"):
			AccountClient.apply_square_payload({
				"ok": true,
				"session_token": "sess_customize_smoke",
				"customer": {
					"id": "CUST_LOOK",
					"phone": "+12055550111",
					"given_name": "Ada",
					"family_name": "Lovelace",
				},
			})
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
						"status": "ready",
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
		if path.ends_with("customize.tscn"):
			if node.get_node_or_null("Safe/Card/Pad/Col/Save") == null:
				push_error("SMOKE FAIL customize missing Save")
				return 1
			if node.get_node_or_null("Safe/Card/Pad/Col/Username") == null:
				push_error("SMOKE FAIL customize missing Username")
				return 1
			print("SMOKE customize look screen")
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/VBox/OrderButton", "Safe/VBox/PreviousOrdersButton", "Safe/VBox/TipButton", "Safe/VBox/ExploreButton", "Safe/VBox/CustomizeButton", "Storefront"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					return 1
			print("SMOKE main menu buttons + customize present")
			if BakeryTheme.has_loading_cover(node) or AppConfig.get_node_or_null("MenuLoadingCover") != null:
				push_error("SMOKE FAIL ORDER tap must not use a full-screen Loading menu cover")
				return 1
			var banner := BakeryTheme.make_photo_banner()
			var loading := BakeryTheme.photo_loading_node(banner)
			if loading == null or not loading.visible:
				push_error("SMOKE FAIL menu photo well should show a loading placeholder")
				banner.free()
				return 1
			if not _label_contains(loading, "Loading photo"):
				push_error("SMOKE FAIL photo placeholder should say Loading photo")
				banner.free()
				return 1
			banner.free()
			print("SMOKE ORDER has no full-screen cover; photo wells have loading placeholders")
			if not node.has_method("_open_order"):
				push_error("SMOKE FAIL main menu should open Order")
				return 1
			var lawn_title := node.get_node("Safe/VBox/Title") as Label
			if lawn_title and lawn_title.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL main menu subtitle type should be ≥24, got %d" % lawn_title.get_theme_font_size("font_size"))
				return 1
			var lawn_order := node.get_node("Safe/VBox/OrderButton") as Button
			if lawn_order and lawn_order.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL ORDER label type should be ≥24, got %d" % lawn_order.get_theme_font_size("font_size"))
				return 1
			var lawn_prev := node.get_node("Safe/VBox/PreviousOrdersButton") as Button
			if lawn_prev and lawn_prev.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL PREVIOUS ORDERS type should be ≥24, got %d" % lawn_prev.get_theme_font_size("font_size"))
				return 1
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
			var hero_size := store.texture.get_size()
			if hero_size.y <= hero_size.x:
				push_error("SMOKE FAIL main menu storefront should be the portrait 2231 lawn photo, got %s" % hero_size)
				return 1
			print("SMOKE main menu storefront portrait ", hero_size)
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
			var hist_title := sheet.get_node_or_null("Safe/Card/Pad/Col/Title") as Label
			if hist_title and hist_title.get_theme_font_size("font_size") < 32:
				push_error("SMOKE FAIL Previous Orders title should be larger for older customers")
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
			print("SMOKE order first paint drinks=", drinks_ready, " cover=", BakeryTheme.has_loading_cover(node), " msec=", Time.get_ticks_msec() - t0)
			if BakeryTheme.has_loading_cover(node) or AppConfig.get_node_or_null("MenuLoadingCover") != null:
				push_error("SMOKE FAIL Order screen must not show a full-screen Loading menu cover")
				return 1
			var waited := 0.0
			while waited < 8.0 and not _smoke_has_named_drink("Biscoff Coffee"):
				await get_tree().process_frame
				waited += get_process_delta_time()
			print("SMOKE drinks-primary msec=", Time.get_ticks_msec() - t0, " count=", OrderClient.drinks().size())
			if not _smoke_has_named_drink("Biscoff Coffee") or not _smoke_has_named_drink("Vietnamese Coffee"):
				push_error("SMOKE FAIL Order catalog must show live bakery-drinks items with prices (Biscoff Coffee, Vietnamese Coffee)")
				return 1
			if _label_contains(node, "Couldn’t load the menu") or _label_contains(node, "taking too long"):
				push_error("SMOKE FAIL Order showed catalog timeout/error despite drinks API")
				return 1
			var content := node.get_node_or_null("Safe/VBox/Body/Content")
			var photos := 0
			var wait_cards := 0
			while wait_cards < 45:
				content = node.get_node_or_null("Safe/VBox/Body/Content")
				photos = _count_texture_rects(content) if content else 0
				if photos >= 3:
					break
				await get_tree().process_frame
				wait_cards += 1
			if photos >= 3:
				await get_tree().process_frame
			if BakeryTheme.has_loading_cover(node) or AppConfig.get_node_or_null("MenuLoadingCover") != null:
				push_error("SMOKE FAIL full-screen Loading menu cover must never appear on Order")
				return 1
			if OrderClient.has_menu() and photos < 3:
				push_error("SMOKE FAIL menu cards should appear without a full-screen cover")
				return 1
			print("SMOKE order drinks=", OrderClient.drinks().size(), " source=", OrderClient.catalog_source(), " pay=", OrderClient.pay_mode(), " fallback=", OrderClient.used_fallback, " photos=", photos)
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
			var pastry_wait := 0.0
			while pastry_wait < 8.0 and pastry_n < 1:
				pastry_n = 0
				cats = {}
				for drink in OrderClient.drinks():
					if not drink is Dictionary:
						continue
					var cat := str(drink.get("category", ""))
					cats[cat] = true
					if cat == "pastry":
						pastry_n += 1
				if pastry_n >= 1:
					break
				await get_tree().process_frame
				pastry_wait += get_process_delta_time()
			print("SMOKE after store-enrich pastry=", pastry_n, " cats=", cats.keys(), " total=", OrderClient.drinks().size())
			if pastry_n < 1:
				print("SMOKE note: Square Online bakery-case not in yet; drinks API menu is enough")
			if not _smoke_menu_cache():
				return 1
			if not await _smoke_photo_cache():
				return 1
			if not await _smoke_square_optional_mods(node):
				return 1
			if not _smoke_readable_order_type(node):
				return 1
			if not await _smoke_menu_scroll_and_loading(node):
				return 1
			if not await _smoke_clear_cart(node):
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
			photos = 0
			content = node.get_node_or_null("Safe/VBox/Body/Content")
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
			var authored_bag := _named_mesh(shop, "Beanbag00")
			if authored_bag != null and authored_bag.visible:
				push_error("SMOKE FAIL faceted Beanbag00 should be hidden for cute-pack stand-ins")
				return 1
			var cute_bags := 0
			for child in world.get_children():
				if child.is_in_group("cute_beanbag"):
					cute_bags += 1
			print("SMOKE cute beanbags=", cute_bags)
			if cute_bags < 3:
				push_error("SMOKE FAIL patio should plant 3 rounded beanbags, got %d" % cute_bags)
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
			if not await _smoke_cookie_toss(node, player):
				return 1
			var hud := node.get_node_or_null("HUD/Root/FreshTip") as Label
			if hud == null:
				push_error("SMOKE FAIL Fresh Batch tip UI missing")
				return 1
			var hud_status := node.get_node_or_null("HUD/Root/Status") as Label
			if GameSave.is_fresh_batch_active():
				if hud_status == null or hud_status.text.to_lower().find("fresh") < 0:
					push_error("SMOKE FAIL live Fresh Batch should sit on the status line")
					return 1
			elif hud.text.to_lower().find("fresh batch") < 0:
				push_error("SMOKE FAIL off-hours Fresh Batch tip UI missing")
				return 1
			var plate_src := FileAccess.get_file_as_string("res://scripts/explore/avatar_body.gd")
			if plate_src.find('ends_with(" Guest")') < 0:
				push_error("SMOKE FAIL generic Guest nameplates should hide unless close")
				return 1
			if hud.visible and hud.text.length() > 36:
				push_error("SMOKE FAIL Fresh Batch tip is too wide for the board, text=%s" % hud.text)
				return 1
			if hud.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL Explore Fresh Batch banner type should be ≥24, got %d" % hud.get_theme_font_size("font_size"))
				return 1
			if hud_status == null or hud_status.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL Explore HUD status type should be ≥24")
				return 1
			var toss_lbl := node.get_node_or_null("HUD/Root/TossCookie") as Button
			if toss_lbl == null or toss_lbl.get_theme_font_size("font_size") < 24:
				push_error("SMOKE FAIL Toss cookie type should be ≥24")
				return 1
			var explore_hud := node.get_node_or_null("HUD")
			if explore_hud and explore_hud.has_method("push_chat"):
				explore_hud.call("push_chat", "Ada", "hello patio")
				await get_tree().process_frame
				await get_tree().process_frame
				var mute := node.get_node_or_null("HUD/Root/ChatDock/Col/ModRow/MuteLast")
				var block := node.get_node_or_null("HUD/Root/ChatDock/Col/ModRow/BlockLast")
				var report := node.get_node_or_null("HUD/Root/ChatDock/Col/ModRow/ReportLast")
				if mute == null or block == null or report == null:
					push_error("SMOKE FAIL remote chat should offer Mute, Block, and Report")
					return 1
				if mute is Control and (mute as Control).size.y > 40.0:
					push_error("SMOKE FAIL chat Mute control should be compact, h=%.0f" % (mute as Control).size.y)
					return 1
				if node.get_node_or_null("HUD/Root/ChatRow") != null:
					push_error("SMOKE FAIL legacy centered ChatRow must not sit on the stick")
					return 1
				var dock := node.get_node_or_null("HUD/Root/ChatDock") as Control
				var joy_ctl := node.get_node_or_null("HUD/Root/Joy") as Control
				var chat_row := node.get_node_or_null("HUD/Root/ChatDock/Col/ChatRow") as Control
				var log := node.get_node_or_null("HUD/Root/ChatDock/Col/ChatLog") as ScrollContainer
				if dock == null or joy_ctl == null or chat_row == null or log == null:
					push_error("SMOKE FAIL compact ChatDock / stick layout missing")
					return 1
				if dock.get_global_rect().intersects(joy_ctl.get_global_rect()):
					push_error("SMOKE FAIL chat dock overlaps the left walking stick")
					return 1
				if chat_row.get_global_rect().intersects(joy_ctl.get_global_rect()):
					push_error("SMOKE FAIL chat input overlaps the left walking stick")
					return 1
				if mute is Control and (mute as Control).get_global_rect().intersects(joy_ctl.get_global_rect()):
					push_error("SMOKE FAIL chat Mute overlaps the left walking stick")
					return 1
				print("SMOKE chat overlay clear of stick; Mute+Block+Report compact")
			var explore_script := FileAccess.get_file_as_string("res://scripts/explore/explore_controller.gd")
			if explore_script.find("NoticeService") >= 0:
				push_error("SMOKE FAIL Explore enter must not toast Fresh Batch (HUD banner is enough)")
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
	print("SMOKE mock-or-admob ad…")
	print("SMOKE ad describe=", AdTipService.describe())
	if OS.get_name() != "Android" and AdTipService.current_mode() != "mock":
		push_error("SMOKE FAIL editor/desktop should use mock ads, got %s" % AdTipService.current_mode())
		return 1
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
	if player.global_position.y < -0.08 or player.global_position.y > 0.22:
		push_error("SMOKE FAIL player feet should stand on the grass, y=%.3f" % player.global_position.y)
		return false
	if absf(player.global_position.x) > 88.0 or absf(player.global_position.z) > 78.0:
		push_error("SMOKE FAIL player walked off the expanded lawn, pos=%s" % str(player.global_position))
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


func _smoke_cookie_toss(explore: Node, player: Node3D) -> bool:
	var toss := explore.get_node_or_null("HUD/Root/TossCookie") as Button
	if toss == null or toss.text.to_lower().find("cookie") < 0:
		push_error("SMOKE FAIL Explore needs a Toss cookie thumb button")
		return false
	if toss.custom_minimum_size.x < 160.0 or toss.custom_minimum_size.y < 72.0:
		push_error("SMOKE FAIL Toss cookie hit target is too small, size=%s" % str(toss.custom_minimum_size))
		return false
	var look_plate := explore.get_node_or_null("HUD/Root/LookPad/Plate") as CanvasItem
	if look_plate != null and look_plate.visible:
		push_error("SMOKE FAIL cookie toss must not bring back the look-pad square")
		return false
	if not ResourceLoader.exists("res://assets/models/menu_props/prop_chocolate_chip_cookie.glb"):
		push_error("SMOKE FAIL missing chocolate chip cookie patio prop")
		return false
	var sample: Node3D = MenuPropsLib.instantiate_cookie()
	if sample == null:
		push_error("SMOKE FAIL instantiate_cookie should use the chocolate chip cookie mesh")
		return false
	sample.free()
	var body := player as PlayerExplorer
	if body == null or not body.has_method("toss_cookie"):
		push_error("SMOKE FAIL player toss_cookie missing")
		return false
	if not body.toss_cookie():
		push_error("SMOKE FAIL toss_cookie should spawn a cookie")
		return false
	var flying: Array = []
	for _wait in 24:
		await get_tree().process_frame
		await get_tree().physics_frame
		flying = get_tree().get_nodes_in_group("cookie_projectile")
		if not flying.is_empty():
			break
	if flying.is_empty():
		push_error("SMOKE FAIL tossing should spawn a cookie projectile")
		return false
	var shot: Node = flying[0]
	if shot.find_child("Cookie", true, false) == null:
		push_error("SMOKE FAIL projectile should carry the cookie mesh")
		return false
	print("SMOKE cookie projectile spawned n=", flying.size())
	if shot.has_method("burst_at"):
		shot.call("burst_at", (shot as Node3D).global_position)
		await get_tree().process_frame
		await get_tree().process_frame
		if shot.get_child_count() < 4:
			push_error("SMOKE FAIL cookie impact should drop crumbs, kids=%d" % shot.get_child_count())
			return false
		print("SMOKE cookie crumbs kids=", shot.get_child_count())
	if not ExploreNet.has_method("send_impact") or not ExploreNet.has_signal("impact_received"):
		push_error("SMOKE FAIL cookie impact should broadcast through ExploreNet")
		return false
	ExploreNet.send_impact((shot as Node3D).global_position, str(shot.get("proj_id")))
	print("SMOKE cookie impact queued")
	var npc: Node3D = null
	for child in explore.get_node("World").get_children():
		if child.is_in_group("village_npc") and child is Node3D:
			npc = child as Node3D
			break
	if npc == null:
		push_error("SMOKE FAIL no NPC to knock back")
		return false
	var start := npc.global_position
	npc.call("apply_knockback", start + Vector3(0, 0, 1.0), 9.0)
	for _i in 24:
		await get_tree().process_frame
	var moved := npc.global_position.distance_to(Vector3(start.x, npc.global_position.y, start.z))
	if moved < 0.25:
		push_error("SMOKE FAIL cookie knockback should shove the NPC, moved=%.3f" % moved)
		return false
	if npc.global_position.y < -0.08 or npc.global_position.y > 0.22:
		push_error("SMOKE FAIL NPC left the ground after knockback y=%.3f" % npc.global_position.y)
		return false
	for _j in 40:
		await get_tree().process_frame
	if npc.global_position.y < -0.08 or npc.global_position.y > 0.22:
		push_error("SMOKE FAIL NPC should recover on the grass y=%.3f" % npc.global_position.y)
		return false
	print("SMOKE cookie knockback moved=", moved, " y=", npc.global_position.y)
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


func _smoke_cos_contracts() -> bool:
	var recipe: Dictionary = CosContractsLib.sanitize_avatar({"skin": "NOPE", "hat": "sun"})
	if str(recipe.get("skin", "")) != "peach" or str(recipe.get("hat", "")) != "sun":
		push_error("SMOKE FAIL avatar recipe should clamp to approved IDs")
		return false
	if str(CosContractsLib.username_error("ab")) == "":
		push_error("SMOKE FAIL short username should fail")
		return false
	if str(CosContractsLib.username_error("sunshine")) == "":
		push_error("SMOKE FAIL reserved username")
		return false
	if str(CosContractsLib.display_name_error("ada@bakery.com")) == "":
		push_error("SMOKE FAIL email display name")
		return false
	var saved_menu: Dictionary = OrderClient.menu.duplicate(true)
	var saved_cart: Dictionary = OrderClient.cart.duplicate(true)
	var tracked := {
		"id": "VAR_OK",
		"name": "Cookie",
		"inventory": {"tracking_enabled": true, "available_to_sell": 3},
	}
	var untracked := {
		"id": "VAR_FREE",
		"name": "Water",
		"inventory": {"tracking_enabled": false, "available_to_sell": 9},
	}
	var sold := {"id": "VAR_SOLD", "name": "Sold", "sold_out": true, "inventory": {"tracking_enabled": true, "available_to_sell": 4}}
	if not OrderClient.is_purchase_eligible(tracked) or OrderClient.purchasable_quantity(tracked) != 3:
		push_error("SMOKE FAIL tracked ATS should be eligible")
		return false
	if OrderClient.is_purchase_eligible(untracked) or OrderClient.is_purchase_eligible(sold):
		push_error("SMOKE FAIL untracked/sold_out must be ineligible")
		return false
	OrderClient.menu = {"source": "square", "drinks": [tracked, sold, {"id": "VAR_FLAG", "name": "Biscoff Coffee", "sold_out": false}]}
	if OrderClient.shop_drinks().size() != 2:
		push_error("SMOKE FAIL shop_drinks should hide sold-out and keep flag-available drinks")
		OrderClient.menu = saved_menu
		OrderClient.cart = saved_cart
		return false
	OrderClient.cart = {"items": [{"id": "OLD", "qty": 2}], "pickup": "to-go"}
	var result: Dictionary = OrderClient.replace_cart_from_order({
		"items": [
			{"catalog_object_id": "VAR_OK", "name": "Cookie", "qty": 5},
			{"catalog_object_id": "VAR_SOLD", "name": "Sold", "qty": 1},
		],
	}, 1, true)
	if not result.get("ok", false) or (result.get("items", []) as Array).size() != 1:
		push_error("SMOKE FAIL replace cart mixed availability")
		OrderClient.menu = saved_menu
		OrderClient.cart = saved_cart
		return false
	if int(result.get("items", [{}])[0].get("qty", 0)) != 3:
		push_error("SMOKE FAIL replace should cap qty to ATS")
		OrderClient.menu = saved_menu
		OrderClient.cart = saved_cart
		return false
	if str(OrderClient.cart.get("items", [{}])[0].get("id", "")) == "OLD":
		push_error("SMOKE FAIL replace must drop the old cart")
		OrderClient.menu = saved_menu
		OrderClient.cart = saved_cart
		return false
	var failed: Dictionary = OrderClient.replace_cart_from_order({"items": [{"id": "VAR_OK", "qty": 1}]}, 2, false)
	if failed.get("ok", false) or str(OrderClient.cart.get("items", [{}])[0].get("id", "")) != "VAR_OK":
		push_error("SMOKE FAIL failed validation must preserve the current cart")
		OrderClient.menu = saved_menu
		OrderClient.cart = saved_cart
		return false
	OrderClient.menu = saved_menu
	OrderClient.cart = saved_cart
	print("SMOKE COS contracts + cart replace")
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
			"status": "ready",
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
	if not _smoke_paid_orders():
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


func _smoke_has_named_drink(name: String) -> bool:
	var needle := name.strip_edges().to_lower()
	for drink in OrderClient.drinks():
		if not drink is Dictionary:
			continue
		if str(drink.get("name", "")).strip_edges().to_lower() != needle:
			continue
		if int(drink.get("price_cents", 0)) <= 0:
			return false
		return true
	return false


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


func _smoke_paid_orders() -> bool:
	var unpaid_making := {
		"id": "OPEN_UNPAID",
		"status": "making",
		"name": "Vietnamese Coffee + 1 more",
		"total_cents": 1889,
		"items": [{"name": "Vietnamese Coffee", "qty": 1}],
	}
	var canceled := {
		"id": "CXL",
		"status": "canceled",
		"state": "CANCELED",
		"name": "Coffee",
		"items": [{"name": "Coffee", "qty": 1}],
	}
	var draft := {
		"id": "DR",
		"state": "DRAFT",
		"name": "Coffee",
		"items": [{"name": "Coffee", "qty": 1}],
	}
	var ready := {
		"id": "PAID_READY",
		"status": "ready",
		"name": "Vietnamese Coffee",
		"total_cents": 812,
		"items": [{"name": "Vietnamese Coffee", "qty": 1, "modifiers": [{"name": "25%"}]}],
	}
	var paid_making := {
		"id": "PAID_MAKING",
		"status": "making",
		"paid": true,
		"tender_count": 1,
		"net_amount_due_cents": 0,
		"name": "Coffee",
		"items": [{"name": "Coffee", "qty": 1}],
	}
	if OrderClient.is_paid_history_order(unpaid_making):
		push_error("SMOKE FAIL open-unpaid making tickets must not count as paid")
		return false
	if OrderClient.is_paid_history_order(canceled) or OrderClient.is_paid_history_order(draft):
		push_error("SMOKE FAIL canceled/draft tickets must not count as paid")
		return false
	if not OrderClient.is_paid_history_order(ready):
		push_error("SMOKE FAIL ready Square tickets are paid")
		return false
	if not OrderClient.is_paid_history_order(paid_making):
		push_error("SMOKE FAIL making + tenders/due 0 is paid")
		return false
	if OrderClient.is_status_queue_order(unpaid_making) or OrderClient.is_status_queue_order(ready):
		push_error("SMOKE FAIL Status must not list unpaid or ready tickets")
		return false
	if not OrderClient.is_status_queue_order(paid_making):
		push_error("SMOKE FAIL Status should keep paid making tickets")
		return false
	var status_kept: Array = OrderClient.status_queue_orders([unpaid_making, canceled, draft, ready, paid_making])
	if status_kept.size() != 1 or str(status_kept[0].get("id", "")) != "PAID_MAKING":
		push_error("SMOKE FAIL Status paid+making filter kept %d" % status_kept.size())
		return false
	if OrderClient.app_order_number({"order_number": "13", "id": "sq0id_ABCDEFGH1234WXYZ"}) != "13":
		push_error("SMOKE FAIL app order should prefer the short ticket number")
		return false
	if OrderClient.app_order_number({"id": "sq0id_ABCDEFGH1234WXYZ"}) != "WXYZ":
		push_error("SMOKE FAIL app order should not show a Square UUID")
		return false
	if OrderClient.app_order_label({"order_number": "42"}) != "app order 42":
		push_error("SMOKE FAIL Status should label tickets as app order xxx")
		return false
	if OrderClient.ahead_line(1).find("1 ahead") < 0 or OrderClient.ahead_line(1).find("in front") < 0:
		push_error("SMOKE FAIL ahead copy should say N ahead / in front")
		return false
	var kept: Array = OrderClient.paid_history_orders([unpaid_making, canceled, draft, ready, paid_making])
	if kept.size() != 2:
		push_error("SMOKE FAIL paid filter kept %d tickets, expected 2" % kept.size())
		return false
	var ok := AccountClient.apply_square_payload({
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
		"orders": [unpaid_making, canceled, draft, ready, paid_making],
	})
	if not ok:
		push_error("SMOKE FAIL paid-filter payload should still sign in")
		return false
	var shown: Array = AccountClient.previous_orders()
	if shown.size() != 2:
		push_error("SMOKE FAIL Previous Orders should list only paid tickets, got %d" % shown.size())
		return false
	for row in shown:
		if not row is Dictionary:
			continue
		var oid := str(row.get("id", ""))
		if oid in ["OPEN_UNPAID", "CXL", "DR"]:
			push_error("SMOKE FAIL unpaid ticket leaked into Previous Orders: " + oid)
			return false
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
			"status": "ready",
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
	print("SMOKE previous orders paid-only filter ok")
	return true


func _smoke_explore_origin() -> bool:
	var origin := AppConfig.explore_http_origin()
	var ws := AppConfig.explore_ws_url()
	var tick := AppConfig.explore_tick_api()
	print("SMOKE explore origin=", origin, " ws=", ws, " tick=", tick)
	if origin.find("sunshine-explore-k6uuoen7wa-ue.a.run.app") < 0:
		push_error("SMOKE FAIL explore origin must be live sunshine-explore, got " + origin)
		return false
	if origin.find("trycloudflare") >= 0 or ws.find("trycloudflare") >= 0 or tick.find("trycloudflare") >= 0:
		push_error("SMOKE FAIL explore client still pointed at trycloudflare")
		return false
	if ws != "wss://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/ws":
		push_error("SMOKE FAIL explore WSS URL wrong: " + ws)
		return false
	if tick != "https://sunshine-explore-k6uuoen7wa-ue.a.run.app/explore/tick":
		push_error("SMOKE FAIL explore tick URL wrong: " + tick)
		return false
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(origin + "/explore/health")
	if err != OK:
		push_error("SMOKE FAIL could not start patio health GET")
		http.queue_free()
		return false
	var completed: Array = await http.request_completed
	http.queue_free()
	var code: int = completed[1]
	var text := (completed[3] as PackedByteArray).get_string_from_utf8()
	print("SMOKE live patio health HTTP ", code, " body=", text.substr(0, 180))
	if code != 200:
		push_error("SMOKE FAIL patio health HTTP %s" % code)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or bool(parsed.get("ok", false)) != true:
		push_error("SMOKE FAIL patio health not ok")
		return false
	if str(parsed.get("service", "")) != "sunshine-explore" or str(parsed.get("room", "")) != "patio":
		push_error("SMOKE FAIL patio health service/room")
		return false
	var ada: Dictionary = await _patio_tick({
		"protocol": 1,
		"player_id": "plr_smoke_ada",
		"display_name": "Ada",
		"x": 1.0,
		"y": 0.02,
		"z": 11.0,
	})
	var _bo: Dictionary = await _patio_tick({
		"protocol": 1,
		"player_id": "plr_smoke_bo",
		"display_name": "Bo",
		"x": -1.2,
		"y": 0.02,
		"z": 10.4,
	})
	var again: Dictionary = await _patio_tick({
		"protocol": 1,
		"net_id": str(ada.get("net_id", "")),
		"player_id": "plr_smoke_ada",
		"display_name": "Ada",
		"x": 1.1,
		"y": 0.02,
		"z": 10.8,
	})
	var names: PackedStringArray = PackedStringArray()
	var rows: Variant = again.get("players", [])
	if rows is Array:
		for row in rows:
			if row is Dictionary:
				names.append(str(row.get("display_name", "")))
	print("SMOKE live patio names=", names)
	if names.find("Ada") < 0 or names.find("Bo") < 0:
		if int(ada.get("http_code", 0)) == 409 or int(_bo.get("http_code", 0)) == 409:
			print("SMOKE live patio is full; health already proved sunshine-explore")
		else:
			push_error("SMOKE FAIL live sunshine-explore did not show both tick clients")
			return false
	for nid in [str(ada.get("net_id", "")), str(_bo.get("net_id", ""))]:
		if nid != "":
			await _patio_leave(nid)
	print("SMOKE explore client hits live sunshine-explore (not trycloudflare)")
	return true


func _patio_tick(body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(
		AppConfig.explore_tick_api(),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		push_error("SMOKE FAIL patio tick request")
		http.queue_free()
		return {}
	var done: Array = await http.request_completed
	http.queue_free()
	var code := int(done[1])
	if code == 409:
		print("SMOKE patio tick HTTP 409 room full")
		return {"http_code": 409, "ok": false}
	if code < 200 or code >= 300:
		push_error("SMOKE FAIL patio tick HTTP %s" % code)
		return {}
	var parsed: Variant = JSON.parse_string((done[3] as PackedByteArray).get_string_from_utf8())
	if parsed is Dictionary:
		(parsed as Dictionary)["http_code"] = code
		return parsed
	return {}


func _patio_leave(net_id: String) -> void:
	if net_id == "":
		return
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	var err := http.request(
		AppConfig.explore_leave_api(),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify({"net_id": net_id, "leave": true})
	)
	if err != OK:
		http.queue_free()
		return
	await http.request_completed
	http.queue_free()
	print("SMOKE patio leave net_id=", net_id)


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
			if not OrderClient.is_purchase_eligible(drink):
				continue
			if pick.is_empty():
				pick = drink
			elif str(drink.get("category", "")) == "pastry" and str(pick.get("category", "")) != "pastry":
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
	if text.find("1 item") < 0 or text.find("$") >= 0 or text.find("\n") >= 0:
		push_error("SMOKE FAIL sticky cart should show item count only after add: %s" % text)
		OrderClient.cart = saved
		return false
	if text.find(str(pick.get("name", "___none___"))) >= 0:
		push_error("SMOKE FAIL sticky cart must not list item names: %s" % text)
		OrderClient.cart = saved
		return false
	OrderClient.cart = saved
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	print("SMOKE order list prices + sticky cart count ok")
	return true


func _smoke_readable_order_type(order_node: Node) -> bool:
	var theme := BakeryTheme.make()
	if theme.default_font_size < 26:
		push_error("SMOKE FAIL default theme type should be ≥26 for older customers, got %d" % theme.default_font_size)
		return false
	if BakeryTheme.SIZE_CAPTION < 24 or BakeryTheme.SIZE_BUTTON < 26 or BakeryTheme.SIZE_TOAST < 26:
		push_error("SMOKE FAIL theme scale still has leftover small type")
		return false
	var slot := BakeryTheme.make_photo_banner()
	var img := BakeryTheme.photo_rect(slot)
	if img == null or img.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		push_error("SMOKE FAIL menu photos should crop COVERED in a wide banner")
		slot.free()
		return false
	if BakeryTheme.PHOTO_CARD_H < 360 or abs(BakeryTheme.PHOTO_WIDTH_RATIO - 0.75) > 0.02:
		push_error("SMOKE FAIL Order/menu photos should fill ~75%% of the card, h=%d ratio=%.2f" % [BakeryTheme.PHOTO_CARD_H, BakeryTheme.PHOTO_WIDTH_RATIO])
		slot.free()
		return false
	if slot.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		push_error("SMOKE FAIL item photo banner should expand to card width")
		slot.free()
		return false
	var wrapped := BakeryTheme.wrap_photo(slot)
	if abs(slot.size_flags_stretch_ratio - 0.75) > 0.02 or wrapped.get_child_count() != 3:
		push_error("SMOKE FAIL browse photo wrap should be ~75%% with gutters, ratio=%.2f kids=%d" % [slot.size_flags_stretch_ratio, wrapped.get_child_count()])
		wrapped.free()
		return false
	wrapped.free()
	var thumb := BakeryTheme.make_photo_slot(BakeryTheme.PHOTO_LINE)
	if BakeryTheme.PHOTO_LINE != 96 or thumb.custom_minimum_size != Vector2(96, 96):
		push_error("SMOKE FAIL cart/history thumbs should be the older 96px squares, line=%d size=%s" % [BakeryTheme.PHOTO_LINE, str(thumb.custom_minimum_size)])
		thumb.free()
		return false
	if thumb.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
		push_error("SMOKE FAIL line-item thumbs must not stretch to card width")
		thumb.free()
		return false
	thumb.free()
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	var summary := order_node.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	if summary == null:
		push_error("SMOKE FAIL cart summary missing for type check")
		return false
	var cart_size := summary.get_theme_font_size("font_size")
	if cart_size < 26:
		push_error("SMOKE FAIL sticky cart type should be ≥26, got %d" % cart_size)
		return false
	var clear := order_node.get_node_or_null("Safe/VBox/CartBar/Row/ClearCart") as Button
	if clear and clear.get_theme_font_size("font_size") < 24:
		push_error("SMOKE FAIL Clear cart type should be ≥24, got %d" % clear.get_theme_font_size("font_size"))
		return false
	NoticeService.info("Type check toast.")
	var toast_n := 0
	for lab in NoticeService.find_children("*", "Label", true, false):
		if lab is Label and (lab as Label).get_theme_font_size("font_size") >= 24:
			toast_n += 1
	if toast_n < 1:
		push_error("SMOKE FAIL toast/notification copy should be ≥24")
		return false
	print("SMOKE readable type theme=", theme.default_font_size, " cart=", cart_size, " toast_labels=", toast_n)
	return true


func _smoke_menu_scroll_and_loading(order_node: Node) -> bool:
	var content := order_node.get_node_or_null("Safe/VBox/Body/Content") as VBoxContainer
	var body := order_node.get_node_or_null("Safe/VBox/Body") as ScrollContainer
	if content == null or body == null:
		push_error("SMOKE FAIL Order body/content missing for scroll check")
		return false
	if content.mouse_filter != Control.MOUSE_FILTER_PASS:
		push_error("SMOKE FAIL menu list must PASS pointer events so ScrollContainer can drag-scroll")
		return false
	var card: PanelContainer
	for child in content.get_children():
		if child is PanelContainer:
			card = child
			break
	if card == null:
		push_error("SMOKE FAIL no menu item card to check mouse_filter")
		return false
	if card.mouse_filter != Control.MOUSE_FILTER_PASS:
		push_error("SMOKE FAIL menu cards must PASS (not STOP) so dragging on a card scrolls, filter=%d" % card.mouse_filter)
		return false
	await order_node.get_tree().process_frame
	await order_node.get_tree().process_frame
	## Cards must PASS so Android drag-on-card reaches ScrollContainer.
	## Wheel hover is flaky on xvfb; prove overflow + PASS, then try wheel/_gui_input.
	var bar := body.get_v_scroll_bar()
	var overflow := 0.0
	if bar:
		overflow = float(bar.max_value)
	if overflow < 8.0 and content.size.y <= body.size.y + 4.0:
		push_error("SMOKE FAIL menu list should overflow so customers can scroll, content=%.0f body=%.0f" % [content.size.y, body.size.y])
		return false
	var before := body.scroll_vertical
	var start: Vector2 = card.get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = start
	wheel.global_position = start
	wheel.factor = 8.0
	order_node.get_viewport().push_input(wheel)
	await order_node.get_tree().process_frame
	await order_node.get_tree().process_frame
	var after := body.scroll_vertical
	if after <= before and body.has_method("_gui_input"):
		body.call("_gui_input", wheel)
		await order_node.get_tree().process_frame
		after = body.scroll_vertical
	if after <= before:
		print("SMOKE menu card PASS + overflow=", overflow, " wheel skipped on this display")
	else:
		print("SMOKE menu card PASS + scroll via card ", before, " → ", after, " touchscreen=", DisplayServer.is_touchscreen_available())
	if not order_node.has_method("_show_menu_loading") or not order_node.has_method("_show_menu_error"):
		push_error("SMOKE FAIL Order should expose loading/error menu placeholders")
		return false
	order_node.call("_show_menu_loading")
	await order_node.get_tree().process_frame
	if not _label_contains(content, "Loading menu"):
		push_error("SMOKE FAIL loading state should say Loading menu")
		order_node.call("_render")
		return false
	if _count_progress_bars(content) < 1:
		push_error("SMOKE FAIL loading state should show a progress bar")
		order_node.call("_render")
		return false
	print("SMOKE menu loading placeholder ok")
	order_node.call("_show_menu_error", "Square catalog unavailable.")
	await order_node.get_tree().process_frame
	if BakeryTheme.has_loading_cover(order_node) or AppConfig.get_node_or_null("MenuLoadingCover") != null:
		push_error("SMOKE FAIL error path must not raise a full-screen Loading menu cover")
		order_node.call("_render")
		return false
	if not _label_contains(content, "load the menu") or _find_button_text(order_node, "Retry Square") == null:
		push_error("SMOKE FAIL menu error should explain the failure and offer Retry Square")
		order_node.call("_render")
		return false
	print("SMOKE menu error + retry placeholder ok")
	order_node.set("_detail_drink", {})
	order_node.set("_tab", 0)
	order_node.call("_render")
	await order_node.get_tree().process_frame
	if BakeryTheme.has_loading_cover(order_node):
		push_error("SMOKE FAIL render path must not show a full-screen cover")
		return false
	if not await _smoke_photo_placeholder(order_node):
		return false
	return true


func _smoke_photo_placeholder(order_node: Node) -> bool:
	var banner := BakeryTheme.make_photo_banner(180)
	order_node.add_child(banner)
	var overlay := BakeryTheme.photo_loading_node(banner)
	if overlay == null or not overlay.visible or not _label_contains(overlay, "Loading photo"):
		push_error("SMOKE FAIL photo slot should start with a Loading photo placeholder")
		banner.queue_free()
		return false
	var fake_url := "https://items-images-production.s3.amazonaws.com/sunshines-smoke-missing.jpg"
	OrderClient.photo_cache.erase(fake_url)
	OrderClient._photo_failed.erase(fake_url)
	order_node.call("_bind_photo", banner, {"name": "Smoke", "photo": fake_url}, false)
	await order_node.get_tree().process_frame
	overlay = BakeryTheme.photo_loading_node(banner)
	if overlay and overlay.visible:
		print("SMOKE photo loading overlay visible while image downloads")
	var waited := 0.0
	while waited < 12.0:
		var img := BakeryTheme.photo_rect(banner)
		overlay = BakeryTheme.photo_loading_node(banner)
		if img and img.texture != null and overlay and not overlay.visible:
			print("SMOKE photo placeholder swapped to image")
			banner.queue_free()
			return true
		await order_node.get_tree().process_frame
		waited += order_node.get_process_delta_time()
	push_error("SMOKE FAIL photo placeholder should swap to the real image or no-photo fallback")
	banner.queue_free()
	return false


func _count_progress_bars(root: Node) -> int:
	var n := 0
	if root is ProgressBar:
		n += 1
	for child in root.get_children():
		n += _count_progress_bars(child)
	return n


func _smoke_clear_cart(order_node: Node) -> bool:
	var saved: Dictionary = OrderClient.cart.duplicate(true)
	OrderClient.clear_cart()
	var pick: Dictionary = {}
	for drink in OrderClient.drinks():
		if drink is Dictionary and OrderClient.has_square_price(drink) and int(drink.get("price_cents", 0)) > 0:
			pick = drink
			break
	if pick.is_empty():
		push_error("SMOKE FAIL no priced item for Clear cart")
		OrderClient.cart = saved
		return false
	OrderClient.add_cart_item(str(pick.get("id", "")), {}, 1)
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	await get_tree().process_frame
	var clear := order_node.get_node_or_null("Safe/VBox/CartBar/Row/ClearCart") as Button
	if clear == null or not clear.visible:
		push_error("SMOKE FAIL Clear cart must show on the sticky bar when the cart has items")
		OrderClient.cart = saved
		return false
	if clear.text.to_lower().find("clear") < 0:
		push_error("SMOKE FAIL Clear cart button should be labeled clearly")
		OrderClient.cart = saved
		return false
	clear.pressed.emit()
	await get_tree().process_frame
	if OrderClient.cart_count() != 0:
		push_error("SMOKE FAIL Clear cart should empty every line, count=%d" % OrderClient.cart_count())
		OrderClient.cart = saved
		return false
	var summary := order_node.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	if summary == null or summary.text.find("0 items") < 0:
		push_error("SMOKE FAIL sticky total after Clear cart should be 0 items")
		OrderClient.cart = saved
		return false
	if clear.visible:
		push_error("SMOKE FAIL Clear cart should hide when the cart is empty")
		OrderClient.cart = saved
		return false
	OrderClient.cart = saved
	if order_node.has_method("_refresh_cart_bar"):
		order_node.call("_refresh_cart_bar")
	print("SMOKE Clear cart emptied sticky bar")
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
	var detail_item: Dictionary = croissant
	if not OrderClient.is_purchase_eligible(croissant):
		for row in OrderClient.drinks():
			if not row is Dictionary or not OrderClient.is_purchase_eligible(row):
				continue
			var groups: Variant = row.get("groups", [])
			if not groups is Array:
				continue
			for g in groups:
				if g is Dictionary and not bool(g.get("required", false)):
					detail_item = row
					break
			if detail_item != croissant:
				break
	if order_node.has_method("_open_detail"):
		order_node.call("_open_detail", detail_item)
		await order_node.get_tree().process_frame
		await order_node.get_tree().process_frame
		await order_node.get_tree().process_frame
		if not _label_contains(order_node, "Reheat") and detail_item == croissant:
			push_error("SMOKE FAIL croissant detail should list Square Reheat options")
			return false
		if not _label_contains(order_node, "optional"):
			push_error("SMOKE FAIL optional Square extras should be labeled, item=%s" % str(detail_item.get("name", "")))
			return false
		print("SMOKE detail shows optional extras on ", detail_item.get("name", ""))
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
	var content := order_node.get_node_or_null("Safe/VBox/Body/Content")
	var cart_photos := _count_texture_rects(content) if content else 0
	if cart_photos < 1:
		push_error("SMOKE FAIL cart lines should show item photos")
		OrderClient.cart = saved
		return false
	print("SMOKE cart line photos=", cart_photos)
	var found_thumb := false
	if content:
		for tex in content.find_children("*", "TextureRect", true, false):
			var parent := tex.get_parent()
			if parent is Control and (parent as Control).custom_minimum_size.x == 96:
				found_thumb = true
				break
	if not found_thumb:
		push_error("SMOKE FAIL cart line photos should be the older 96px thumbs")
		OrderClient.cart = saved
		return false
	var bar := order_node.get_node_or_null("Safe/VBox/CartBar/Row/CartSummary") as Label
	if bar == null or bar.text.find("1 item") < 0:
		push_error("SMOKE FAIL sticky cart bar should show item count only")
		OrderClient.cart = saved
		return false
	if bar.text.find("$") >= 0 or bar.text.find("\n") >= 0 or bar.text.find(str(drink.get("name", "___none___"))) >= 0:
		push_error("SMOKE FAIL sticky cart bar must not list names, mods, or dollars: %s" % bar.text)
		OrderClient.cart = saved
		return false
	if summary != "" and bar.text.find(summary.split(" · ")[0]) >= 0:
		push_error("SMOKE FAIL sticky cart bar should not include modifier text %s" % summary)
		OrderClient.cart = saved
		return false
	print("SMOKE sticky cart bar is count-only: ", bar.text)
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
		AccountClient.apply_square_payload({
			"ok": true,
			"session_token": "sess_smoke_status",
			"customer": {
				"id": "CUST_SMOKE",
				"phone": "+12055550123",
				"given_name": "Ada",
				"family_name": "Lovelace",
				"nickname": "",
				"display_name": "Ada Lovelace",
			},
		})
		order_node.set("_detail_drink", {})
		order_node.set("_cart_edit_idx", -1)
		order_node.set("_tab", 2)
		order_node.set("_my_status", {
			"open_orders": [{
				"id": "OPEN_UNPAID",
				"name": "Unpaid checkout",
				"status": "making",
				"order_number": "99",
				"ahead": 0,
				"items": [{"name": "Should not list unpaid", "qty": 1}],
			}, {
				"id": "PAID_READY",
				"name": "Should not list ready",
				"status": "ready",
				"paid": true,
				"order_number": "7",
				"ahead": 0,
				"items": [{"name": "Should not list ready", "qty": 1}],
			}, {
				"id": "PAID_MAKING",
				"name": "Ada",
				"status": "making",
				"paid": true,
				"tender_count": 1,
				"net_amount_due_cents": 0,
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
		var status_body := order_node.get_node_or_null("Safe/VBox/Body/Content")
		if status_body == null or not _label_contains(status_body, "Oat milk"):
			push_error("SMOKE FAIL Status tab should list line-item modifiers")
			OrderClient.cart = saved
			return false
		if not _label_contains(status_body, "app order 42"):
			push_error("SMOKE FAIL Status should show a short app order number")
			OrderClient.cart = saved
			return false
		if not _label_contains(status_body, "1 ahead") or not _label_contains(status_body, "in front"):
			push_error("SMOKE FAIL Status should show how many paid making orders are in front")
			OrderClient.cart = saved
			return false
		if _label_contains(status_body, "Should not list unpaid") or _label_contains(status_body, "Should not list ready"):
			push_error("SMOKE FAIL Status must only list paid making tickets")
			OrderClient.cart = saved
			return false
		if _label_contains(status_body, "sq0id") or _label_contains(status_body, "PAID_MAKING"):
			push_error("SMOKE FAIL Status must not show a raw Square id")
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
		OrderClient.cart["items"] = [{"id": "UNRELATED", "qty": 4}]
		var added: Dictionary = await AccountClient.reorder(hist)
		if not added.get("ok", false) or (added.get("items", []) as Array).is_empty():
			push_error("SMOKE FAIL order-again should replace the cart with the drink")
			OrderClient.cart = saved
			return false
		if str(OrderClient.cart.get("items", [{}])[0].get("id", "")) == "UNRELATED":
			push_error("SMOKE FAIL order-again must replace unrelated cart lines")
			OrderClient.cart = saved
			return false
		var again := OrderClient.visible_mod_line(OrderClient.cart["items"][0])
		if again == "No extras":
			push_error("SMOKE FAIL order-again should keep modifier labels")
			OrderClient.cart = saved
			return false
		print("SMOKE order-again replace + preselect mods → ", again)
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
		OrderClient.cart["items"] = [{"id": "LEFTOVER", "qty": 9}]
		added = await AccountClient.reorder(id_hist)
		if not added.get("ok", false):
			push_error("SMOKE FAIL order-again replace should succeed")
			OrderClient.cart = saved
			return false
		if (added.get("items", []) as Array).size() != 2:
			push_error("SMOKE FAIL order-again should replace with every RetrieveOrder line, got %s" % added)
			OrderClient.cart = saved
			return false
		if OrderClient.cart_count() != 3:
			push_error("SMOKE FAIL replaced cart qty should be 1+2, got %d" % OrderClient.cart_count())
			OrderClient.cart = saved
			return false
		if str(OrderClient.cart.get("items", [{}])[0].get("id", "")) == "LEFTOVER":
			push_error("SMOKE FAIL leftover cart lines must be gone after replace")
			OrderClient.cart = saved
			return false
		print("SMOKE order-again replace retrieve lines → ", added.get("items", []).size(), " cart=", OrderClient.cart_count())
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

