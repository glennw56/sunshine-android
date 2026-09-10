extends SceneTree
## Headless instantiate of the three feature scenes. Run:
##   godot --headless --path . -s res://tools/scene_smoke.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var paths := PackedStringArray([
		"res://scenes/main_menu.tscn",
		"res://scenes/tip_ad/tip_ad.tscn",
		"res://scenes/order/order.tscn",
		"res://scenes/explore/explore_3d.tscn",
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
			var waited := 0.0
			while waited < 8.0 and OrderClient.drinks().is_empty():
				await process_frame
				waited += 0.05
			print("SMOKE order drinks=", OrderClient.drinks().size(), " source=", OrderClient.catalog_source(), " pay=", OrderClient.pay_mode())
			if OrderClient.drinks().is_empty():
				push_error("SMOKE FAIL live catalog empty")
				quit(1)
				return
		if path.ends_with("explore_3d.tscn"):
			print("SMOKE explore world children=", node.get_node("World").get_child_count())
			if node.get_node("World").get_child_count() < 8:
				push_error("SMOKE FAIL explore world too empty")
				quit(1)
				return
		if path.ends_with("main_menu.tscn"):
			for n in ["Safe/VBox/OrderButton", "Safe/VBox/TipButton", "Safe/VBox/ExploreButton"]:
				if node.get_node_or_null(n) == null:
					push_error("SMOKE FAIL missing " + n)
					quit(1)
					return
			print("SMOKE main menu 3 buttons present")
		print("SMOKE ok ", path, " class=", node.get_class(), " children=", node.get_child_count())
		root.remove_child(node)
		node.free()
	print("SMOKE all scenes ok")
	quit(0)
