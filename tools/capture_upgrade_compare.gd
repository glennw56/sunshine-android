extends SceneTree
## Same-camera shots for the Godot upgrade: menu, Loyalty, Customize, order,
## Explore patio, and the patio games (practice, bullseye, disco).
##   SUNSHINE_SHOT_DIR=/path xvfb-run -a godot --path . \
##     --rendering-method gl_compatibility --resolution 720x1280 \
##     --audio-driver Dummy -s res://tools/capture_upgrade_compare.gd

const RECIPE := {
	"v": 1,
	"skin": "rich",
	"hair": "wavy",
	"hair_color": "honey",
	"outfit": "apricot",
	"bottoms": "pants",
	"pants": "navy",
	"apron": "wine",
	"hat": "none",
	"accessory": "glasses",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_dir := OS.get_environment("SUNSHINE_SHOT_DIR").strip_edges()
	if disk_dir == "":
		disk_dir = "/opt/cursor/artifacts/screenshots/upgrade"
	DirAccess.make_dir_recursive_absolute(disk_dir)
	var gs: Node = root.get_node("GameSave")
	var ps: Node = root.get_node("ProfileStore")
	_apply_look(gs, ps)
	gs.call("clear_square_session")
	gs.call("set_square_session", _payload(140))
	if not await _scene("res://scenes/main_menu.tscn", disk_dir, "menu.png", 16):
		quit(1)
		return
	if not await _scene("res://scenes/loyalty/loyalty.tscn", disk_dir, "loyalty.png", 36):
		quit(1)
		return
	if not await _scene("res://scenes/explore/customize.tscn", disk_dir, "customize.png", 40):
		quit(1)
		return
	if not await _order(disk_dir):
		quit(1)
		return
	if not await _explore(disk_dir):
		quit(1)
		return
	print("CAPTURE upgrade compare ok -> ", disk_dir)
	quit(0)


func _order(disk_dir: String) -> bool:
	if change_scene_to_file("res://scenes/order/order.tscn") != OK:
		push_error("CAPTURE FAIL order")
		return false
	var oc: Node = root.get_node("OrderClient")
	var waited := 0.0
	while waited < 12.0 and int(oc.call("drinks").size()) == 0:
		await process_frame
		await RenderingServer.frame_post_draw
		waited += 0.05
	for _i in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	print("CAPTURE order drinks=", oc.call("drinks").size(), " source=", oc.call("catalog_source"))
	return _snap(disk_dir, "order.png")


func _explore(disk_dir: String) -> bool:
	if change_scene_to_file("res://scenes/explore/explore_3d.tscn") != OK:
		push_error("CAPTURE FAIL explore")
		return false
	for _i in 8:
		await process_frame
	var explore := current_scene
	if explore == null:
		push_error("CAPTURE FAIL explore scene")
		return false
	var hud := explore.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var player_cam := explore.get_node_or_null("Player/Camera3D") as Camera3D
	if player_cam:
		player_cam.current = false
	var rig := explore.get_node_or_null("ReviewCameras")
	if rig == null:
		push_error("CAPTURE FAIL ReviewCameras")
		return false
	for shot in ["Entrance", "Dining", "Exterior"]:
		var cam := rig.get_node_or_null(shot) as Camera3D
		if cam == null:
			push_error("CAPTURE FAIL missing " + shot)
			return false
		cam.current = true
		for _i in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		if not _snap(disk_dir, "explore_" + shot.to_lower() + ".png"):
			return false
		cam.current = false
	if not await _shot_at(explore, disk_dir, "game_practice.png", Vector3(0.0, 2.2, 30.2), Vector3(0.0, 1.1, 35.5)):
		return false
	if not await _shot_at(explore, disk_dir, "game_bullseye.png", Vector3(2.2, 1.55, 0.6), Vector3(4.35, 1.15, -2.4)):
		return false
	var party := explore.get_tree().get_first_node_in_group("disco_party")
	if party == null:
		push_error("CAPTURE FAIL disco party missing")
		return false
	party.call("apply_until", Time.get_unix_time_from_system() + 20.0)
	for _i in 20:
		await process_frame
		await RenderingServer.frame_post_draw
	if not await _shot_at(explore, disk_dir, "game_disco.png", Vector3(-1.6, 2.4, 2.2), Vector3(0.15, 1.2, -2.55)):
		return false
	return true


func _shot_at(explore: Node, disk_dir: String, file_name: String, pos: Vector3, look: Vector3) -> bool:
	var cam := explore.get_node_or_null("UpgradeShotCam") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "UpgradeShotCam"
		cam.fov = 50.0
		explore.add_child(cam)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true
	for _i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	return _snap(disk_dir, file_name)


func _scene(path: String, disk_dir: String, file_name: String, frames: int) -> bool:
	if change_scene_to_file(path) != OK:
		push_error("CAPTURE FAIL " + path)
		return false
	for _i in frames:
		await process_frame
		await RenderingServer.frame_post_draw
	return _snap(disk_dir, file_name)


func _apply_look(gs: Node, ps: Node) -> void:
	var look := RECIPE.duplicate(true)
	gs.set("avatar_recipe", look)
	ps.set("avatar", look)


func _payload(points: int) -> Dictionary:
	return {
		"customer": {
			"id": "CUST_LOYALTY_PREVIEW",
			"phone": "2564525192",
			"given_name": "Ada",
			"family_name": "Baker",
			"display_name": "Ada Baker",
		},
		"loyalty": {
			"enrolled": true,
			"account_id": "LOY_PREVIEW",
			"points": points,
			"program_id": "PROG_PREVIEW",
		},
	}


func _snap(disk_dir: String, file_name: String) -> bool:
	var tex: ViewportTexture = root.get_texture()
	if tex == null:
		push_error("CAPTURE FAIL viewport " + file_name)
		return false
	var img: Image = tex.get_image()
	if img == null:
		push_error("CAPTURE FAIL image " + file_name)
		return false
	var disk := disk_dir.path_join(file_name)
	var err := img.save_png(disk)
	print("CAPTURE ", file_name, " ", img.get_width(), "x", img.get_height(), " -> ", disk, " err=", err)
	return err == OK
