extends SceneTree
## Headless instantiate of the three feature scenes. Run:
##   godot --headless --path . -s res://tools/scene_smoke.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths := PackedStringArray([
		"res://scenes/main_menu.tscn",
		"res://scenes/donate/donate.tscn",
		"res://scenes/tip_ad/tip_ad.tscn",
		"res://scenes/order/order.tscn",
		"res://scenes/explore/explore_3d.tscn",
		"res://scenes/loyalty/loyalty.tscn",
	])
	for path in paths:
		print("SMOKE load ", path)
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("SMOKE FAIL load " + path)
			quit(1)
			return
		var node: Node = packed.instantiate()
		root.add_child(node)
		# Let _ready / first awaits run (Order HTTP, Explore CSG).
		await process_frame
		await process_frame
		if path.ends_with("order.tscn"):
			var oc := root.get_node("OrderClient")
			var waited := 0.0
			while waited < 8.0 and oc.call("drinks").is_empty():
				await process_frame
				waited += 0.05
			print("SMOKE order drinks=", oc.call("drinks").size(), " source=", oc.call("catalog_source"), " pay=", oc.call("pay_mode"), " fallback=", oc.get("used_fallback"))
			if oc.call("drinks").is_empty():
				push_error("SMOKE FAIL order catalog empty (live Square)")
				quit(1)
				return
		if path.ends_with("explore_3d.tscn"):
			var world := node.get_node("World")
			print("SMOKE explore world children=", world.get_child_count())
			if world.get_child_count() < 8:
				push_error("SMOKE FAIL explore world too empty")
				quit(1)
				return
			var pickups := 0
			var lot_pickups := 0
			for child in world.get_children():
				if child.is_in_group("bakery_pickup"):
					pickups += 1
					if child.position.z > -8.0 and child.position.z < 6.0:
						lot_pickups += 1
			print("SMOKE explore pickups=", pickups, " lot=", lot_pickups)
			# Lawn pickups are a seeded scatter (12), not three fixed front-lot cubes.
			if pickups < 12:
				push_error("SMOKE FAIL expected 12 seeded lawn pickups, got %d" % pickups)
				quit(1)
				return
			var oc := root.get_node("OrderClient")
			var board_wait := 0.0
			while board_wait < 8.0 and oc.call("drinks").is_empty():
				await process_frame
				board_wait += 0.05
			if world.get_node_or_null("LiveMenuBoard") != null:
				push_error("SMOKE FAIL explore chalkboard should be gone")
				quit(1)
				return
			var sign := world.get_node_or_null("WelcomeSign/WelcomeText") as Label3D
			if sign == null:
				push_error("SMOKE FAIL explore welcome sign missing")
				quit(1)
				return
			var spoken := " ".join(sign.text.replace("\n", " ").split(" ", false))
			if spoken != "Thanks for loading into Sunshine World":
				push_error("SMOKE FAIL explore welcome sign text: " + sign.text)
				quit(1)
				return
			var priced := _explore_priced_labels(world)
			if not priced.is_empty():
				push_error("SMOKE FAIL explore map label has a price: " + ", ".join(priced))
				quit(1)
				return
			var named := _explore_menu_name_labels(world, oc)
			if not named.is_empty():
				push_error("SMOKE FAIL explore map still shows a menu name: " + ", ".join(named))
				quit(1)
				return
			print("SMOKE explore welcome sign: ", spoken)
		if path.ends_with("loyalty.tscn"):
			for n in ["Safe/Col/Scroll/Card/Pad/Col/Points", "Safe/Col/Scroll/Card/Pad/Col/Track", "Safe/Col/Scroll/Card/Pad/Col/HowBody", "Safe/Col/Header/Back"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL loyalty missing " + n)
					quit(1)
					return
			var how := node.get_node("Safe/Col/Scroll/Card/Pad/Col/HowBody") as Label
			if how.text.find("before tax") < 0 or how.text.find("Fruit Tea") < 0:
				push_error("SMOKE FAIL loyalty how-it-works copy")
				quit(1)
				return
			print("SMOKE loyalty screen present")
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/VBox/OrderButton", "Safe/VBox/PreviousOrdersButton", "Safe/VBox/DonateButton", "Safe/VBox/TipButton", "Safe/VBox/ExploreButton", "Safe/VBox/LoyaltyButton"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					quit(1)
					return
			print("SMOKE main menu buttons present")
		print("SMOKE ok ", path, " class=", node.get_class(), " children=", node.get_child_count())
		root.remove_child(node)
		node.free()
	print("SMOKE all scenes ok")
	quit(0)


func _explore_label_has_price(text: String) -> bool:
	return text.find("$") >= 0


func _explore_priced_labels(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	if node is Label3D and _explore_label_has_price((node as Label3D).text):
		found.append((node as Label3D).text)
	for child in node.get_children():
		found.append_array(_explore_priced_labels(child))
	return found


func _explore_menu_name_labels(node: Node, order_client: Node) -> PackedStringArray:
	var names := {}
	for item in order_client.call("drinks"):
		if item is Dictionary:
			var item_name := str(item.get("name", "")).strip_edges()
			if item_name != "":
				names[item_name] = true
	return _explore_named_labels(node, names)


func _explore_named_labels(node: Node, names: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	if node is Label3D:
		for line in (node as Label3D).text.split("\n", false):
			var text := line.strip_edges()
			if names.has(text):
				found.append(text)
	for child in node.get_children():
		found.append_array(_explore_named_labels(child, names))
	return found
