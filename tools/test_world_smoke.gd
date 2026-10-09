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
	if world.get_node_or_null("PatioGhosts") != null or world.get_node_or_null("GiantPumpkin") != null:
		push_error("TEST FAIL production explore spawned ghosts or the giant pumpkin")
		return false
	if world.get_node_or_null("PerimeterWall") != null:
		push_error("TEST FAIL production explore spawned the perimeter wall")
		return false
	if world.get_node_or_null("PatioPets") != null or world.get_node_or_null("Graveyard") != null:
		push_error("TEST FAIL production explore spawned pets or the graveyard")
		return false
	if world.get_node_or_null("LogoSun") == null or world.get_node_or_null("LogoMoon") != null:
		push_error("TEST FAIL production explore should keep the day logo sun")
		return false
	var sun_disc := world.get_node("LogoSun").find_child("LogoDisc", true, false)
	if sun_disc == null or not (sun_disc is Sprite3D):
		push_error("TEST FAIL production sun disc should stay the logo sprite")
		return false
	if scene.find_child("CookieMesh", true, false) != null or scene.find_child("PracticeTargetArt", true, false) != null:
		push_error("TEST FAIL production explore picked up a test-world prop mesh")
		return false
	if world.find_child("FloorBase", true, false) != null or world.find_child("BullseyeModel", true, false) != null or world.find_child("Torso_Top", true, false) != null:
		push_error("TEST FAIL production explore picked up a batch-3 mesh")
		return false
	for node in world.find_children("*", "", true, false):
		if node.has_meta("batch3_prop"):
			push_error("TEST FAIL production menu prop used the batch-3 mesh")
			return false
	var island := _find(world.get_node_or_null("ChatGPTStorefront"), "Patio_Island") as Node3D
	if island == null:
		push_error("TEST FAIL production Patio_Island missing")
		return false
	var island_box := _mesh_box(island)
	print("TEST production island size=", island_box.size)
	if island_box.size.x > 18.0 or island_box.size.z > 16.0:
		push_error("TEST FAIL production island is the expand mesh, size=%s" % str(island_box.size))
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
	print("TEST island before=", before, " after=", after, " center=", world.get_meta("test_island_center", Vector3.ZERO), " authored=", world.get_meta("test_island_authored", false))
	if bool(world.get_meta("test_island_authored", false)):
		if after.x < 21.0 or after.x > 24.5 or after.y > 0.25 or after.z < 15.2 or after.z > 17.2:
			push_error("TEST FAIL authored island should be about 22 × 0.15 × 16, after=%s" % after)
			return false
		var shop := world.get_node_or_null("ChatGPTStorefront")
		if shop == null or shop.find_child("Bistro_W2", true, false) == null:
			push_error("TEST FAIL p2 patio missing Bistro_W2")
			return false
		if shop.find_child("Picnic_West", true, false) == null:
			push_error("TEST FAIL Picnic_West was removed (soften ran on the remade patio)")
			return false
	else:
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
		var face := (child as Node).get_node_or_null("FaceCollider") as StaticBody3D
		if face == null or face.position.distance_to(Vector3(0, 1.1, 0)) > 0.05:
			push_error("TEST FAIL practice target is missing the face collider")
			return false
		var face_shape := face.get_child(0).shape as BoxShape3D
		if face_shape == null or face_shape.size.distance_to(Vector3(0.8, 0.8, 0.12)) > 0.02:
			push_error("TEST FAIL practice face collider size %s" % str(face_shape.size if face_shape else Vector3.ZERO))
			return false
		if (child as Node).find_child("PracticeTargetArt", true, false) == null:
			push_error("TEST FAIL practice target art missing")
			return false
	if practice < 3:
		push_error("TEST FAIL expected 3 practice targets, got %d" % practice)
		return false
	var bin := world.get_node("PumpkinBin") as Node3D
	if absf(bin.position.x - 8.0) > 0.2 or absf(bin.position.z - 31.0) > 0.2:
		push_error("TEST FAIL pumpkin bin drifted, pos=%s" % str(bin.position))
		return false
	var bin_art := bin.get_node_or_null("PumpkinBinArt")
	if bin_art == null or _find_prefix(bin_art, "Sign") == null:
		push_error("TEST FAIL PumpkinBin art is missing the chalk sign")
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
	if ResourceLoader.exists("res://assets/explore/prop_pumpkin_toss.glb"):
		var tossed := prop.call("instantiate") as Node3D
		host.add_child(tossed)
		await process_frame
		var tossed_h := _mesh_height(tossed)
		print("TEST pumpkin glb height=%.3f" % tossed_h)
		if tossed_h < 0.35 or tossed_h > 0.45:
			push_error("TEST FAIL pumpkin GLB should be 0.35–0.45 m, h=%.3f" % tossed_h)
			return false
	if not _hair_outside():
		return false
	if not _ghosts_float(world):
		return false
	if not await _pets(scene, world):
		return false
	if not await _disco(scene, world):
		return false
	if not await _batch3(scene, world):
		return false
	if not await _graveyard(scene, world):
		return false
	if not _night_sky(world):
		return false
	if not _leftover_placeholders(world):
		return false
	if not await _perimeter(world):
		return false
	if not await _pumpkin_climb(world):
		return false
	print("TEST halloween+pumpkin+ping ok")
	return true


func _hair_outside() -> bool:
	var body: Node = load("res://scripts/explore/avatar_body.gd").new()
	body.name = "HairProbe"
	root.add_child(body)
	for style in ["bangs", "wavy", "short", "bun"]:
		body.call("rebuild", {"v": 1, "hair": style, "hair_color": "brown", "skin": "peach"})
		if not bool(body.call("hair_reaches_outside")):
			push_error("TEST FAIL hair style %s stays inside the skull" % style)
			return false
	print("TEST hair reaches outside the skull")
	body.queue_free()
	return true


