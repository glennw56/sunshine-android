extends SceneTree
## Prove Explore 3D cannot boot into a cleared black viewport.
## Android is pinned to GLES; the scene must still present on the Mobile renderer.
##
##   godot --headless --path . --rendering-method gl_compatibility -s res://tools/prove_explore_visible.gd
##   godot --headless --path . --rendering-method mobile -s res://tools/prove_explore_visible.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var android_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.android", ""))
	var base_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var active := RenderingServer.get_current_rendering_method()
	var hdr := bool(ProjectSettings.get_setting("rendering/viewport/hdr_2d", true))
	var fallback := bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3", false))
	print("EXPLORE-VIS base=", base_method, " android=", android_method, " active=", active, " hdr_2d=", hdr, " gl_fallback=", fallback)
	if android_method != "gl_compatibility":
		push_error("EXPLORE-VIS FAIL rendering_method.android must be gl_compatibility, got '%s'" % android_method)
		quit(1)
		return
	if base_method != "mobile":
		push_error("EXPLORE-VIS FAIL base rendering_method must stay mobile (desktop Vulkan / iOS Metal), got '%s'" % base_method)
		quit(1)
		return
	if hdr:
		push_error("EXPLORE-VIS FAIL hdr_2d must stay false")
		quit(1)
		return
	if not fallback:
		push_error("EXPLORE-VIS FAIL fallback_to_opengl3 must stay true")
		quit(1)
		return
	if not _export_pins_gles():
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	if packed == null:
		push_error("EXPLORE-VIS FAIL explore scene did not load")
		quit(1)
		return
	var explore := packed.instantiate()
	root.add_child(explore)
	await process_frame
	await process_frame
	await process_frame
	if not _assert_scene(explore, active):
		quit(1)
		return
	await process_frame
	await process_frame
	if not _sample_frame(explore, active):
		quit(1)
		return
	print("EXPLORE-VIS ok renderer=", active)
	quit(0)


func _export_pins_gles() -> bool:
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f == null:
		push_error("EXPLORE-VIS FAIL could not read export_presets.cfg")
		return false
	var text := f.get_as_text()
	f.close()
	if text.count("command_line/extra_args=\"--rendering-method gl_compatibility\"") < 2:
		push_error("EXPLORE-VIS FAIL both Android presets must pass --rendering-method gl_compatibility")
		return false
	if text.count("version/name=\"0.1.78\"") < 2 or text.count("version/code=79") < 2:
		push_error("EXPLORE-VIS FAIL Android presets must be versionName 0.1.78 / versionCode 79")
		return false
	# iOS App Store version is intentionally left alone.
	if not text.contains("application/short_version=\"0.1.76\""):
		push_error("EXPLORE-VIS FAIL iOS short_version should stay 0.1.76")
		return false
	return true


func _assert_scene(explore: Node, active: String) -> bool:
	var world := explore.get_node_or_null("World") as Node3D
	if world == null:
		push_error("EXPLORE-VIS FAIL World missing")
		return false
	var shop := world.get_node_or_null("ChatGPTStorefront")
	if shop == null:
		push_error("EXPLORE-VIS FAIL patio GLB did not instance (missing import or load failure)")
		return false
	var meshes := _count_meshes(shop)
	print("EXPLORE-VIS patio_meshes=", meshes)
	if meshes < 1:
		push_error("EXPLORE-VIS FAIL patio has no meshes")
		return false
	var env_node := world.get_node_or_null("ExploreEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		push_error("EXPLORE-VIS FAIL ExploreEnvironment missing")
		return false
	var env := env_node.environment
	var bg := env.background_color
	if bg.r < 0.05 and bg.g < 0.05 and bg.b < 0.05:
		push_error("EXPLORE-VIS FAIL environment background_color is black")
		return false
	if active == "gl_compatibility" or OS.get_name() != "Android":
		if env.background_mode != Environment.BG_SKY or env.sky == null:
			push_error("EXPLORE-VIS FAIL GLES/desktop should use a sky, mode=%s" % env.background_mode)
			return false
	else:
		if env.background_mode != Environment.BG_COLOR:
			push_error("EXPLORE-VIS FAIL Vulkan-on-Android must use a solid sky color, not a sky shader")
			return false
	var player := explore.get_node_or_null("Player")
	var cam: Camera3D = null
	if player:
		cam = player.find_child("Camera3D", true, false) as Camera3D
	if cam == null or not cam.current:
		push_error("EXPLORE-VIS FAIL player Camera3D is not current")
		return false
	if cam.environment == null:
		push_error("EXPLORE-VIS FAIL camera has no environment; viewport can present cleared")
		return false
	if cam.environment != env:
		push_error("EXPLORE-VIS FAIL camera environment is not the explore environment")
		return false
	var vp := explore.get_viewport()
	if vp and vp.transparent_bg:
		push_error("EXPLORE-VIS FAIL Explore viewport is transparent (clears black)")
		return false
	return true


func _sample_frame(explore: Node, active: String) -> bool:
	var vp := explore.get_viewport()
	if vp == null or vp.get_texture() == null:
		print("EXPLORE-VIS no drawable viewport (structural checks still passed)")
		return true
	var img := vp.get_texture().get_image()
	if img == null or img.get_width() < 2 or img.get_height() < 2:
		print("EXPLORE-VIS viewport image unavailable")
		return true
	var black := 0
	var samples := 0
	var step := 8
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			samples += 1
			if c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
				black += 1
	var ratio := float(black) / float(maxi(samples, 1))
	var out := "/tmp/explore-vis-%s.png" % active
	img.save_png(out)
	print("EXPLORE-VIS black_ratio=%.3f samples=%d saved=%s" % [ratio, samples, out])
	# Headless / software GPUs often return a cleared frame. A real display must not.
	if DisplayServer.get_name() == "headless":
		return true
	if ratio > 0.92:
		push_error("EXPLORE-VIS FAIL viewport is black on %s (ratio %.3f)" % [active, ratio])
		return false
	return true


func _count_meshes(n: Node) -> int:
	var count := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		count += 1
	for child in n.get_children():
		count += _count_meshes(child)
	return count
