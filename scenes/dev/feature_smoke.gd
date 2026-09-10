extends Node
## Run: godot --headless --path . res://scenes/dev/feature_smoke.tscn

func _ready() -> void:
	var code := await _run()
	await get_tree().process_frame
	get_tree().quit(code)


func _run() -> int:
	print("SMOKE autoloads AppConfig url=", AppConfig.order_url())
	for path in [
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
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/VBox/OrderButton", "Safe/VBox/TipButton", "Safe/VBox/ExploreButton"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					return 1
			print("SMOKE main menu 3 buttons present")
		if path.ends_with("order.tscn"):
			var waited := 0.0
			while waited < 8.0 and OrderClient.drinks().is_empty():
				await get_tree().process_frame
				waited += get_process_delta_time()
			print("SMOKE order drinks=", OrderClient.drinks().size(), " source=", OrderClient.catalog_source(), " pay=", OrderClient.pay_mode())
			if OrderClient.drinks().is_empty():
				push_error("SMOKE FAIL live catalog empty")
				return 1
		if path.ends_with("explore_3d.tscn"):
			var world := node.get_node("World")
			print("SMOKE explore world children=", world.get_child_count())
			if world.get_child_count() < 8:
				push_error("SMOKE FAIL explore world too empty")
				return 1
			var pickups := 0
			var indoor_pickups := 0
			for child in world.get_children():
				if child is CollectiblePickup:
					pickups += 1
					if child.position.z > 0.0 and child.position.z < 6.0:
						indoor_pickups += 1
			print("SMOKE explore pickups=", pickups, " indoor=", indoor_pickups, " door_w=", world._door_w)
			if pickups < 12 or indoor_pickups < 3:
				push_error("SMOKE FAIL expected indoor+outdoor collectibles")
				return 1
			var player := node.get_node("Player") as Node3D
			if player.position.z > -1.5:
				push_error("SMOKE FAIL player should spawn outside the storefront door")
				return 1
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