func _ghosts_float(world: Node) -> bool:
	var ghosts := world.get_node_or_null("PatioGhosts")
	if ghosts == null or ghosts.get_child_count() < 3:
		push_error("TEST FAIL expected a few patio ghosts")
		return false
	if ghosts.find_children("*", "StaticBody3D", true, false).size() > 0:
		push_error("TEST FAIL patio ghosts should not block walking")
		return false
	print("TEST patio ghosts=", ghosts.get_child_count())
	var smile := 0
	var oh := 0
	for child in ghosts.get_children():
		if child.find_child("FaceSmile", true, false) != null and (child.find_child("FaceSmile", true, false) as Node3D).visible:
			smile += 1
		if child.find_child("FaceOh", true, false) != null and (child.find_child("FaceOh", true, false) as Node3D).visible:
			oh += 1
	if smile != 2 or oh != 2:
		push_error("TEST FAIL ghost faces should alternate smile and oh, smile=%d oh=%d" % [smile, oh])
		return false
	var sheet := ghosts.get_child(0).find_child("Sheet", true, false) as MeshInstance3D
	if sheet and sheet.get_surface_override_material(0) is StandardMaterial3D:
		var alpha := (sheet.get_surface_override_material(0) as StandardMaterial3D).albedo_color.a
		if absf(alpha - 0.86) > 0.02:
			push_error("TEST FAIL ghost sheet alpha should stay 0.86, got %.2f" % alpha)
			return false
	ghosts.set_process(false)
	var leader := ghosts.get_child(0) as Node3D
	for ang in [0.0, 0.7, 1.15, PI * 0.5, PI, 4.2]:
		var travel := Vector3(-sin(ang) * 6.2, 0.3, cos(ang) * 6.2 * 0.82)
		ghosts.call("face_travel", leader, travel, 0.0, 0.0)
		var face := Vector3((-leader.global_transform.basis.z).x, 0.0, (-leader.global_transform.basis.z).z).normalized()
		var want := Vector3(travel.x, 0.0, travel.z).normalized()
		var dot := face.dot(want)
		if dot < 0.98:
			push_error("TEST FAIL ghost faces %.2f off travel at ang=%.2f" % [dot, ang])
			return false
	print("TEST ghost faces travel")
	return true


func _pets(scene: Node, world: Node) -> bool:
	var pets := world.get_node_or_null("PatioPets")
	if pets == null or pets.get_node_or_null("Cat") == null or pets.get_node_or_null("Dog") == null:
		push_error("TEST FAIL patio cat and dog missing")
		return false
	if pets.find_children("*", "StaticBody3D", true, false).size() > 0:
		push_error("TEST FAIL pets should not block walking")
		return false
	var player: Node = scene.get_node("Player")
	var cat := pets.get_node("Cat") as Node3D
	var dog := pets.get_node("Dog") as Node3D
	player.global_position = cat.global_position + Vector3(3.15, 0.2, 0.4)
	await physics_frame
	if player.call("nearest_pet") == null:
		push_error("TEST FAIL pickup radius should reach a pet 3 m away")
		return false
	player.global_position = Vector3(0.0, 0.2, 42.0)
	if player.call("nearest_pet") != null:
		push_error("TEST FAIL pickup radius reached too far")
		return false
	var hud := scene.get_node_or_null("HUD")
	var pet_btn := hud.find_child("PetButton", true, false) as Control if hud else null
	var pet_h := 0.0
	if pet_btn:
		pet_h = maxf(pet_btn.custom_minimum_size.y, pet_btn.offset_bottom - pet_btn.offset_top)
	if pet_btn == null or pet_h < 120.0:
		push_error("TEST FAIL Pick up button should be a large thumb target")
		return false
	player.global_position = cat.global_position + Vector3(2.4, 0.2, 0.6)
	for _i in 3:
		await process_frame
	if not pet_btn.visible or str(pet_btn.text) != "Pick up":
		push_error("TEST FAIL Pick up button should show beside a nearby pet")
		return false
	if not bool(player.call("try_pickup_pet", cat)) or not bool(player.call("holding_pet")):
		push_error("TEST FAIL could not pick up the cat")
		return false
	for _i in 4:
		await physics_frame
	if not await _pet_on_head(player, cat):
		return false
	var cookies_before := player.get_tree().get_nodes_in_group("cookie_projectile").size()
	var pumpkins_before := player.get_tree().get_nodes_in_group("pumpkin_projectile").size()
	if bool(player.call("toss_cookie")):
		push_error("TEST FAIL toss should do nothing while holding a pet")
		return false
	if player.get_tree().get_nodes_in_group("cookie_projectile").size() != cookies_before:
		push_error("TEST FAIL holding a pet spawned a cookie")
		return false
	if player.get_tree().get_nodes_in_group("pumpkin_projectile").size() != pumpkins_before:
		push_error("TEST FAIL holding a pet spawned a pumpkin toss")
		return false
	var feet: Vector3 = player.global_position
	if not bool(player.call("try_put_down_pet")) or bool(player.call("holding_pet")):
		push_error("TEST FAIL could not put the pet down")
		return false
	if cat.get("held"):
		push_error("TEST FAIL pet stayed marked held")
		return false
	var dropped := Vector2(cat.global_position.x - feet.x, cat.global_position.z - feet.z).length()
	if dropped < 0.85 or dropped > 2.4 or cat.global_position.y > 1.2:
		push_error("TEST FAIL pet was not set on the ground in front, at=%s" % str(cat.global_position))
		return false
	player.global_position = dog.global_position + Vector3(0.8, 0.2, 0.4)
	if not bool(player.call("try_pickup_pet", dog)):
		push_error("TEST FAIL could not pick up the dog")
		return false
	for _i in 3:
		await physics_frame
	if not await _pet_on_head(player, dog):
		return false
	if not bool(player.call("try_put_down_pet")):
		push_error("TEST FAIL could not put the dog down")
		return false
	print("TEST pets pickup ok")
	return true


func _pet_on_head(player: Node, pet: Node3D) -> bool:
	var avatar := player.get_node_or_null("Avatar") as Node3D
	if avatar == null:
		push_error("TEST FAIL player avatar missing while holding a pet")
		return false
	for hat in ["sun", "beanie", "none"]:
		avatar.call("rebuild", {"v": 1, "hat": hat, "hair": "bun", "hair_color": "brown", "skin": "peach"})
		for _i in 3:
			await physics_frame
		if not _pet_clears_head(avatar, pet, hat):
			return false
	return true


