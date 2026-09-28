extends Node3D
class_name AvatarBody
## Rounded chibi from an approved avatar recipe. Feet sit on y=0. No cubes as the body.

const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
## Soft clothing stays the live blouse pack. A1 locked head: Scout discs, 4-point stars
## fully inside, one continuous wine glasses bridge, rear hair only (no side-of-face slabs).
const WINE := Color("6b2d3c")
const BLUSH_FABRIC := Color("e8b4b8")
const CREAM := Color("f7f0e6")
const STRAW := Color("e6b14a")
const STRAW_DARK := Color("c9922e")
const PETAL := Color("f0c43a")
const SEED := Color("4a2a12")
const SHOE := Color("2a1c18")
const PLATE_NEAR := 5.5
const PLATE_FAR := 10.0
const THROW_TIME := 0.32
const TOSS_GHOST_ALPHA := 0.28

var recipe: Dictionary = {}
var _hand: Node3D
var _head: Node3D
var _plate: Label3D
var _lleg: Node3D
var _rleg: Node3D
var _larm: Node3D
var _rarm: Node3D
var _moving := false
var _walk: float = 0.0
var _display: String = ""
var _hide_plate := false
var _throw_left := 0.0
var _hit_left := 0.0
var _skin_mats: Array[StandardMaterial3D] = []
var _skin_alpha: Array[float] = []
var _skin_transparency: Array[int] = []
var _skin_depth: Array[int] = []
var _ghost: float = 1.0
var _ghost_target: float = 1.0
var _ghost_applied: float = 1.0


func _ready() -> void:
	if recipe.is_empty():
		rebuild(ProfileStore.current_avatar())


func rebuild(raw: Dictionary, display_name: String = "") -> void:
	recipe = CosContracts.sanitize_avatar(raw)
	if display_name != "":
		_display = display_name
	for child in get_children():
		child.queue_free()
	_hand = null
	_head = null
	_plate = null
	_lleg = null
	_rleg = null
	_larm = null
	_rarm = null
	_build()


func hand_socket() -> Node3D:
	return _hand


func head_node() -> Node3D:
	return _head


func set_nameplate(text: String) -> void:
	var label := text.strip_edges()
	if label == "":
		label = "Sunshine Guest"
	_display = label
	if _plate:
		_plate.text = label
		if _hide_plate:
			_plate.visible = false


func hide_nameplate() -> void:
	_hide_plate = true
	if _plate:
		_plate.visible = false


func update_nameplate_for(viewer: Vector3) -> void:
	if _hide_plate or _plate == null:
		if _plate:
			_plate.visible = false
		return
	var d := global_position.distance_to(viewer)
	var far := PLATE_FAR
	var generic := _is_generic_plate(_display)
	if generic:
		far = 3.8
	if d > far:
		_plate.visible = false
		return
	_plate.visible = true
	var alpha := 1.0
	if d > PLATE_NEAR:
		alpha = 1.0 - (d - PLATE_NEAR) / (PLATE_FAR - PLATE_NEAR)
	_plate.modulate = Color(1.0, 0.965, 0.918, clampf(alpha, 0.0, 1.0))
	_plate.font_size = 18 if d > 7.0 else 20


func _is_generic_plate(display: String) -> bool:
	var d := display.strip_edges()
	return d == "" or d == "Baker" or d == "Guest" or d.ends_with(" Guest")


func set_moving(on: bool) -> void:
	_moving = on


func set_toss_ghost(enabled: bool) -> void:
	_ghost_target = TOSS_GHOST_ALPHA if enabled else 1.0


func toss_ghost_alpha() -> float:
	return _ghost


func play_throw(skip_windup := false) -> void:
	# Local bakers wind up 0.12s then fling. Remotes already waited on the
	# sender, so start at the release pose so the cookie leaves the hand.
	_hit_left = 0.0
	_throw_left = THROW_TIME * (0.62 if skip_windup else 1.0)
	_apply_throw_pose()


func play_hit() -> void:
	_throw_left = 0.0
	_hit_left = 0.42
	_apply_hit_pose(0.0)


