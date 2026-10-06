extends Node3D
## Far test-world graveyard and the Headless Horseman.
## He stays on a loop inside the fence and only throws while a player is in the yard.

const CookieScript := preload("res://scripts/explore/cookie_projectile.gd")
const PLACE := Vector3(-84.0, 0.0, -58.0)
const YARD_R := 9.2
const COOLDOWN := 2.8

var _horseman: Node3D
var _lantern: Node3D
var _angle := 0.4
var _cool := 0.8
var _legs: Array[Node3D] = []


func _ready() -> void:
	name = "Graveyard"
	position = PLACE
	add_to_group("graveyard")
	_ground()
	_fence()
	_stones()
	_trees()
	_fog()
	_horseman = _rider()
	add_child(_horseman)
	var glow := OmniLight3D.new()
	glow.name = "YardGlow"
	glow.position = Vector3(0, 2.4, 0)
	glow.light_color = Color("9eb4cc")
	glow.light_energy = 0.42
	glow.omni_range = 14.0
	glow.shadow_enabled = false
	add_child(glow)


func contains_point(point: Vector3) -> bool:
	var flat := point - global_position
	return Vector2(flat.x, flat.z).length() <= YARD_R


func throw_cookie() -> bool:
	var player := get_tree().get_first_node_in_group("local_baker") as Node3D
	if player == null or _lantern == null:
		return false
	var cookie: Node3D = CookieScript.new()
	cookie.set("hits_local", true)
	cookie.set("owner_net_id", "horseman")
	cookie.set("grace", 0.05)
	cookie.set("life", 3.4)
	cookie.set("proj_id", "hh_%d" % Time.get_ticks_msec())
	var world := get_parent()
	if world == null:
		return false
	world.add_child(cookie)
	var from := _lantern.global_position
	var to := player.global_position + Vector3(0, 0.9, 0)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dist := maxf(flat.length(), 0.4)
	var speed := clampf(dist * 1.15, 9.0, 16.0)
	var travel := dist / speed
	var vy := (to.y - from.y) / travel + 0.5 * 9.0 * travel
	cookie.global_position = from
	cookie.set("velocity", flat.normalized() * speed + Vector3(0, vy, 0))
	if player.has_method("_on_cookie_impact"):
		cookie.connect("impacted", Callable(player, "_on_cookie_impact"))
	return true


func _process(delta: float) -> void:
	_angle += delta * 0.62
	var radius := 5.05
	_horseman.position = Vector3(cos(_angle) * radius, 0.0, sin(_angle) * radius * 0.86)
	var ahead := _angle + 0.45
	var next := Vector3(cos(ahead) * radius, 0.0, sin(ahead) * radius * 0.86)
	_horseman.look_at(to_global(next), Vector3.UP)
	var gallop := sin(Time.get_ticks_msec() * 0.011)
	for i in _legs.size():
		var swing := gallop if i % 2 == 0 else -gallop
		_legs[i].rotation.x = swing * 0.6
	var cloak := _horseman.get_node_or_null("Cloak") as Node3D
	if cloak:
		cloak.rotation.z = sin(Time.get_ticks_msec() * 0.003) * 0.07
	for puff in get_children():
		if str(puff.name).begins_with("Fog"):
			var bob := sin(Time.get_ticks_msec() * 0.001 + puff.position.x) * 0.12
			puff.position.y = 0.7 + bob
	_cool = maxf(0.0, _cool - delta)
	if _cool > 0.0:
		return
	var player := get_tree().get_first_node_in_group("local_baker") as Node3D
	if player == null or not contains_point(player.global_position):
		return
	if throw_cookie():
		_cool = COOLDOWN