func _pet_clears_head(avatar: Node3D, pet: Node3D, hat: String) -> bool:
	var box := _aabb_in(pet, avatar)
	if box.size.length_squared() < 0.001:
		push_error("TEST FAIL held pet has no mesh")
		return false
	var head := avatar.call("head_node") as Node3D
	var head_box := _aabb_in(head, avatar) if head else AABB()
	var head_top := head_box.position.y + head_box.size.y
	var pet_bottom := box.position.y
	var center := box.get_center()
	print("TEST held %s hat=%s head_top=%.2f pet_bottom=%.2f center=%s" % [pet.name, hat, head_top, pet_bottom, str(center)])
	if pet_bottom < head_top + 0.02:
		push_error("TEST FAIL held %s clips the %s head, bottom=%.2f top=%.2f" % [pet.name, hat, pet_bottom, head_top])
		return false
	if pet_bottom > head_top + 0.22:
		push_error("TEST FAIL held %s floats above the %s head, bottom=%.2f top=%.2f" % [pet.name, hat, pet_bottom, head_top])
		return false
	if absf(center.x) > 0.38 or absf(center.z) > 0.38:
		push_error("TEST FAIL held %s is not sitting over the head, center=%s" % [pet.name, str(center)])
		return false
	var up := avatar.global_transform.basis.inverse() * pet.global_transform.basis.y
	if up.y < 0.9:
		push_error("TEST FAIL held %s is not sitting upright, up=%s" % [pet.name, str(up)])
		return false
	var forward := avatar.global_transform.basis.inverse() * (-pet.global_transform.basis.z)
	if forward.z > -0.9:
		push_error("TEST FAIL held %s is not facing forward, forward=%s" % [pet.name, str(forward)])
		return false
	return true


func _aabb_in(node: Node3D, space_node: Node3D) -> AABB:
	var inv := space_node.global_transform.affine_inverse()
	var box := AABB()
	var any := false
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var piece: AABB = (inv * mi.global_transform) * mi.get_aabb()
			if not any:
				box = piece
				any = true
			else:
				box = box.merge(piece)
		for child in n.get_children():
			stack.append(child)
	return box


func _disco(scene: Node, world: Node) -> bool:
	var eye := world.get_node_or_null("DiscoBullseye")
	var party := world.get_node_or_null("DiscoParty")
	if eye == null or party == null or not party.has_method("apply_until"):
		push_error("TEST FAIL disco bullseye or party missing in the test world")
		return false
	var shapes := eye.find_children("*", "CollisionShape3D", true, false)
	var hitbox := shapes[0] as CollisionShape3D if not shapes.is_empty() else null
	if hitbox == null:
		push_error("TEST FAIL disco bullseye has no collider")
		return false
	var face_at := hitbox.global_position
	var before := int(eye.get("hits"))
	var CookieScript := load("res://scripts/explore/cookie_projectile.gd")
	var bean: Node3D = CookieScript.new()
	scene.add_child(bean)
	bean.set("grace", 0.0)
	bean.global_position = face_at + Vector3(0, 0, 0.4)
	bean.set("velocity", Vector3(0, 0, -10.0))
	var tagged := false
	for _k in 24:
		await physics_frame
		if int(eye.get("hits")) > before:
			tagged = true
			break
	if not tagged:
		push_error("TEST FAIL a cookie should still hit the disco bullseye, hits=%d" % int(eye.get("hits")))
		return false
	if not party.party_on():
		push_error("TEST FAIL a bullseye hit should start the test-world party")
		return false
	for _i in 8:
		await process_frame
	var floor := party.find_child("BlushCenter", true, false) as MeshInstance3D
	var host := party.find_child("HostDancer", true, false) as Node3D
	var wash := party.find_child("DiscoWash", true, false) as ColorRect
	var music := party.find_child("DiscoMusic", true, false) as AudioStreamPlayer3D
	if floor == null or host == null or not host.visible or wash == null or not wash.visible:
		push_error("TEST FAIL disco floor, host, or wash missing")
		return false
	var floor_box := floor.global_transform * floor.get_aabb()
	var island := _find(world.get_node_or_null("ChatGPTStorefront"), "Patio_Island") as Node3D
	var island_top := 0.07
	if island:
		var island_box := _mesh_box(island)
		if island_box.size.y > 0.01:
			island_top = island_box.position.y + island_box.size.y
	var floor_bottom := floor_box.position.y
	print("TEST disco floor_bottom=%.3f island_top=%.3f wash=%s" % [floor_bottom, island_top, str(wash.color)])
	if floor_bottom < island_top + 0.02:
		push_error("TEST FAIL dance floor is inside the patio slab, bottom=%.3f top=%.3f" % [floor_bottom, island_top])
		return false
	if music == null or not music.playing:
		push_error("TEST FAIL disco music should be playing")
		return false
	var avatar := scene.get_node_or_null("Player/Avatar")
	if avatar == null or not avatar.has_method("dancing") or not avatar.dancing():
		push_error("TEST FAIL the baker should dance when the test-world party is on")
		return false
	print("TEST disco party on")
	return true