func _apply_throw_pose() -> void:
	if _rarm == null or _throw_left <= 0.0:
		return
	var k := 1.0 - _throw_left / THROW_TIME
	if k < 0.38:
		_rarm.rotation.x = lerpf(0.0, 0.95, k / 0.38)
	else:
		_rarm.rotation.x = lerpf(0.95, -1.15, (k - 0.38) / 0.62)


func _apply_hit_pose(k: float) -> void:
	# Lean back, both arms up — a hit, not a throw.
	var lean := sin(clampf(k, 0.0, 1.0) * PI) * -0.55
	rotation.x = lean
	if _rarm:
		_rarm.rotation.x = -1.05
	if _larm:
		_larm.rotation.x = -0.85


func _process(delta: float) -> void:
	_ghost = lerpf(_ghost, _ghost_target, clampf(delta * 14.0, 0.0, 1.0))
	if absf(_ghost - _ghost_target) < 0.02:
		_ghost = _ghost_target
	_apply_ghost()
	if _hit_left > 0.0:
		_hit_left = maxf(0.0, _hit_left - delta)
		_apply_hit_pose(1.0 - _hit_left / 0.42)
		if _hit_left <= 0.0:
			rotation.x = 0.0
		return
	if _throw_left > 0.0:
		_throw_left = maxf(0.0, _throw_left - delta)
		_apply_throw_pose()
	if _moving:
		_walk += delta * 9.0
	else:
		_walk = lerpf(_walk, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	var swing := sin(_walk) * (0.55 if _moving else 0.0)
	if _lleg:
		_lleg.rotation.x = swing
	if _rleg:
		_rleg.rotation.x = -swing
	if _larm:
		_larm.rotation.x = -swing * 0.65
	if _rarm and _throw_left <= 0.0:
		_rarm.rotation.x = swing * 0.65


func _mat(c: Color, rough := 0.58) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.visibility_range_end = 40.0
	mi.visibility_range_end_margin = 8.0
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	return _mesh(parent, mesh, mat, pos, Vector3.ZERO, scl)


func _cap(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = r
	mesh.height = h
	mesh.radial_segments = 14
	return _mesh(parent, mesh, mat, pos, rot)


func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = 16
	return _mesh(parent, mesh, mat, pos, rot)


func _build() -> void:
	var skin := _mat(CosContracts.SKIN_COLORS.get(recipe["skin"], Color("f7d3b8")))
	var hair_c := _mat(CosContracts.HAIR_TINTS.get(recipe["hair_color"], Color("3d2418")), 0.7)
	## Blouse fabric follows the outfit key. Blush is #e8b4b8 so it does not match warm skin.
	var outfit_key := str(recipe.get("outfit", "blush"))
	var outfit_col: Color = CosContracts.OUTFIT_COLORS.get(outfit_key, Color("e8a8b4"))
	if outfit_key == "blush":
		outfit_col = BLUSH_FABRIC
	var outfit := _mat(outfit_col, 0.65)
	var cuff_m := _mat(outfit_col.lightened(0.12), 0.55)
	var wine_m := _mat(WINE, 0.55)
	var cream_m := _mat(CREAM, 0.65)
	var shoe_m := _mat(SHOE, 0.5)
	var root := Node3D.new()
	root.name = "Rig"
	root.position.y = -0.05
	add_child(root)
	## Contact shadow so the soles read as planted, not hovering.
	var shadow := CylinderMesh.new()
	shadow.top_radius = 0.28
	shadow.bottom_radius = 0.28
	shadow.height = 0.02
	var shadow_mat := _mat(Color(0.12, 0.08, 0.06, 0.38), 1.0)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(root, shadow, shadow_mat, Vector3(0, 0.012, 0.02))
	## Short rounded sleeves, a waist pinch, and a wine collar on the face side (−Z).
	_cap(root, 0.155, 0.52, outfit, Vector3(0, 0.78, 0))
	_sphere(root, 0.195, outfit, Vector3(0, 1.00, 0), Vector3(1.18, 0.68, 0.95))
	_cyl(root, 0.145, 0.155, 0.06, outfit, Vector3(0, 0.58, 0.0))
	_cyl(root, 0.140, 0.150, 0.048, wine_m, Vector3(0, 1.08, 0.01))
	_sphere(root, 0.048, wine_m, Vector3(-0.065, 1.05, -0.115), Vector3(1.15, 0.7, 0.85))
	_sphere(root, 0.048, wine_m, Vector3(0.065, 1.05, -0.115), Vector3(1.15, 0.7, 0.85))
	var wear_pants := str(recipe.get("bottoms", "skirt")) == "pants"
	if wear_pants:
		_build_pants(root)
	else:
		_build_skirt(root, outfit_key, cream_m)
	_cyl(root, 0.165, 0.175, 0.045, outfit, Vector3(0, 0.54, 0.0))
	var apron := str(recipe.get("apron", "none"))
	if apron != "none":
		var apron_col := Color("c5c0be")
		if apron == "blush":
			apron_col = Color("e8b4b8")
		elif apron == "wine":
			apron_col = Color("6b2d3c")
		## Face is −Z (eyes). Keep the apron on that side of the chest.
		_cyl(root, 0.17, 0.2, 0.3, _mat(apron_col, 0.7), Vector3(0, 0.7, -0.11))
	_larm = Node3D.new()
	_larm.position = Vector3(-0.24, 0.96, 0.02)
	root.add_child(_larm)
	_sphere(_larm, 0.070, outfit, Vector3(0, -0.02, 0), Vector3(1.15, 0.85, 1.15))
	_cap(_larm, 0.058, 0.16, outfit, Vector3(0, -0.10, 0), Vector3(0, 0, 18))
	_cyl(_larm, 0.052, 0.055, 0.035, cuff_m, Vector3(0.01, -0.18, 0), Vector3(0, 0, 18))
	_cap(_larm, 0.042, 0.16, skin, Vector3(0.02, -0.28, 0), Vector3(0, 0, 18))
	_sphere(_larm, 0.048, skin, Vector3(0.03, -0.36, 0.01))
	_rarm = Node3D.new()
	_rarm.position = Vector3(0.24, 0.96, 0.02)
	root.add_child(_rarm)
	_sphere(_rarm, 0.070, outfit, Vector3(0, -0.02, 0), Vector3(1.15, 0.85, 1.15))
	_cap(_rarm, 0.058, 0.16, outfit, Vector3(0, -0.10, 0), Vector3(0, 0, -18))
	_cyl(_rarm, 0.052, 0.055, 0.035, cuff_m, Vector3(-0.01, -0.18, 0), Vector3(0, 0, -18))
	_cap(_rarm, 0.042, 0.16, skin, Vector3(-0.02, -0.28, 0), Vector3(0, 0, -18))
	_sphere(_rarm, 0.048, skin, Vector3(-0.03, -0.36, 0.01))
	_hand = Node3D.new()
	_hand.name = "HandSocket"
	_hand.position = Vector3(0.06, -0.40, -0.06)
	_rarm.add_child(_hand)
	_lleg = Node3D.new()
	_lleg.position = Vector3(-0.08, 0.42, 0.02)
	root.add_child(_lleg)
	if not wear_pants:
		_cap(_lleg, 0.055, 0.30, skin, Vector3(0, -0.12, 0))
	_cyl(_lleg, 0.048, 0.042, 0.08, cream_m, Vector3(0, -0.30, 0))
	_sphere(_lleg, 0.070, shoe_m, Vector3(0, -0.36, 0.025), Vector3(1.15, 0.75, 1.25))
	_cyl(_lleg, 0.055, 0.060, 0.018, _mat(Color("1a1210"), 0.6), Vector3(0, -0.40, 0.02))
	_rleg = Node3D.new()
	_rleg.position = Vector3(0.08, 0.42, 0.02)
	root.add_child(_rleg)
	if not wear_pants:
		_cap(_rleg, 0.055, 0.30, skin, Vector3(0, -0.12, 0))
	_cyl(_rleg, 0.048, 0.042, 0.08, cream_m, Vector3(0, -0.30, 0))
	_sphere(_rleg, 0.070, shoe_m, Vector3(0, -0.36, 0.025), Vector3(1.15, 0.75, 1.25))
	_cyl(_rleg, 0.055, 0.060, 0.018, _mat(Color("1a1210"), 0.6), Vector3(0, -0.40, 0.02))
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 1.28, 0)
	root.add_child(_head)
	## Youthify head: slightly wider + shorter for rounder cheeks / softer shorter jaw.
	_sphere(_head, 0.26, skin, Vector3.ZERO, Vector3(1.07, 0.95, 1.03))
	## Soft cheek plump — front-biased. Not lateral ear lobes.
	_sphere(_head, 0.082, skin, Vector3(-0.140, -0.012, -0.175), Vector3(0.88, 0.78, 0.52))
	_sphere(_head, 0.082, skin, Vector3(0.140, -0.012, -0.175), Vector3(0.88, 0.78, 0.52))
	## Scout eyes: flush near-black discs + 4-point stars fully inside both discs.
	var eye_m := _mat(Color("1a1210"), 0.22)
	var glint_m := _mat(Color.WHITE, 0.08)
	var smile_m := _mat(Color("3f1522"), 0.35)
	var blush_m := _mat(Color("e8b4b8"), 0.55)
	## Flat discs sit forward of the skull so they stay round, and behind the glasses plane.
	_sphere(_head, 0.058, eye_m, Vector3(-0.082, 0.036, -0.261), Vector3(1.00, 1.00, 0.085))
	_sphere(_head, 0.058, eye_m, Vector3(0.082, 0.036, -0.261), Vector3(1.00, 1.00, 0.085))
	## Stars just in front of each disc, inset toward the centers so they never spill.
	_star_sparkle(_head, glint_m, Vector3(-0.077, 0.042, -0.2672), 0.010)
	_star_sparkle(_head, glint_m, Vector3(-0.087, 0.029, -0.2670), 0.0045)
	_star_sparkle(_head, glint_m, Vector3(0.077, 0.042, -0.2672), 0.010)
	_star_sparkle(_head, glint_m, Vector3(0.087, 0.029, -0.2670), 0.0045)
	## Soft horizontal oval blush.
	_sphere(_head, 0.055, blush_m, Vector3(-0.150, -0.008, -0.195), Vector3(1.55, 0.55, 0.38))
	_sphere(_head, 0.055, blush_m, Vector3(0.150, -0.008, -0.195), Vector3(1.55, 0.55, 0.38))
	## One clean shallow wine smile, slightly proud of the face.
	var smile_pts := [
		Vector3(-0.020, -0.072, -0.283), Vector3(-0.014, -0.075, -0.283),
		Vector3(-0.008, -0.077, -0.283), Vector3(-0.003, -0.078, -0.283),
		Vector3(0.0, -0.079, -0.283), Vector3(0.003, -0.078, -0.283),
		Vector3(0.008, -0.077, -0.283), Vector3(0.014, -0.075, -0.283),
		Vector3(0.020, -0.072, -0.283),
	]
	for i in range(smile_pts.size() - 1):
		var a: Vector3 = smile_pts[i]
		var b: Vector3 = smile_pts[i + 1]
		var mid := (a + b) * 0.5
		var delta := b - a
		var length := delta.length()
		var yaw := rad_to_deg(atan2(delta.x, -delta.z))
		var pitch := rad_to_deg(atan2(delta.y, Vector2(delta.x, -delta.z).length()))
		_cap(_head, 0.0032, maxf(length * 1.55, 0.012), smile_m, mid, Vector3(pitch + 90.0, yaw, 0.0))
	_sphere(_head, 0.0034, smile_m, smile_pts[0])
	_sphere(_head, 0.0034, smile_m, smile_pts[smile_pts.size() - 1])
	## Beauty mark — viewer-left (+X), just below the left lens.
	_sphere(_head, 0.0088, _mat(Color("2a1c18"), 0.4), Vector3(0.115, -0.048, -0.275))
	_build_hair(_head, hair_c)
	_build_hat(_head)
	_build_accessory(_head)
	_plate = Label3D.new()
	_plate.name = "Nameplate"
	_plate.text = _display if _display != "" else (ProfileStore.display_name if ProfileStore.display_name != "" else "Sunshine Guest")
	_plate.font_size = 20
	_plate.outline_size = 4
	_plate.pixel_size = 0.0042
	_plate.position = Vector3(0, 1.72, 0)
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.modulate = Color("fff6ea")
	_plate.outline_modulate = Color("4a1c28")
	_plate.no_depth_test = false
	_plate.visible = false
	add_child(_plate)
	_capture_skin(root)
	_ghost_applied = -1.0
	_apply_ghost()


func _build_skirt(root: Node3D, outfit_key: String, cream_m: Material) -> void:
	var skirt_col := cream_m if outfit_key != "cream" else _mat(Color("e8dcc8"), 0.65)
	if outfit_key == "wine":
		skirt_col = _mat(Color("f0e6dc"), 0.65)
	var skirt := Node3D.new()
	skirt.name = "Skirt"
	root.add_child(skirt)
	_cyl(skirt, 0.16, 0.22, 0.22, skirt_col, Vector3(0, 0.46, 0.0))
	_sphere(skirt, 0.10, skirt_col, Vector3(-0.11, 0.36, -0.02), Vector3(1.0, 0.5, 0.75))
	_sphere(skirt, 0.10, skirt_col, Vector3(0.11, 0.36, -0.02), Vector3(1.0, 0.5, 0.75))


func _build_pants(root: Node3D) -> void:
	var key := str(recipe.get("pants", "wine"))
	var col: Color = CosContracts.PANTS_COLORS.get(key, Color("4a1c28"))
	var cloth := _mat(col, 0.62)
	var pants := Node3D.new()
	pants.name = "Pants"
	root.add_child(pants)
	## Seat meets the blouse waist. Each leg covers the thigh down to the sock.
	_cyl(pants, 0.155, 0.17, 0.14, cloth, Vector3(0, 0.50, 0.02))
	_cyl(pants, 0.078, 0.064, 0.30, cloth, Vector3(-0.08, 0.32, 0.02))
	_cyl(pants, 0.078, 0.064, 0.30, cloth, Vector3(0.08, 0.32, 0.02))


func _capture_skin(rig: Node) -> void:
	_skin_mats.clear()
	_skin_alpha.clear()
	_skin_transparency.clear()
	_skin_depth.clear()
	_collect_skin(rig)


func _collect_skin(n: Node) -> void:
	if n is MeshInstance3D:
		var mat := (n as MeshInstance3D).material_override as StandardMaterial3D
		if mat and not _skin_mats.has(mat):
			_skin_mats.append(mat)
			_skin_alpha.append(mat.albedo_color.a)
			_skin_transparency.append(int(mat.transparency))
			_skin_depth.append(int(mat.depth_draw_mode))
	for child in n.get_children():
		_collect_skin(child)


func _apply_ghost() -> void:
	if absf(_ghost - _ghost_applied) < 0.004:
		return
	_ghost_applied = _ghost
	var ghosting := _ghost < 0.97
	for i in _skin_mats.size():
		var mat := _skin_mats[i]
		if mat == null:
			continue
		var c := mat.albedo_color
		c.a = _skin_alpha[i] * _ghost
		mat.albedo_color = c
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if ghosting:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		else:
			mat.transparency = _skin_transparency[i] as BaseMaterial3D.Transparency
			mat.depth_draw_mode = _skin_depth[i] as BaseMaterial3D.DepthDrawMode


func _build_hair(head: Node3D, hair: Material) -> void:
	var style := str(recipe.get("hair", "bangs"))
	if style == "none":
		return
	## Crown under the brim. Rear mass is one volume — no stacked back plate.
	_sphere(head, 0.21, hair, Vector3(0, 0.14, 0.10), Vector3(1.12, 0.6, 0.92))
	if style == "bangs" or style == "wavy":
		## Short under-brim fringe, pulled in so it never sticks out at the temples.
		_sphere(head, 0.044, hair, Vector3(-0.070, 0.178, -0.100), Vector3(1.35, 0.22, 0.36))
		_sphere(head, 0.046, hair, Vector3(-0.010, 0.186, -0.112), Vector3(1.30, 0.22, 0.36))
		_sphere(head, 0.044, hair, Vector3(0.055, 0.180, -0.105), Vector3(1.30, 0.22, 0.36))
		## Soft high wisps above the lenses, under the brim, with no side reach.
		_sphere(head, 0.026, hair, Vector3(-0.030, 0.150, -0.122), Vector3(1.0, 0.16, 0.26))
		_sphere(head, 0.024, hair, Vector3(0.030, 0.152, -0.120), Vector3(0.95, 0.15, 0.24))
		_build_rear_hair_only(head, hair)
	if style == "wavy":
		## Extra rear wave volume only — behind the head, not cheek columns.
		_sphere(head, 0.12, hair, Vector3(-0.14, -0.06, 0.14), Vector3(0.7, 1.15, 0.85))
		_sphere(head, 0.12, hair, Vector3(0.14, -0.06, 0.14), Vector3(0.7, 1.15, 0.85))
	if style == "short":
		_sphere(head, 0.2, hair, Vector3(0, 0.1, 0.04), Vector3(1.05, 0.55, 1.0))
	if style == "bun":
		_sphere(head, 0.1, hair, Vector3(0, 0.24, 0.06))


## One continuous soft rear volume behind the head. No side-of-face hair.
func _build_rear_hair_only(head: Node3D, hair: Material) -> void:
	_sphere(head, 0.168, hair, Vector3(0.0, 0.010, 0.178), Vector3(0.98, 1.35, 0.92))
	## Fill tucked inside the primary mass so the lower edge tapers as one silhouette.
	_sphere(head, 0.105, hair, Vector3(0.0, -0.070, 0.168), Vector3(0.78, 0.85, 0.72))


func _build_hat(head: Node3D) -> void:
	var hat := str(recipe.get("hat", "none"))
	if hat == "none":
		return
	if hat == "sun":
		var straw := _mat(STRAW, 0.5)
		var straw_d := _mat(STRAW_DARK, 0.55)
		var tilt := Vector3(8, 0, -5)
		_cyl(head, 0.15, 0.17, 0.12, straw, Vector3(0, 0.30, 0.02), tilt)
		_sphere(head, 0.150, straw, Vector3(0, 0.36, 0.02), Vector3(1.05, 0.45, 1.05))
		_cyl(head, 0.175, 0.175, 0.045, _mat(Color("1a1a1a"), 0.4), Vector3(0, 0.24, 0.02), tilt)
		var brim0 := CylinderMesh.new()
		brim0.top_radius = 0.28
		brim0.bottom_radius = 0.28
		brim0.height = 0.028
		brim0.radial_segments = 20
		_mesh(head, brim0, straw, Vector3(0, 0.22, 0.0), tilt)
		var brim1 := CylinderMesh.new()
		brim1.top_radius = 0.36
		brim1.bottom_radius = 0.37
		brim1.height = 0.026
		brim1.radial_segments = 20
		_mesh(head, brim1, straw, Vector3(0, 0.205, 0.0), Vector3(10, 0, -6))
		var brim2 := CylinderMesh.new()
		brim2.top_radius = 0.44
		brim2.bottom_radius = 0.46
		brim2.height = 0.022
		brim2.radial_segments = 22
		_mesh(head, brim2, straw_d, Vector3(0, 0.185, 0.01), Vector3(12, 0, -7))
		_attach_sunflower(head, Vector3(0.28, 0.26, -0.06), 0.72)
	elif hat == "beanie":
		_sphere(head, 0.2, _mat(Color("6b2d3c")), Vector3(0, 0.18, 0.02), Vector3(1.15, 0.7, 1.05))
	elif hat == "bow":
		_sphere(head, 0.07, _mat(Color("e8a8b4")), Vector3(-0.08, 0.24, -0.04))
		_sphere(head, 0.07, _mat(Color("e8a8b4")), Vector3(0.08, 0.24, -0.04))


func _build_accessory(head: Node3D) -> void:
	var acc := str(recipe.get("accessory", "none"))
	if acc == "glasses":
		## Thin wine wire rings. Eyes stay behind this plane.
		var g_z := -0.268
		var g_mat := _mat(Color("3a1820"), 0.25)
		_torus_mat(head, 0.072, 0.0038, Vector3(-0.082, 0.036, g_z), g_mat)
		_torus_mat(head, 0.072, 0.0038, Vector3(0.082, 0.036, g_z), g_mat)
		## One continuous thin wine bridge joining the inner rims.
		_cap(head, 0.0032, 0.042, g_mat, Vector3(0.0, 0.042, g_z), Vector3(0, 0, 90))
	elif acc == "flower":
		if str(recipe.get("hat", "none")) != "sun":
			_attach_sunflower(head, Vector3(0.22, 0.16, -0.04), 0.9)
	elif acc == "scarf":
		_cyl(head, 0.16, 0.16, 0.05, _mat(Color("e8b4b8")), Vector3(0, -0.22, 0.0))


func _attach_sunflower(parent: Node3D, pos: Vector3, scl: float = 1.0) -> void:
	var flower := Node3D.new()
	flower.name = "Sunflower"
	flower.position = pos
	flower.scale = Vector3.ONE * scl
	flower.rotation_degrees = Vector3(15, -25, 18)
	parent.add_child(flower)
	var petal_m := _mat(PETAL, 0.45)
	var petal_d := _mat(Color("e8942a"), 0.5)
	for i in 10:
		var a := float(i) / 10.0 * TAU
		var deep := (i % 2) == 0
		_sphere(flower, 0.028, petal_d if deep else petal_m, Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.01 if deep else 0.0), Vector3(0.7, 1.55, 0.55))
	for i in 8:
		var a := (float(i) + 0.5) / 8.0 * TAU
		_sphere(flower, 0.024, petal_m, Vector3(cos(a) * 0.095, sin(a) * 0.095, 0.01), Vector3(0.65, 1.4, 0.5))
	_sphere(flower, 0.045, _mat(SEED, 0.55), Vector3(0, 0, 0.02), Vector3(1.0, 1.0, 0.55))