func _rider() -> Node3D:
	var root := Node3D.new()
	root.name = "HeadlessHorseman"
	var black := _mat(Color("1c1e24"))
	var cloak_c := _mat(Color("2a1840"))
	var mane := _mat(Color("121318"))
	_ball(root, 0.34, black, Vector3(0, 1.05, 0.05), Vector3(1.7, 0.72, 0.62))
	_cyl(root, 0.1, 0.12, 0.42, black, Vector3(0, 1.45, -0.42), Vector3(-0.7, 0, 0))
	_ball(root, 0.16, black, Vector3(0, 1.62, -0.72), Vector3(0.7, 0.85, 1.25))
	_ball(root, 0.05, mane, Vector3(-0.08, 1.78, -0.7))
	_ball(root, 0.05, mane, Vector3(0.08, 1.78, -0.7))
	_ball(root, 0.06, mane, Vector3(0, 1.35, -0.15), Vector3(0.4, 1.1, 0.5))
	_ball(root, 0.06, mane, Vector3(0, 1.28, 0.15), Vector3(0.35, 0.9, 0.45))
	_leg(root, Vector3(-0.18, 1.0, -0.28))
	_leg(root, Vector3(0.18, 1.0, -0.28))
	_leg(root, Vector3(-0.18, 1.0, 0.32))
	_leg(root, Vector3(0.18, 1.0, 0.32))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 1.15, 0.55)
	root.add_child(tail)
	_ball(tail, 0.06, mane, Vector3(0, -0.05, 0.12), Vector3(0.4, 0.5, 1.4))
	var cloak := Node3D.new()
	cloak.name = "Cloak"
	cloak.position = Vector3(0, 1.72, -0.05)
	root.add_child(cloak)
	_ball(cloak, 0.28, cloak_c, Vector3(0, 0.05, 0.05), Vector3(0.85, 1.15, 0.55))
	_cyl(cloak, 0.22, 0.08, 0.7, cloak_c, Vector3(0, -0.28, 0.08))
	var arm := _cyl(cloak, 0.06, 0.07, 0.55, cloak_c, Vector3(0.2, 0.35, -0.15), Vector3(-1.1, 0.2, -0.4))
	arm.name = "RaisedArm"
	_lantern = _lantern_mesh()
	_lantern.position = Vector3(0.28, 0.72, -0.42)
	cloak.add_child(_lantern)
	return root


func _lantern_mesh() -> Node3D:
	var root := Node3D.new()
	root.name = "Lantern"
	var orange := _mat(Color("ff8a28"))
	orange.emission_enabled = true
	orange.emission = Color("ff6a18")
	orange.emission_energy_multiplier = 1.6
	_ball(root, 0.16, orange, Vector3.ZERO, Vector3(1.05, 0.9, 1.0))
	var eye := _mat(Color("1a100c"))
	_ball(root, 0.035, eye, Vector3(-0.06, 0.03, -0.13), Vector3(0.7, 0.7, 0.3))
	_ball(root, 0.035, eye, Vector3(0.06, 0.03, -0.13), Vector3(0.7, 0.7, 0.3))
	_ball(root, 0.04, eye, Vector3(0, -0.06, -0.14), Vector3(1.4, 0.45, 0.3))
	_cyl(root, 0.03, 0.04, 0.08, _mat(Color("3d6b32")), Vector3(0, 0.16, 0))
	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = Color("ff8a32")
	light.light_energy = 1.15
	light.omni_range = 5.5
	light.shadow_enabled = false
	root.add_child(light)
	return root