func _batch3(scene: Node, world: Node) -> bool:
	var guests := world.get_tree().get_nodes_in_group("village_npc")
	if guests.is_empty():
		push_error("TEST FAIL patio guests missing")
		return false
	var staff_apron := false
	for guest in guests:
		if guest.find_child("Torso_Top", true, false) == null:
			push_error("TEST FAIL guest %s is still the code body" % guest.name)
			return false
		var rig := guest.find_child("Rig", true, false) as Node3D
		if rig == null or absf(rig.position.y) > 0.001:
			push_error("TEST FAIL guest rig should sit at y 0")
			return false
		var apron := guest.find_child("Torso_Apron", true, false) as Node3D
		var staff := str(guest.get("outfit")) == "staff"
		if staff:
			if apron == null or not apron.visible:
				push_error("TEST FAIL staff visor should show the apron")
				return false
			staff_apron = true
		elif apron != null and apron.visible:
			push_error("TEST FAIL a non-staff guest is wearing the apron")
			return false
		if str(guest.get("pose")) == "0":
			var arm := guest.find_child("ArmL", true, false) as Node3D
			if arm and absf(arm.rotation.x) > 0.35:
				push_error("TEST FAIL authored arms should rest near 0, got %.2f" % arm.rotation.x)
				return false
	if not staff_apron:
		push_error("TEST FAIL no staff apron was visible")
		return false
	var party := world.get_node("DiscoParty")
	for need in ["FloorBase", "BlushCenter", "Tile0", "Orb0", "Beam0", "MirrorBall", "Glitter", "Hoop"]:
		if party.find_child(need, true, false) == null:
			push_error("TEST FAIL disco is missing %s" % need)
			return false
	var host_arm := party.find_child("HostDancer", true, false).find_child("ArmL", true, false) as Node3D
	if host_arm == null or host_arm.rotation.x < 0.4:
		push_error("TEST FAIL host arms should pitch forward")
		return false
	var eye := world.get_node("DiscoBullseye")
	if eye.find_child("BullseyeModel", true, false) == null or eye.find_child("FrontDisc", true, false) == null:
		push_error("TEST FAIL bullseye model missing")
		return false
	for child in eye.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh is CylinderMesh:
			push_error("TEST FAIL code bullseye pole is still visible")
			return false
	var plated := false
	for node in world.get_tree().get_nodes_in_group("menu_prop"):
		if node.has_meta("batch3_prop"):
			plated = true
			break
	if not plated:
		push_error("TEST FAIL menu props did not use the batch-3 meshes")
		return false
	var Remote := load("res://scripts/explore/remote_baker.gd")
	var remote: Node3D = Remote.new()
	world.add_child(remote)
	remote.call("setup", {"net_id": "batch3", "display_name": "Mara", "x": 1.2, "y": 0.02, "z": 2.0})
	await process_frame
	var hand := remote.find_child("HandSocket", true, false)
	if hand == null or hand.find_child("HandCookie", true, false) == null:
		push_error("TEST FAIL remote hand should hold the cookie GLB")
		return false
	if hand.find_child("CookieMesh", true, false) == null:
		push_error("TEST FAIL remote cookie mesh missing")
		return false
	var plate := remote.find_child("Nameplate", true, false)
	if plate == null or not plate is Label3D:
		push_error("TEST FAIL remote nameplate should stay a Label3D")
		return false
	remote.queue_free()
	print("TEST batch3 guests+disco+menu+remote cookie")
	return true


func _graveyard(scene: Node, world: Node) -> bool:
	var yard := world.get_node_or_null("Graveyard") as Node3D
	if yard == null or yard.get_node_or_null("HeadlessHorseman") == null:
		push_error("TEST FAIL graveyard or horseman missing")
		return false
	if yard.find_children("Tombstone*", "", true, false).size() < 4:
		push_error("TEST FAIL graveyard needs tombstones")
		return false
	for art_name in ["GraveyardGround", "GraveyardStones", "GraveyardFence", "DeadTreeA", "DeadTreeB"]:
		if yard.get_node_or_null(art_name) == null:
			push_error("TEST FAIL graveyard missing %s" % art_name)
			return false
	if yard.get_node_or_null("FenceRailGap0") == null or yard.get_node_or_null("FenceRailGap1") == null:
		push_error("TEST FAIL graveyard gate rails should be the two short spans")
		return false
	var tree_a := yard.get_node("DeadTreeA") as Node3D
	var tree_b := yard.get_node("DeadTreeB") as Node3D
	if tree_a.position.distance_to(Vector3(-8.8, 0, -2.4)) > 0.05 or absf(tree_a.scale.x - 1.0) > 0.02:
		push_error("TEST FAIL dead tree A drifted")
		return false
	if tree_b.position.distance_to(Vector3(6.4, 0, -7.2)) > 0.05 or absf(tree_b.scale.x - 0.8) > 0.02:
		push_error("TEST FAIL dead tree B drifted")
		return false
	var at := yard.global_position
	if Vector2(at.x, at.z).length() < 70.0 or at.distance_to(Vector3(72, 0, 78)) < 80.0:
		push_error("TEST FAIL graveyard is too close to the patio or the giant pumpkin, pos=%s" % str(at))
		return false
	var player: Node = scene.get_node("Player")
	player.global_position = at + Vector3(1.2, 0.2, 0.4)
	var before := player.get_tree().get_nodes_in_group("cookie_projectile").size()
	if not bool(yard.call("throw_cookie")):
		push_error("TEST FAIL horseman did not throw a cookie")
		return false
	var shots := player.get_tree().get_nodes_in_group("cookie_projectile")
	var shot: Node = null
	for item in shots:
		if str(item.get("owner_net_id")) == "horseman":
			shot = item
			break
	if shot == null:
		push_error("TEST FAIL horseman cookie missing")
		return false
	var cookie_mesh := shot.get_node_or_null("Cookie") as Node3D
	if cookie_mesh == null or cookie_mesh.find_child("CookieMesh", true, false) == null or cookie_mesh.scale.distance_to(Vector3.ONE) > 0.02:
		push_error("TEST FAIL test-world cookie should be the GLB at scale 1")
		return false
	if not bool(shot.get("hits_local")) or str(shot.get("owner_net_id")) != "horseman":
		push_error("TEST FAIL horseman cookie should reuse the local hit path")
		return false
	player.global_position = Vector3(0, 0.2, 11)
	for item in shots:
		if str(item.get("owner_net_id")) == "horseman":
			item.queue_free()
	yard.set_physics_process(false)
	yard.call("_sync_hit_shapes")
	await physics_frame
	if not await _horseman_hit_fits(yard):
		return false
	var hits_before := int(yard.get("hits_taken"))
	var Cookie := load("res://scripts/explore/cookie_projectile.gd")
	var tossed: Node3D = Cookie.new()
	tossed.set("owner_net_id", "player")
	tossed.set("grace", 0.0)
	var aim: Vector3 = yard.call("cookie_aim_point")
	world.add_child(tossed)
	tossed.global_position = aim + Vector3(1.4, 0.15, 0.2)
	tossed.set("velocity", Vector3(-8.0, 0.4, 0.0))
	var tagged := false
	for _i in 25:
		await physics_frame
		if int(yard.get("hits_taken")) > hits_before:
			tagged = true
			break
	if not tagged:
		push_error("TEST FAIL player cookie did not hit the horseman, hits=%s" % str(yard.get("hits_taken")))
		return false
	for item in player.get_tree().get_nodes_in_group("cookie_projectile"):
		item.queue_free()
	await physics_frame
	if not await _horseman_miss_and_hoof(world, yard):
		return false
	print("TEST graveyard horseman ok pos=%s hits=%s" % [str(at), str(yard.get("hits_taken"))])
	return true


