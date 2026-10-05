extends SceneTree
## Proves the production patio stays put, then the test world dresses it.
##   godot --path . --headless -s res://tools/test_world_smoke.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cfg: Node = root.get_node("AppConfig")
	cfg.set("test_world", false)
	if not await _production_stays_plain():
		quit(1)
		return
	if not await _test_world_dresses():
		quit(1)
		return
	print("TEST WORLD SMOKE ok")
	quit(0)


func _production_stays_plain() -> bool:
	var packed := load("res://scenes/explore/explore_3d.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	for _i in 8:
		await process_frame
	var world := scene.get_node("World")
	if world.get_node_or_null("HW_NorthLawn") != null or world.get_node_or_null("PumpkinBin") != null:
		push_error("TEST FAIL production explore dressed the test patio")
		return false
	if not _grass_and_rim(world):
		return false
	print("TEST production patio plain grass+rim ok")
	scene.queue_free()
	await process_frame
	return true


func _test_world_dresses() -> bool:
	var packed := load("res://scenes/explore/explore_test.tscn") as PackedScene
	var boot := packed.instantiate()
	root.add_child(boot)
	for _i in 10:
		await process_frame
	var cfg: Node = root.get_node("AppConfig")
	if not bool(cfg.get("test_world")):
		push_error("TEST FAIL explore_test did not enable test_world")
		return false
	var scene := boot.get_node("Explore")
	var world := scene.get_node("World")
	if not _grass_and_rim(world):
		return false
	for pocket in ["HW_NorthLawn", "HW_WestCorner", "HW_DiscoFringe", "PumpkinBin"]:
		if world.get_node_or_null(pocket) == null:
			push_error("TEST FAIL missing " + pocket)
			return false
	var before: Vector3 = world.get_meta("test_island_before", Vector3.ZERO)
	var after: Vector3 = world.get_meta("test_island_after", Vector3.ZERO)
	print("TEST island before=", before, " after=", after, " center=", world.get_meta("test_island_center", Vector3.ZERO))
	if before.x < 1.0 or after.x < before.x * 1.4 or after.z < before.z * 1.4:
		push_error("TEST FAIL island should grow about 1.5× in XZ, before=%s after=%s" % [before, after])
		return false
	if after.x > before.x * 1.65 or after.z > before.z * 1.65:
		push_error("TEST FAIL island scale ran past 1.6×, before=%s after=%s" % [before, after])
		return false
	var practice := 0
	var found: Array = world.find_children("*", "PracticeTarget", true, false)
	if found.is_empty():
		found = world.get_tree().get_nodes_in_group("practice_target")
	for child in found:
		if not child is Node3D:
			continue
		practice += 1
		var z := (child as Node3D).position.z
		print("TEST practice ", child.name, " z=", z)
		if z < 33.5 or z > 38.0:
			push_error("TEST FAIL practice target left z 34–37, z=%.2f" % z)
			return false
	if practice < 3:
		push_error("TEST FAIL expected 3 practice targets, got %d" % practice)
		return false
	var bin := world.get_node("PumpkinBin") as Node3D
	if absf(bin.position.x - 8.0) > 0.2 or absf(bin.position.z - 31.0) > 0.2:
		push_error("TEST FAIL pumpkin bin drifted, pos=%s" % str(bin.position))
		return false
	var ping := scene.get_node_or_null("HUD/Root/ServerPing") as Label
	if ping == null or not ping.visible or not ping.text.begins_with("Ping"):
		push_error("TEST FAIL ping HUD missing")
		return false
	var player: Node = scene.get_node("Player")
	var cookies_before := int(root.get_node("GameSave").get("throw_cookies"))
	player.global_position = bin.global_position + Vector3(0.4, 0.2, 0.4)
	if not bool(player.call("try_pickup_pumpkin")) or not bool(player.call("holding_pumpkin")):
		push_error("TEST FAIL pumpkin pickup")
		return false
	if player.get_node_or_null("Avatar/HandSocket") == null and player.find_child("HeldPumpkin", true, false) == null:
		push_error("TEST FAIL held pumpkin missing from hand")
		return false
	if not bool(player.call("toss_cookie")):
		push_error("TEST FAIL pumpkin throw did not start")
		return false
	var flew := false
	for _i in 40:
		await process_frame
		if scene.get_tree().get_first_node_in_group("pumpkin_projectile") != null:
			flew = true
			break
	if not flew:
		push_error("TEST FAIL pumpkin projectile never spawned")
		return false
	var cookies_after := int(root.get_node("GameSave").get("throw_cookies"))
	if cookies_after != cookies_before:
		push_error("TEST FAIL pumpkin throw spent a cookie %d -> %d" % [cookies_before, cookies_after])
		return false
	var prop := load("res://scripts/explore/pumpkin_prop.gd")
	var host := Node3D.new()
	root.add_child(host)
	var stand: Node3D = prop.call("procedural")
	host.add_child(stand)
	await process_frame
	var height := _mesh_height(stand)
	print("TEST pumpkin stand-in height=%.3f" % height)
	if height < 0.35 or height > 0.45:
		push_error("TEST FAIL pumpkin stand-in should be 0.35–0.45 m, h=%.3f" % height)
		return false
	print("TEST halloween+pumpkin+ping ok")
	return true


func _grass_and_rim(world: Node) -> bool:
	var shop := world.get_node_or_null("ChatGPTStorefront")
	var grass := _find(shop, "Grass_Base") as MeshInstance3D
	if grass == null:
		push_error("TEST FAIL missing Grass_Base")
		return false
	var box: AABB = grass.global_transform * grass.get_aabb()
	if box.size.x < 210.0 or box.size.z < 210.0:
		push_error("TEST FAIL grass shrank, size=%s" % str(box.size))
		return false
	if absf(box.get_center().x) > 2.0 or absf(box.get_center().z) > 2.0:
		push_error("TEST FAIL grass drifted, center=%s" % str(box.get_center()))
		return false
	var borders := world.get_node_or_null("PhotoBorders")
	var north := borders.get_node_or_null("NorthBorder") if borders else null
	if north == null:
		push_error("TEST FAIL photo north border missing")
		return false
	if absf((north as Node3D).position.z + 109.6) > 0.5:
		push_error("TEST FAIL photo rim moved, z=%.2f" % (north as Node3D).position.z)
		return false
	return true


func _find(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name) == node_name:
			return n
		for child in n.get_children():
			stack.append(child)
	return null


func _mesh_height(root_node: Node3D) -> float:
	var box := AABB()
	var any := false
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var piece := mi.global_transform * mi.get_aabb()
			if not any:
				box = piece
				any = true
			else:
				box = box.merge(piece)
		for child in n.get_children():
			stack.append(child)
	return box.size.y
