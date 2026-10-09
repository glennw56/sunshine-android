extends Node3D
## Test-world rim. A 20 m cobblestone wall inside the photo borders,
## with a closed grand gate in the middle of each side. North is −Z.
## An invisible collar above the stone stops a jump off the giant pumpkin.

const INNER := 102.0
const THICK := 1.8
const HEIGHT := 20.0
const SEAL_TOP := 42.0
const GATE_GAP := 6.6
const DOOR_H := 8.15
const ARCH_R := 3.15

const STONE := Color("5c584f")
const STONE_DK := Color("3e3b36")
const MORTAR := Color("2a2826")
const COPING := Color("7a756c")
const WOOD := Color("6a4030")
const WOOD_DK := Color("4a2c20")
const IRON := Color("2a2e34")
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
	_gate("GateNorth", Vector3(0, 0, -center), 0.0, tex)
	_gate("GateSouth", Vector3(0, 0, center), PI, tex)
	_gate("GateEast", Vector3(center, 0, 0), -PI * 0.5, tex)
	_gate("GateWest", Vector3(-center, 0, 0), PI * 0.5, tex)


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


func _gate(gate_name: String, pos: Vector3, yaw: float, tex: Texture2D) -> void:
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
	# One mesh child. A later grand_gate.glb replaces this node only.
	# Its outside face is local −Z and its base is y 0, matching that file.
	var visual := Node3D.new()
	visual.name = "GateVisual"
	gate.add_child(visual)
	var stone := _stone_mat(tex, 2.2, 2.2)
	_pillar(visual, Vector3(-GATE_GAP * 0.5 - 0.15, 0, 0), stone)
	_pillar(visual, Vector3(GATE_GAP * 0.5 + 0.15, 0, 0), stone)
	_arch(visual, stone)
	_doors(visual)
	_torch(visual, gate, Vector3(-GATE_GAP * 0.5 - 0.15, 6.4, THICK * 0.55), "TorchLightL")
	_torch(visual, gate, Vector3(GATE_GAP * 0.5 + 0.15, 6.4, THICK * 0.55), "TorchLightR")


func _pillar(visual: Node3D, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.35, 10.4, THICK + 0.45)
	mi.mesh = mesh
	mi.position = at + Vector3(0, 5.2, 0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mi)
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(1.7, 0.38, THICK + 0.8)
	cap.mesh = cap_mesh
	cap.position = at + Vector3(0, 10.5, 0)
	cap.material_override = _flat(COPING)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(cap)


func _arch(visual: Node3D, mat: Material) -> void:
	var spring := DOOR_H - 1.55
	var pieces := 8
	for i in pieces:
		var t := (float(i) + 0.5) / float(pieces)
		var ang := PI * (1.0 - t)
		var radial := Vector3(cos(ang), sin(ang), 0)
		var tangent := Vector3(-sin(ang), cos(ang), 0)
		var mi := MeshInstance3D.new()
		mi.name = "Arch"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(ARCH_R * PI / float(pieces) + 0.28, 0.85, THICK + 0.35)
		mi.mesh = mesh
		mi.position = Vector3(0, spring, 0) + radial * ARCH_R
		mi.basis = Basis(tangent, radial, tangent.cross(radial).normalized())
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(mi)


func _doors(visual: Node3D) -> void:
	var leaf_w := GATE_GAP * 0.5 - 0.08
	for side in [-1.0, 1.0]:
		var door := MeshInstance3D.new()
		door.name = "DoorLeft" if side < 0.0 else "DoorRight"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(leaf_w, DOOR_H, 0.28)
		door.mesh = mesh
		door.position = Vector3(side * leaf_w * 0.5, DOOR_H * 0.5 + 0.04, 0.06)
		door.material_override = _flat(WOOD if side < 0.0 else WOOD_DK)
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(door)
	for i in 4:
		var band := MeshInstance3D.new()
		band.name = "IronBand"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(GATE_GAP - 0.35, 0.16, 0.4)
		band.mesh = mesh
		band.position = Vector3(0, 1.15 + float(i) * 1.85, 0.16)
		band.material_override = _flat(IRON)
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(band)
	for side in [-1.0, 1.0]:
		var hinge := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.42, 0.46)
		hinge.mesh = mesh
		hinge.position = Vector3(side * (GATE_GAP * 0.5 - 0.12), 2.2, 0.18)
		hinge.material_override = _flat(IRON)
		hinge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(hinge)
		var hinge2 := hinge.duplicate() as MeshInstance3D
		hinge2.position.y = 6.4
		visual.add_child(hinge2)


func _torch(visual: Node3D, gate: Node3D, at: Vector3, light_name: String) -> void:
	var bracket := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 0.12, 0.55)
	bracket.mesh = bar
	bracket.position = at
	bracket.material_override = _flat(IRON)
	bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(bracket)
	var flame := MeshInstance3D.new()
	flame.name = "Torch"
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	ball.radial_segments = 10
	ball.rings = 6
	flame.mesh = ball
	flame.position = at + Vector3(0, 0.28, 0.18)
	var mat := _flat(FLAME)
	mat.emission_enabled = true
	mat.emission = FLAME
	mat.emission_energy_multiplier = 1.4
	flame.material_override = mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(flame)
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = FLAME
	light.light_energy = 1.35
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = flame.position
	gate.add_child(light)
	var glow := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 0.9
	disc.height = 1.8
	disc.radial_segments = 10
	disc.rings = 6
	glow.mesh = disc
	glow.position = at + Vector3(0, -0.15, 0.05)
	glow.scale = Vector3(1.1, 1.4, 0.12)
	var wash := _flat(Color(1.0, 0.55, 0.22, 0.22))
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = wash
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(glow)


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
