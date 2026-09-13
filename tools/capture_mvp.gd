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
	print("CAPTURE mvp screens ok")
	quit(0)