func _horseman_hit_fits(yard: Node3D) -> bool:
	var rider := yard.get_node("HeadlessHorseman") as Node3D
	var hit := rider.find_child("HorsemanHit", true, false) as StaticBody3D
	if hit == null:
		push_error("TEST FAIL HorsemanHit missing")
		return false
	var shapes := hit.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() < 8:
		push_error("TEST FAIL horseman should have a shape per mesh part, got %d" % shapes.size())
		return false
	for col in shapes:
		var box := (col as CollisionShape3D).shape as BoxShape3D
		if box and box.size.distance_to(Vector3(1.25, 1.25, 2.25)) < 0.05:
			push_error("TEST FAIL horseman still uses the old oversized hit box")
			return false
	var leg := rider.find_child("LegFL", true, false) as Node3D
	var leg_shape := hit.find_child("Hit_LegFL", true, false) as CollisionShape3D
	if leg == null or leg_shape == null:
		push_error("TEST FAIL horseman leg hit shape missing")
		return false
	leg.rotation.x = 0.0
	yard.call("_sync_hit_shapes")
	var before := leg_shape.global_position
	leg.rotation.x = 0.6
	yard.call("_sync_hit_shapes")
	if leg_shape.global_position.distance_to(before) < 0.08:
		push_error("TEST FAIL horseman hit shape did not follow the leg")
		return false
	leg.rotation.x = 0.0
	yard.call("_sync_hit_shapes")
	await physics_frame
	var space := yard.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	var chest: Vector3 = rider.to_global(Vector3(0.0, 1.45, 0.0))
	var empty: Vector3 = rider.to_global(Vector3(1.8, 1.45, 0.0))
	if not _point_hits_horseman(space, chest):
		push_error("TEST FAIL horseman chest is not inside the hit shapes")
		return false
	if _point_hits_horseman(space, empty):
		push_error("TEST FAIL empty air beside the horseman still counts as a hit")
		return false
	print("TEST horseman hit shapes=%d" % shapes.size())
	return true