## Four diamond tips plus a bright core. Sized so the star stays inside the eye disc.
func _star_sparkle(parent: Node3D, mat: Material, pos: Vector3, arm: float) -> void:
	var tip_r := arm * 0.42
	var reach := arm * 0.70
	_sphere(parent, tip_r, mat, pos + Vector3(0, reach, 0), Vector3(0.38, 1.70, 0.08))
	_sphere(parent, tip_r, mat, pos + Vector3(0, -reach, 0), Vector3(0.38, 1.70, 0.08))
	_sphere(parent, tip_r, mat, pos + Vector3(reach, 0, 0), Vector3(1.70, 0.38, 0.08))
	_sphere(parent, tip_r, mat, pos + Vector3(-reach, 0, 0), Vector3(1.70, 0.38, 0.08))
	_sphere(parent, arm * 0.34, mat, pos, Vector3(1.2, 1.2, 0.08))


func _torus_mat(parent: Node3D, r: float, t: float, pos: Vector3, mat: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = r - t
	mesh.outer_radius = r + t
	mesh.rings = 22
	mesh.ring_segments = 16
	_mesh(parent, mesh, mat, pos, Vector3(90, 0, 0))


func _torus(parent: Node3D, r: float, t: float, pos: Vector3) -> void:
	_torus_mat(parent, r, t, pos, _mat(Color("1a1a1a"), 0.25))
