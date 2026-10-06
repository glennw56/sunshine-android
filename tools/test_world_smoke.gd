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
	if world.get_node_or_null("PatioPets") != null or world.get_node_or_null("Graveyard") != null:
		push_error("TEST FAIL production explore spawned pets or the graveyard")
		return false
	if world.get_node_or_null("LogoSun") == null or world.get_node_or_null("LogoMoon") != null:
		push_error("TEST FAIL production explore should keep the day logo sun")
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
	if practice < 3:
		push_error("TEST FAIL expected 3 practice targets, got %d" % practice)
		return false
	var bin := world.get_node("PumpkinBin") as Node3D
	if absf(bin.position.x - 8.0) > 0.2 or absf(bin.position.z - 31.0) > 0.2:
		push_error("TEST FAIL pumpkin bin drifted, pos=%s" % str(bin.position))
		return false
	var bin_art := bin.get_node_or_null("PumpkinBinArt")
	if bin_art == null or _find_prefix(bin_art, "Rim") == null:
		push_error("TEST FAIL PumpkinBin art is missing the open rim")
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
	if not await _graveyard(scene, world):
		return false
	if not _night_sky(world):
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


func _graveyard(scene: Node, world: Node) -> bool:
	var yard := world.get_node_or_null("Graveyard") as Node3D
	if yard == null or yard.get_node_or_null("HeadlessHorseman") == null:
		push_error("TEST FAIL graveyard or horseman missing")
		return false
	if yard.find_children("Tombstone*", "", true, false).size() < 4:
		push_error("TEST FAIL graveyard needs tombstones")
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
	if not bool(shot.get("hits_local")) or str(shot.get("owner_net_id")) != "horseman":
		push_error("TEST FAIL horseman cookie should reuse the local hit path")
		return false
	player.global_position = Vector3(0, 0.2, 11)
	for item in shots:
		if str(item.get("owner_net_id")) == "horseman":
			item.queue_free()
	await physics_frame
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
	print("TEST graveyard horseman ok pos=%s hits=%s" % [str(at), str(yard.get("hits_taken"))])
	return true


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