func _point_hits_horseman(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = 1
	for row in space.intersect_point(query, 8):
		var col: Object = row.get("collider")
		if col is Node and _has_ancestor(col as Node, "HorsemanHit"):
			return true
	return false


func _has_ancestor(node: Node, ancestor_name: String) -> bool:
	var n: Node = node
	while n:
		if str(n.name) == ancestor_name or n.name.begins_with(ancestor_name):
			return true
		n = n.get_parent()
	return false


func _horseman_miss_and_hoof(world: Node, yard: Node) -> bool:
	var rider := yard.get_node("HeadlessHorseman") as Node3D
	var aim: Vector3 = yard.call("cookie_aim_point")
	var side := rider.global_transform.basis.x.normalized()
	var before := int(yard.get("hits_taken"))
	if await _fly_cookie(world, aim + side * 1.8, side * 4.0):
		push_error("TEST FAIL cookie in empty air beside the horse still scored")
		return false
	if int(yard.get("hits_taken")) != before:
		push_error("TEST FAIL empty miss changed the hit count")
		return false
	var hoof := rider.find_child("Hit_LegBL", true, false) as CollisionShape3D
	if hoof == null or hoof.shape == null:
		push_error("TEST FAIL back hoof hit shape missing")
		return false
	var box := hoof.shape as BoxShape3D
	var away := hoof.global_position - rider.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = hoof.global_transform.basis.x
	away = away.normalized()
	var reach := maxf(box.size.x, box.size.z) * 0.5 + 0.28
	var start := hoof.global_position + away * reach
	if not await _fly_cookie(world, start, (hoof.global_position - start).normalized() * 7.0):
		push_error("TEST FAIL cookie into the hoof did not score")
		return false
	print("TEST horseman miss stays empty and hoof scores")
	return true


func _fly_cookie(world: Node, from: Vector3, velocity: Vector3) -> bool:
	var Cookie := load("res://scripts/explore/cookie_projectile.gd")
	var tossed: Node3D = Cookie.new()
	tossed.set("owner_net_id", "player")
	tossed.set("grace", 0.0)
	world.add_child(tossed)
	tossed.global_position = from
	tossed.set("velocity", velocity)
	var yard := world.get_node("Graveyard")
	var before := int(yard.get("hits_taken"))
	var scored := false
	for _i in 10:
		await physics_frame
		if int(yard.get("hits_taken")) > before:
			scored = true
			break
	if is_instance_valid(tossed):
		tossed.queue_free()
	return scored


func _leftover_placeholders(world: Node) -> bool:
	## Visible code primitives whose center sits inside an authored GLB.
	## The stair slabs were this bug: Godot renames duplicate siblings, so a
	## first-name hide left the rest drawing on top of the model.
	var boxes: Array[AABB] = []
	for node in world.get_tree().get_nodes_in_group("authored_glb"):
		if not node is Node3D:
			continue
		var box := _mesh_box(node as Node3D)
		if box.size.length() > 0.05:
			boxes.append(box)
	var offenders: PackedStringArray = []
	var stack: Array = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if _authored_ancestor(n):
			continue
		if n is MeshInstance3D and (n as MeshInstance3D).visible and _primitive_mesh(n as MeshInstance3D):
			if not _placeholder_allowed(n):
				var mi := n as MeshInstance3D
				var piece: AABB = mi.global_transform * mi.get_aabb()
				var center := piece.get_center()
				for box in boxes:
					if box.grow(0.08).has_point(center):
						offenders.append(str(n.get_path()))
						break
		for child in n.get_children():
			stack.append(child)
	print("TEST leftover placeholders overlapping GLBs=%d authored=%d" % [offenders.size(), boxes.size()])
	for path in offenders:
		push_error("TEST FAIL leftover placeholder mesh " + path)
	return offenders.is_empty()


func _authored_ancestor(node: Node) -> bool:
	var n: Node = node
	while n:
		if n.is_in_group("authored_glb"):
			return true
		n = n.get_parent()
	return false


func _primitive_mesh(mi: MeshInstance3D) -> bool:
	var mesh := mi.mesh
	return mesh is BoxMesh or mesh is CylinderMesh or mesh is SphereMesh or mesh is CapsuleMesh or mesh is PrismMesh or mesh is QuadMesh


func _placeholder_allowed(node: Node) -> bool:
	if str(node.name).begins_with("Fog"):
		return true
	var n: Node = node
	while n:
		var nm := str(n.name)
		if nm == "DiscoParty" or nm == "WelcomeSign" or nm == "Player" or nm == "PerimeterWall" or nm == "ChatGPTStorefront":
			return true
		if nm.begins_with("Guest") or n.is_in_group("village_npc"):
			return true
		if n.is_in_group("cookie_projectile") or n.is_in_group("pumpkin_projectile"):
			return true
		n = n.get_parent()
	return false


func _perimeter(world: Node) -> bool:
	var wall := world.get_node_or_null("PerimeterWall") as Node3D
	if wall == null:
		push_error("TEST FAIL perimeter wall missing")
		return false
	for gate_name in ["GateNorth", "GateEast", "GateSouth", "GateWest"]:
		var gate := wall.get_node_or_null(gate_name) as Node3D
		if gate == null or gate.get_node_or_null("GateBlock") == null:
			push_error("TEST FAIL %s should be a closed gate" % gate_name)
			return false
		var visual := gate.find_child("GrandGate", true, false) as Node3D
		if visual == null or visual.scale.distance_to(Vector3.ONE) > 0.01:
			push_error("TEST FAIL %s should instance grand_gate at scale 1" % gate_name)
			return false
		for part in ["DoorL", "DoorR", "Portcullis", "Crossbar"]:
			var piece := visual.find_child(part, true, false) as Node3D
			if piece == null:
				push_error("TEST FAIL %s is missing %s" % [gate_name, part])
				return false
			if absf(piece.rotation.y) > 0.05:
				push_error("TEST FAIL %s %s should stay closed" % [gate_name, part])
				return false
			if part == "Portcullis" and absf(piece.position.y) > 0.05:
				push_error("TEST FAIL %s portcullis should stay down" % gate_name)
				return false
		if gate.find_child("DoorLeft", true, false) != null or gate.find_child("Torch", true, false) != null:
			push_error("TEST FAIL %s still has the code-built door" % gate_name)
			return false
		var glow_ok := false
		for side in ["LightL", "LightR"]:
			var socket := visual.find_child(side, true, false) as Node3D
			var lamp: OmniLight3D = null
			if socket:
				for child in socket.get_children():
					if child is OmniLight3D:
						lamp = child
			if lamp == null or lamp.omni_range < 8.0 or lamp.omni_range > 10.0:
				push_error("TEST FAIL %s %s needs a warm lamp" % [gate_name, side])
				return false
			if lamp.light_color.r < 0.9 or lamp.light_color.b > 0.35:
				push_error("TEST FAIL %s lamp is not ff8a28" % gate_name)
				return false
		var mesh_stack: Array = [visual]
		while not mesh_stack.is_empty():
			var mesh_node: Node = mesh_stack.pop_back()
			if mesh_node is MeshInstance3D:
				var mi := mesh_node as MeshInstance3D
				if mi.mesh:
					for surf in mi.mesh.get_surface_count():
						var src := mi.mesh.surface_get_material(surf)
						if src and str(src.resource_name) == "M_grand_gate_glow":
							var mat := mi.get_surface_override_material(surf) as StandardMaterial3D
							if mat and mat.emission_enabled and mat.albedo_color.r > 0.9:
								glow_ok = true
			for mesh_child in mesh_node.get_children():
				mesh_stack.append(mesh_child)
		if not glow_ok:
			push_error("TEST FAIL %s glow was night-tinted" % gate_name)
			return false
		for child in gate.get_children():
			if child is MeshInstance3D or child is OmniLight3D:
				push_error("TEST FAIL %s mixed a mesh or light into the gate root" % gate_name)
				return false
	var north := wall.get_node("GateNorth") as Node3D
	var south := wall.get_node("GateSouth") as Node3D
	if north.global_position.z > -90.0 or south.global_position.z < 90.0:
		push_error("TEST FAIL gates are not on the outer rim")
		return false
	if absf(north.global_position.x) > 1.0 or absf(south.global_position.x) > 1.0:
		push_error("TEST FAIL north and south gates should sit mid-wall")
		return false
	var east := wall.get_node("GateEast") as Node3D
	if east.global_position.x < 90.0 or absf(east.global_position.z) > 1.0:
		push_error("TEST FAIL east gate is not mid-wall on the rim")
		return false
	await physics_frame
	var space := world.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	if not _ray_hits_wall(space, Vector3(0, 2, -70), Vector3(0, 2, -160)):
		push_error("TEST FAIL ground-level ray walked through the north gate")
		return false
	if not _ray_hits_wall(space, Vector3(0, 30, -70), Vector3(0, 30, -160)):
		push_error("TEST FAIL a jump at y=30 crossed the north wall")
		return false
	if not _ray_hits_wall(space, Vector3(72, 36, 96), Vector3(72, 36, 160)):
		push_error("TEST FAIL the pumpkin deck can see over the south wall")
		return false
	if not _ray_hits_wall(space, Vector3(40, 2, 0), Vector3(160, 2, 0)):
		push_error("TEST FAIL ground-level ray walked through the east wall")
		return false
	var border := world.get_node_or_null("PhotoBorders")
	if border == null:
		push_error("TEST FAIL photo borders missing beside the new wall")
		return false
	print("TEST perimeter wall gates=4 seal holds at y=30")
	return true


func _ray_hits_wall(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return false
	var col: Object = hit.get("collider")
	return col is Node and _has_ancestor(col as Node, "PerimeterWall")


func _night_sky(world: Node) -> bool:
	if world.get_node_or_null("LogoSun") != null:
		push_error("TEST FAIL test world should use the logo moon, not the day sun")
		return false
	var moon := world.get_node_or_null("LogoMoon") as Node3D
	if moon == null or moon.global_position.y < 20.0:
		push_error("TEST FAIL logo moon missing from the night sky")
		return false
	if moon.find_child("LogoDisc", true, false) == null or moon.find_child("MoonLight", true, false) == null:
		push_error("TEST FAIL logo moon needs the bakery disc and a soft light")
		return false
	if moon.find_child("MoonHalo", true, false) == null or moon.find_child("LogoMoonArt", true, false) == null:
		push_error("TEST FAIL logo moon art or halo missing")
		return false
	var found_env := false
	for child in world.get_children():
		if child is WorldEnvironment and (child as WorldEnvironment).environment:
			found_env = true
			var env := (child as WorldEnvironment).environment
			if env.ambient_light_energy > 0.32 or env.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
				push_error("TEST FAIL night ambient is still daytime, energy=%.2f" % env.ambient_light_energy)
				return false
			if env.glow_enabled:
				push_error("TEST FAIL night sky should not enable glow")
				return false
	if not found_env:
		push_error("TEST FAIL night world environment missing")
		return false
	if world.get_node_or_null("PlayerFill") == null:
		push_error("TEST FAIL player fill light missing")
		return false
	print("TEST night logo moon y=%.1f" % moon.global_position.y)
	return true


func _stairs_match_authored(pumpkin: Node3D, pts: PackedVector3Array) -> bool:
	var path := "res://assets/explore/halloween/stairs_walk.json"
	if not FileAccess.file_exists(path):
		return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("TEST FAIL stairs_walk.json did not parse")
		return false
	var data: Dictionary = parsed
	var expect: Array = data.get("walk_points", [])
	if expect.size() != pts.size():
		push_error("TEST FAIL stair walk count %d != authored %d" % [pts.size(), expect.size()])
		return false
	var deck := float(data.get("deck_top", 0.0))
	if absf(float(pumpkin.get("deck_top")) - deck) > 0.08:
		push_error("TEST FAIL deck_top %.3f != authored %.3f" % [float(pumpkin.get("deck_top")), deck])
		return false
	var worst := 0.0
	for i in pts.size():
		var row: Array = expect[i]
		var want := Vector3(float(row[0]), float(row[1]), float(row[2]))
		worst = maxf(worst, pts[i].distance_to(want))
	print("TEST stairs walk points=%d deck=%.2f worst=%.3f" % [pts.size(), float(pumpkin.get("deck_top")), worst])
	if worst > 0.15:
		push_error("TEST FAIL stair path drifted from pumpkin_stairs.glb, worst=%.3f" % worst)
		return false
	var hidden := 0
	var still_visible := 0
	var bodies := 0
	var stack: Array = [pumpkin]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			bodies += 1
		if n is MeshInstance3D and bool(n.get_meta("procedural_stair", false)):
			if (n as MeshInstance3D).visible:
				still_visible += 1
			else:
				hidden += 1
		for child in n.get_children():
			stack.append(child)
	print("TEST stair code meshes hidden=%d visible=%d bodies=%d" % [hidden, still_visible, bodies])
	if hidden < 100 or still_visible != 0:
		push_error("TEST FAIL code stair meshes should hide behind the stair GLB, hidden=%d visible=%d" % [hidden, still_visible])
		return false
	if bodies < 50:
		push_error("TEST FAIL stair colliders were removed, bodies=%d" % bodies)
		return false
	if pumpkin.find_child("PumpkinStairs", true, false) == null:
		push_error("TEST FAIL pumpkin stair visual missing")
		return false
	return true


func _pumpkin_climb(world: Node) -> bool:
	var pumpkin := world.get_node_or_null("GiantPumpkin") as Node3D
	if pumpkin == null:
		push_error("TEST FAIL giant pumpkin missing")
		return false
	if pumpkin.get_node_or_null("CarvedPumpkin") == null:
		push_error("TEST FAIL giant pumpkin should be the carved jack-o'-lantern")
		return false
	if pumpkin.get_node_or_null("TossPumpkin") != null:
		push_error("TEST FAIL giant pumpkin is still the scaled toss prop")
		return false
	if pumpkin.find_child("JackLight", true, false) == null:
		push_error("TEST FAIL carved pumpkin is missing its glow light")
		return false
	var place := pumpkin.global_position
	if absf(place.x - 72.0) > 0.2 or absf(place.z - 78.0) > 0.2:
		push_error("TEST FAIL giant pumpkin drifted, pos=%s" % str(place))
		return false
	var top := _mesh_box(pumpkin).position.y + _mesh_box(pumpkin).size.y
	print("TEST giant pumpkin top y=%.2f" % top)
	if top < 29.0 or top > 32.0:
		push_error("TEST FAIL giant pumpkin should be about 30 m, top=%.2f" % top)
		return false
	var deck := pumpkin.find_child("PumpkinDeck", true, false) as Node3D
	if deck == null or pumpkin.to_global(deck.position).y < 24.0:
		push_error("TEST FAIL pumpkin deck collider is not at the top")
		return false
	if pumpkin.find_children("RampRail*", "StaticBody3D", true, false).size() < 20:
		push_error("TEST FAIL spiral is missing railings")
		return false
	if pumpkin.find_children("DeckRail*", "StaticBody3D", true, false).size() < 8:
		push_error("TEST FAIL deck is missing railings")
		return false
	var pts: PackedVector3Array = pumpkin.walk_points
	if pts.size() < 40:
		push_error("TEST FAIL pumpkin walk path is too short")
		return false
	if not _stairs_match_authored(pumpkin, pts):
		return false
	var ribs: PackedVector3Array = pumpkin.rib_points
	if ribs.size() < 8 or pumpkin.get_node_or_null("PumpkinWalk") == null:
		push_error("TEST FAIL pumpkin is missing a walkable body")
		return false
	var side: Vector3 = ribs[ribs.size() / 2]
	if not await _rest_probe(world, pumpkin.to_global(side) + Vector3(0, 0.35, 0), side.y - 0.4, "pumpkin side"):
		return false
	var crown: Vector3 = pumpkin.crown_stand_local()
	if not await _rest_probe(world, pumpkin.to_global(crown), 18.0, "pumpkin crown"):
		return false
	var hop_from: Vector3 = pumpkin.to_global(ribs[4]) + Vector3(0, 0.3, 0)
	var hop_to: Vector3 = pumpkin.to_global(ribs[5])
	if not await _hop_probe(world, hop_from, hop_to):
		return false
	var climber := CharacterBody3D.new()
	climber.name = "PumpkinClimber"
	climber.floor_snap_length = 0.55
	climber.floor_max_angle = deg_to_rad(52.0)
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.24
	cap.shape = shape
	cap.position = Vector3(0, 0.62, 0)
	climber.add_child(cap)
	var scr := GDScript.new()
	scr.source_code = """extends CharacterBody3D
var host: Node3D
var idx := 0
var done := false
var stuck := 0
func _physics_process(delta: float) -> void:
	if done or host == null:
		return
	var pts: PackedVector3Array = host.walk_points
	var target := host.to_global(pts[idx])
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 1.05 and idx < pts.size() - 1:
		idx += 1
		stuck = 0
		target = host.to_global(pts[idx])
		flat = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if idx >= pts.size() - 1 and flat.length() < 1.4 and global_position.y > 26.0:
		done = true
		return
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 28.0 * delta
	velocity.x = dir.x * 6.5
	velocity.z = dir.z * 6.5
	var before := global_position
	move_and_slide()
	if global_position.distance_to(before) < 0.015:
		stuck += 1
	else:
		stuck = 0
"""
	scr.reload()
	climber.set_script(scr)
	climber.set("host", pumpkin)
	var start := pumpkin.to_global(pts[0]) + Vector3(0, 0.2, 0)
	world.add_child(climber)
	climber.global_position = start
	var climbed := false
	for _i in 5200:
		await physics_frame
		if bool(climber.get("done")):
			climbed = true
			break
		if int(climber.get("stuck")) > 80:
			break
		if climber.global_position.y < -1.0:
			break
	print("TEST pumpkin climb y=%.2f idx=%s on_floor=%s" % [climber.global_position.y, str(climber.get("idx")), climber.is_on_floor()])
	if not climbed or climber.global_position.y < 26.0:
		push_error("TEST FAIL climber did not reach the pumpkin deck, y=%.2f idx=%s" % [climber.global_position.y, str(climber.get("idx"))])
		return false
	print("TEST giant pumpkin climb ok")
	climber.queue_free()
	return true


func _rest_probe(world: Node, at: Vector3, min_y: float, label: String) -> bool:
	var body := _walker()
	body.name = "RestProbe"
	var scr := GDScript.new()
	scr.source_code = """extends CharacterBody3D
func _physics_process(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 28.0 * delta
	move_and_slide()
"""
	scr.reload()
	body.set_script(scr)
	world.add_child(body)
	body.global_position = at
	var grounded := false
	for _i in 90:
		await physics_frame
		if body.is_on_floor() and body.global_position.y >= min_y:
			grounded = true
			break
		if body.global_position.y < -1.0:
			break
	print("TEST %s rest y=%.2f on_floor=%s" % [label, body.global_position.y, body.is_on_floor()])
	if not grounded:
		push_error("TEST FAIL %s did not hold a body, y=%.2f" % [label, body.global_position.y])
		body.queue_free()
		return false
	body.queue_free()
	return true


func _hop_probe(world: Node, start: Vector3, target: Vector3) -> bool:
	var body := _walker()
	body.name = "HopProbe"
	var scr := GDScript.new()
	scr.source_code = """extends CharacterBody3D
var goal := Vector3.ZERO
var hopped := false
func _physics_process(delta: float) -> void:
	var flat := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var dir := flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	if is_on_floor():
		velocity.x = dir.x * 4.4
		velocity.z = dir.z * 4.4
		if goal.y > global_position.y + 0.35 and flat.length() < 1.6:
			velocity.y = 8.6
			hopped = true
		else:
			velocity.y = 0.0
	else:
		velocity.y -= 28.0 * delta
		velocity.x = dir.x * 4.4
		velocity.z = dir.z * 4.4
	move_and_slide()
"""
	scr.reload()
	body.set_script(scr)
	body.set("goal", target)
	world.add_child(body)
	body.global_position = start
	var landed := false
	for _i in 80:
		await physics_frame
		if body.global_position.y > start.y + 0.45 and body.is_on_floor():
			landed = true
			break
	print("TEST pumpkin hop y=%.2f hopped=%s" % [body.global_position.y, str(body.get("hopped"))])
	if not landed:
		push_error("TEST FAIL could not jump onto the next pumpkin rib, y=%.2f" % body.global_position.y)
		body.queue_free()
		return false
	body.queue_free()
	return true


func _walker() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.55
	body.floor_max_angle = deg_to_rad(52.0)
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.24
	cap.shape = shape
	cap.position = Vector3(0, 0.62, 0)
	body.add_child(cap)
	return body


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


func _find_prefix(root_node: Node, prefix: String) -> Node:
	if root_node == null:
		return null
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if str(n.name).begins_with(prefix):
			return n
		for child in n.get_children():
			stack.append(child)
	return null


func _mesh_box(root_node: Node3D) -> AABB:
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
	return box


func _mesh_height(root_node: Node3D) -> float:
	return _mesh_box(root_node).size.y
