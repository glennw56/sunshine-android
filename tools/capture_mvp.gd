extends SceneTree
## Capture MVP screens: menu, order kiosk, explore doorway.
##   godot --path . -s res://tools/capture_mvp.gd
## Writes export/review/mvp_*.png

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := ProjectSettings.globalize_path("res://export/review")
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var shots := [
		{"file": "mvp_main_menu.png", "path": "res://scenes/main_menu.tscn"},
		{"file": "mvp_order_kiosk.png", "path": "res://scenes/order/order.tscn"},
		{"file": "mvp_explore.png", "path": "res://scenes/explore/explore_3d.tscn"},
	]
	for shot in shots:
		if change_scene_to_file(str(shot["path"])) != OK:
			push_error("CAPTURE FAIL " + str(shot["path"]))
			quit(1)
			return
		var waited := 0.0
		while waited < 6.0:
			await process_frame
			waited += 0.05
			if current_scene and str(current_scene.scene_file_path).ends_with(str(shot["path"]).get_file()):
				break
		for _i in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		if str(shot["path"]).ends_with("order.tscn"):
			var oc := root.get_node("OrderClient")
			var catalog_wait := 0.0
			while catalog_wait < 6.0 and oc.call("drinks").is_empty():
				await process_frame
				catalog_wait += 0.05
			if current_scene.has_method("_render"):
				current_scene.call("_render")
			for _j in 20:
				await process_frame
				await RenderingServer.frame_post_draw
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("CAPTURE FAIL viewport " + str(shot["file"]))
			quit(1)
			return
		var img: Image = tex.get_image()
		if img == null:
			push_error("CAPTURE FAIL image " + str(shot["file"]))
			quit(1)
			return
		var disk := disk_dir.path_join(str(shot["file"]))
		var err := img.save_png(disk)
		print("CAPTURE ", shot["file"], " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
		if str(shot["path"]).ends_with("order.tscn"):
			var client := root.get_node("OrderClient")
			if current_scene.has_method("_jump_to_section"):
				current_scene.call("_jump_to_section", "coffee")
				await process_frame
				await RenderingServer.frame_post_draw
				var mid: Image = root.get_texture().get_image()
				if mid:
					var mid_path := disk_dir.path_join("mvp_order_midscroll.png")
					mid.save_png(mid_path)
					print("CAPTURE mvp_order_midscroll.png ", mid.get_width(), "x", mid.get_height(), " -> ", mid_path)
			var drinks: Array = client.call("drinks")
			if not drinks.is_empty() and current_scene.has_method("_open_detail"):
				current_scene.call("_open_detail", drinks[0])
				await process_frame
				var content := current_scene.get_node_or_null("Safe/VBox/Body/Content")
				if content:
					for child in content.get_children():
						if child is HFlowContainer and child.get_child_count() > 0:
							var chip := child.get_child(0) as Button
							if chip:
								chip.pressed.emit()
							break
				await process_frame
				await RenderingServer.frame_post_draw
				var detail: Image = root.get_texture().get_image()
				if detail:
					var detail_path := disk_dir.path_join("mvp_order_mods.png")
					detail.save_png(detail_path)
					print("CAPTURE mvp_order_mods.png ", detail.get_width(), "x", detail.get_height(), " -> ", detail_path)
	print("CAPTURE mvp screens ok")
	quit(0)
