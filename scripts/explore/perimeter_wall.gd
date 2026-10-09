extends Node3D
## Test-world rim. A 20 m cobblestone wall inside the photo borders,
## with grand_gate.glb closed in the middle of each side. North is −Z.
## An invisible collar above the stone stops a jump off the giant pumpkin.

const Look := preload("res://scripts/explore/authored_look.gd")
const GRAND_GATE_GLB := "res://assets/explore/grand_gate.glb"

const INNER := 102.0
const THICK := 1.8
const HEIGHT := 20.0
const SEAL_TOP := 42.0
const GATE_GAP := 6.6

const STONE := Color("5c584f")
const STONE_DK := Color("3e3b36")
const MORTAR := Color("2a2826")
const COPING := Color("7a756c")
const FLAME := Color("ff8a28")


func _ready() -> void:
	name = "PerimeterWall"
	var tex := _stone_tex()
	var center := INNER + THICK * 0.5
	var outer := INNER + THICK
	_run("WallNorth", Vector3(outer * 2.0, HEIGHT, THICK), Vector3(0, HEIGHT * 0.5, -center), true, tex)
	_run("WallSouth", Vector3(outer * 2.0, HEIGHT, THICK), Vector3(0, HEIGHT * 0.5, center), true, tex)
	_run("WallEast", Vector3(THICK, HEIGHT, INNER * 2.0), Vector3(center, HEIGHT * 0.5, 0), false, tex)
	_run("WallWest", Vector3(THICK, HEIGHT, INNER * 2.0), Vector3(-center, HEIGHT * 0.5, 0), false, tex)
	_gate("GateNorth", Vector3(0, 0, -center), 0.0)
	_gate("GateSouth", Vector3(0, 0, center), PI)
	_gate("GateEast", Vector3(center, 0, 0), -PI * 0.5)
	_gate("GateWest", Vector3(-center, 0, 0), PI * 0.5)


func _run(run_name: String, size: Vector3, pos: Vector3, gap_on_x: bool, tex: Texture2D) -> void:
	var gap := GATE_GAP
	var span := size.x if gap_on_x else size.z
	var seg := (span - gap) * 0.5
	var shift := gap * 0.5 + seg * 0.5
	for side in [-1.0, 1.0]:
		var piece := size
		var at := pos
		if gap_on_x:
			piece.x = seg
			at.x += side * shift
		else:
			piece.z = seg
			at.z += side * shift
		_solid(run_name, piece, at, tex)


func _solid(run_name: String, size: Vector3, pos: Vector3, tex: Texture2D) -> void:
	var body := StaticBody3D.new()
	body.name = run_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_shape(body, size, Vector3.ZERO)
	var seal_h := SEAL_TOP - HEIGHT
	_shape(body, Vector3(size.x, seal_h, size.z), Vector3(0, HEIGHT * 0.5 + seal_h * 0.5, 0))
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _stone_mat(tex, size.x / 1.7, size.y / 1.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	var coping := MeshInstance3D.new()
	var cap := BoxMesh.new()
	cap.size = Vector3(size.x + 0.12, 0.34, size.z + 0.12)
	coping.mesh = cap
	coping.position = Vector3(0, size.y * 0.5 + 0.12, 0)
	coping.material_override = _flat(COPING)
	coping.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(coping)
	var skirt := MeshInstance3D.new()
	var skirt_mesh := BoxMesh.new()
	skirt_mesh.size = Vector3(size.x, 0.55, size.z + 0.08)
	skirt.mesh = skirt_mesh
	skirt.position = Vector3(0, -size.y * 0.5 + 0.28, 0)
	skirt.material_override = _flat(MORTAR)
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(skirt)


func _gate(gate_name: String, pos: Vector3, yaw: float) -> void:
	var gate := Node3D.new()
	gate.name = gate_name
	gate.position = pos
	gate.rotation.y = yaw
	add_child(gate)
	var block := StaticBody3D.new()
	block.name = "GateBlock"
	block.collision_layer = 1
	block.collision_mask = 0
	gate.add_child(block)
	_shape(block, Vector3(GATE_GAP, SEAL_TOP, THICK), Vector3(0, SEAL_TOP * 0.5, 0))
	# grand_gate.glb origin is the wall centreline, mid-gap, y 0.
	# Outside face is local −Z, so the patio is +Z. Scale stays 1.
	# DoorL, DoorR, Portcullis, and Crossbar stay closed for a later open.
	var visual := Look.lift(GRAND_GATE_GLB, "GrandGate")
	if visual == null:
		push_error("grand gate model missing for " + gate_name)
		return
	visual.position = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	visual.scale = Vector3.ONE
	gate.add_child(visual)
	_gate_lights(visual)
	_keep_gate_glow(visual)


func _gate_lights(visual: Node3D) -> void:
	for socket_name in ["LightL", "LightR"]:
		var socket := visual.find_child(socket_name, true, false) as Node3D
		if socket == null:
			push_error("grand gate missing " + socket_name)
			continue
		var light := OmniLight3D.new()
		light.name = "GateLamp"
		light.light_color = FLAME
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.shadow_enabled = false
		socket.add_child(light)


func _keep_gate_glow(root: Node) -> void:
	## M_grand_gate_glow is the lantern flame. Night flatten would blue it.
	## Leave that albedo alone and mark the surface emissive.
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				for i in mi.mesh.get_surface_count():
					var src := mi.mesh.surface_get_material(i)
					if src == null or str(src.resource_name) != "M_grand_gate_glow":
						continue
					var mat := mi.get_surface_override_material(i) as StandardMaterial3D
					if mat == null:
						mat = StandardMaterial3D.new()
						mi.set_surface_override_material(i, mat)
					mat.albedo_color = Color.WHITE
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture:
						mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
					mat.emission_enabled = true
					mat.emission = FLAME
					mat.emission_energy_multiplier = 1.6
					if mat.albedo_texture:
						mat.emission_texture = mat.albedo_texture
		for child in n.get_children():
			stack.append(child)


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)


func _stone_mat(tex: Texture2D, tile_x: float, tile_y: float) -> StandardMaterial3D:
	var mat := _flat(Color.WHITE)
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.uv1_scale = Vector3(maxf(tile_x, 1.0), maxf(tile_y, 1.0), 1.0)
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


func _stone_tex() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(MORTAR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	var y := 2
	while y < 124:
		var h := rng.randi_range(16, 24)
		var x := 2
		var row := rng.randi_range(0, 6)
		while x < 124:
			var w := rng.randi_range(18, 30)
			var shade := rng.randf_range(0.78, 1.08)
			var stone := Color(STONE.r * shade, STONE.g * shade, STONE.b * shade)
			if (x + row) % 5 == 0:
				stone = stone.lerp(STONE_DK, 0.35)
			for py in range(y, mini(y + h - 3, 127)):
				for px in range(x, mini(x + w - 3, 127)):
					img.set_pixel(px, py, stone)
			x += w
		y += h
	return ImageTexture.create_from_image(img)