func _leg(root: Node3D, hip: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = hip
	root.add_child(pivot)
	_cyl(pivot, 0.06, 0.07, 0.55, _mat(Color("1c1e24")), Vector3(0, -0.28, 0))
	_legs.append(pivot)


func _ground() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 8.4
	mesh.bottom_radius = 8.4
	mesh.height = 0.06
	mesh.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.name = "YardDirt"
	mi.mesh = mesh
	mi.position = Vector3(0, 0.03, 0)
	mi.material_override = _mat(Color("2a241e"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _fence() -> void:
	var gate := atan2(-PLACE.z, -PLACE.x)
	var posts := 16
	for i in posts:
		var ang := TAU * float(i) / float(posts)
		if absf(wrapf(ang - gate, -PI, PI)) < 0.42:
			continue
		var pos := Vector3(cos(ang) * 7.6, 0.0, sin(ang) * 6.4)
		_post(pos)
		var ang2 := TAU * float((i + 1) % posts) / float(posts)
		if absf(wrapf(ang2 - gate, -PI, PI)) < 0.42:
			continue
		var pos2 := Vector3(cos(ang2) * 7.6, 0.0, sin(ang2) * 6.4)
		_rail(pos, pos2)
	var left := gate - 0.48
	var right := gate + 0.48
	_post(Vector3(cos(left) * 7.6, 0, sin(left) * 6.4))
	_post(Vector3(cos(right) * 7.6, 0, sin(right) * 6.4))


func _post(pos: Vector3) -> void:
	var iron := _mat(Color("5a6270"))
	_box(Vector3(0.12, 1.15, 0.12), pos + Vector3(0, 0.58, 0), iron, true)
	_cyl(self, 0.0, 0.1, 0.22, iron, pos + Vector3(0, 1.2, 0))


func _rail(a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 0.2:
		return
	var yaw := atan2(delta.x, delta.z)
	for h in [0.45, 0.85]:
		var body := StaticBody3D.new()
		body.name = "FenceRail"
		body.position = mid + Vector3(0, h, 0)
		body.rotation.y = yaw
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.06, 0.06, length)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		mi.mesh = mesh
		mi.material_override = _mat(Color("5a6270"))
		mi.position = body.position
		mi.rotation.y = yaw
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _stones() -> void:
	var spots: Array[Vector3] = [
		Vector3(-1.6, 0, -1.2),
		Vector3(1.4, 0, -0.6),
		Vector3(-0.2, 0, 1.5),
		Vector3(2.2, 0, 1.6),
		Vector3(-2.4, 0, 1.1),
		Vector3(0.4, 0, -2.2),
	]
	for i in spots.size():
		var stone := Node3D.new()
		stone.name = "Tombstone%d" % i
		stone.position = spots[i]
		stone.rotation.y = float(i) * 0.4
		stone.rotation.z = 0.06 if i % 2 == 0 else -0.05
		add_child(stone)
		var gray := _mat(Color("d5d8e0") if i % 2 == 0 else Color("9aa0aa"))
		_box(Vector3(0.7, 0.95, 0.16), Vector3(0, 0.55, 0), gray, false, stone)
		_ball(stone, 0.34, gray, Vector3(0, 1.0, 0), Vector3(1.05, 0.55, 0.5))
	var cross := Node3D.new()
	cross.name = "TombstoneCross"
	cross.position = Vector3(-0.8, 0, 0.2)
	add_child(cross)
	var pale := _mat(Color("e4e6ee"))
	_box(Vector3(0.12, 1.15, 0.1), Vector3(0, 0.6, 0), pale, false, cross)
	_box(Vector3(0.55, 0.1, 0.1), Vector3(0, 0.85, 0), pale, false, cross)


func _trees() -> void:
	_tree(Vector3(-8.8, 0, -2.4), 1.0)
	_tree(Vector3(6.4, 0, -7.2), 0.8)


func _tree(pos: Vector3, scale: float) -> void:
	var root := Node3D.new()
	root.name = "DeadTree"
	root.position = pos
	root.scale = Vector3.ONE * scale
	add_child(root)
	var bark := _mat(Color("3a2a24"))
	_cyl(root, 0.18, 0.28, 2.4, bark, Vector3(0, 1.2, 0), Vector3(0.08, 0, 0.12))
	_cyl(root, 0.06, 0.08, 1.3, bark, Vector3(0.55, 2.3, 0.1), Vector3(0, 0, -0.9))
	_cyl(root, 0.05, 0.07, 1.1, bark, Vector3(-0.45, 2.15, -0.2), Vector3(0.2, 0, 0.8))
	_cyl(root, 0.04, 0.05, 0.8, bark, Vector3(0.15, 2.7, -0.45), Vector3(-0.6, 0.4, 0.2))


func _fog() -> void:
	var mat := _mat(Color(0.68, 0.76, 0.88, 0.16))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var spots: Array[Vector3] = [
		Vector3(-2.5, 0.7, 0.4),
		Vector3(1.8, 0.8, -1.4),
		Vector3(0.2, 0.6, 2.2),
		Vector3(-3.2, 0.9, -2.0),
		Vector3(3.0, 0.7, 1.2),
	]
	for i in spots.size():
		_ball(self, 1.6, mat, spots[i], Vector3(1.4, 0.45, 1.2)).name = "Fog%d" % i


func _box(size: Vector3, pos: Vector3, mat: Material, collide: bool, parent: Node = null) -> void:
	var host: Node = parent if parent else self
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	if not collide:
		return
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	host.add_child(body)


func _ball(parent: Node, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, top: float, bottom: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top if top > 0.0 else 0.001
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m
