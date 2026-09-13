extends Node3D
class_name BakeryWorld
## Voxel remake of Sunshine’s Bakery, Irondale — from the 4× video stills.
## Walk: sidewalk + mailbox → 2231 white/pink → yellow board ramp → 2229
## green cottage → tan deck + green-roof pavilion → fenced lawn. Boxes only.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const MascotScript := preload("res://scripts/explore/sunshine_mascot.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const WHITE := Color("f4f1eb")
const PINK := Color("e8b4b8")
const PINK_DK := Color("d49aa0")
const WINE := Color("6b2d3c")
const GOLD := Color("c4922a")
const GRASS := Color("4f9c38")
const DIRT := Color("6a4a28")
const CONCRETE := Color("d8d4cc")
const SIDEWALK := Color("d2cec4")
const DECK := Color("ead9a8")
const DECK_GAP := Color("cbb47a")
const YELLOW := Color("e8d078")
const YELLOW_DK := Color("c9b05a")
const GREEN_SIDING := Color("84c45e")
const GREEN_STRIPE := Color("6eae4c")
const GREEN_ROOF := Color("86dc5a")
const GREEN_ROOF_DK := Color("5aaf38")
const SHINGLE := Color("2a2624")
const PEACH := Color("f4c6b0")
const NEON_OPEN := Color("7cff9a")
const NEON_COFFEE := Color("ff8ad4")
const LEAF := Color("2f6a28")
const FLOWER := Color("d8a8d0")
const BARK := Color("3a2416")
const FENCE := Color("c4a66a")
const FENCE_DK := Color("a88850")
const BEIGE := Color("e6d8c2")
const MAROON := Color("6e2444")
const BLACK := Color("1a1a1c")
const CHAR := Color("2a2a2c")
const GLASS := Color("6a8894")
const TRASH := Color("6e7276")
const HYDRANT := Color("f0d030")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")
const PICNIC := Color("3a3a3c")

var _player: PlayerExplorer
var _front_z: float = 0.48
var _shop_w: float = 7.4
var _shop_h: float = 3.55
var _shop_d: float = 6.6
var _wall: float = 0.30
var _door_w: float = 2.2
var _door_h: float = 2.35
var _deck_y: float = 1.08


func setup(player: PlayerExplorer) -> void:
	_player = player
	_build_environment()
	_build_ground()
	_build_front_yard()
	_build_bakery()
	_build_green_cottage()
	_build_stairs_and_ramp()
	_build_deck()
	_build_back_yard()
	_build_neighbor()
	_build_staff()
	_spawn_collectibles()


func _mat(c: Color) -> StandardMaterial3D:
	return VoxelKit.flat(c)


func _box(size: Vector3, pos: Vector3, color: Color, collide: bool = true, rot_y: float = 0.0, rot_x: float = 0.0) -> Node3D:
	return VoxelKit.add_box(self, size, pos, _mat(color), collide, rot_y, rot_x)


func _sign(text: String, pos: Vector3, font_size: int, color: Color, rot_y_deg: float = 180.0) -> Label3D:
	return VoxelKit.add_sign(self, text, pos, font_size, color, rot_y_deg)


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var we := Environment.new()
	we.background_mode = Environment.BG_COLOR
	we.background_color = Color("87c8f0")
	we.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.ambient_light_color = Color("d0e0b8")
	we.ambient_light_energy = 0.44
	we.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = we
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color("fff4d0")
	sun.light_energy = 1.12
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	# One grass collider. Thin paths/deck boards stay visual so the capsule
	# (bottom ≈ 0.12) never clips a y≈0.1 floor.
	_box(Vector3(56, 0.5, 56), Vector3(1.5, -0.25, 4), GRASS)
	_box(Vector3(56, 0.35, 56), Vector3(1.5, -0.7, 4), DIRT, false)
	# Street + sidewalk in front of spawn (player at z=-8.2).
	_box(Vector3(22, 0.1, 3.2), Vector3(0, 0.05, -12.2), Color("b8b4ac"), false)
	_box(Vector3(18, 0.1, 1.7), Vector3(0, 0.06, -9.7), SIDEWALK, false)
	# Concrete walk spawn → bakery porch (+Z). Centerline stays open for MOVE.
	_box(Vector3(2.15, 0.1, 11.2), Vector3(0, 0.06, -3.6), CONCRETE, false)
	_box(Vector3(4.6, 0.1, 2.4), Vector3(0.35, 0.06, 0.15), CONCRETE, false)
	# Curved path (4× stills): porch → 2229 green cottage.
	_box(Vector3(2.2, 0.1, 1.15), Vector3(2.15, 0.06, -3.15), CONCRETE, false)
	_box(Vector3(2.4, 0.1, 1.15), Vector3(3.55, 0.06, -2.15), CONCRETE, false, deg_to_rad(-28.0))
	_box(Vector3(1.35, 0.1, 2.4), Vector3(4.85, 0.06, -0.85), CONCRETE, false)
	_box(Vector3(2.6, 0.1, 1.2), Vector3(6.15, 0.06, 0.35), CONCRETE, false, deg_to_rad(-18.0))
	_box(Vector3(2.4, 0.1, 1.15), Vector3(7.55, 0.06, 1.15), CONCRETE, false)
	_box(Vector3(1.5, 0.1, 2.2), Vector3(8.35, 0.06, 2.2), CONCRETE, false)


func _build_front_yard() -> void:
	_mailbox(Vector3(-2.35, 0, -7.35))
	_hydrant(Vector3(-5.35, 0, -6.05))
	_lattice(Vector3(2.85, 0, -6.45))
	_picnic(Vector3(3.35, 0, -3.35), PICNIC)
	_picnic(Vector3(-3.25, 0, -3.85), PICNIC)
	# Logo-girl stays on the peach sign. A walk-up mascot sits off the path
	# so the hero view is the two-tone shop, not a giant chibi.
	var mascot: Node3D = MascotScript.new()
	mascot.position = Vector3(-3.4, 0, -1.2)
	mascot.rotation.y = 0.55
	mascot.scale = Vector3(0.72, 0.72, 0.72)
	add_child(mascot)


func _mailbox(pos: Vector3) -> void:
	# Modern black post box + pink flag (4× still p_00).
	_box(Vector3(0.28, 1.15, 0.24), pos + Vector3(0, 0.58, 0), BLACK)
	_box(Vector3(0.22, 0.22, 0.22), pos + Vector3(0, 0.1, 0), BLACK, false)
	_box(Vector3(0.82, 0.72, 0.52), pos + Vector3(0, 1.38, 0), BLACK)
	_box(Vector3(0.7, 0.18, 0.44), pos + Vector3(0, 1.78, 0), BLACK, false)
	_box(Vector3(0.28, 0.08, 0.06), pos + Vector3(0.48, 1.48, 0), PINK, false)
	_sign("2231", pos + Vector3(0, 1.98, 0.02), 16, Color("fff6ea"), 180)


func _hydrant(pos: Vector3) -> void:
	_box(Vector3(0.22, 0.55, 0.22), pos + Vector3(0, 0.32, 0), HYDRANT, false)
	_box(Vector3(0.34, 0.12, 0.34), pos + Vector3(0, 0.62, 0), HYDRANT, false)
	_box(Vector3(0.12, 0.1, 0.28), pos + Vector3(0, 0.42, 0), GOLD, false)


func _lattice(pos: Vector3) -> void:
	_box(Vector3(0.14, 1.05, 0.14), pos + Vector3(-0.7, 0.55, 0), Color("9a8a6a"), false)
	_box(Vector3(0.14, 1.05, 0.14), pos + Vector3(0.7, 0.55, 0), Color("9a8a6a"), false)
	_box(Vector3(1.55, 0.95, 0.08), pos + Vector3(0, 1.05, 0), Color("c8b896"), false)
	for i in 4:
		_box(Vector3(1.4, 0.05, 0.06), pos + Vector3(0, 0.72 + i * 0.2, 0.02), Color("a89870"), false)
	for i in 5:
		_box(Vector3(0.05, 0.85, 0.06), pos + Vector3(-0.55 + i * 0.28, 1.05, 0.02), Color("a89870"), false)


func _picnic(pos: Vector3, top: Color) -> void:
	_box(Vector3(1.7, 0.08, 0.85), pos + Vector3(0, 0.78, 0), top, false)
	_box(Vector3(0.08, 0.74, 0.08), pos + Vector3(-0.7, 0.37, -0.28), CHAR, false)
	_box(Vector3(0.08, 0.74, 0.08), pos + Vector3(0.7, 0.37, -0.28), CHAR, false)
	_box(Vector3(0.08, 0.74, 0.08), pos + Vector3(-0.7, 0.37, 0.28), CHAR, false)
	_box(Vector3(0.08, 0.74, 0.08), pos + Vector3(0.7, 0.37, 0.28), CHAR, false)
	_box(Vector3(1.55, 0.07, 0.28), pos + Vector3(0, 0.46, -0.72), top, false)
	_box(Vector3(1.55, 0.07, 0.28), pos + Vector3(0, 0.46, 0.72), top, false)


func _build_bakery() -> void:
	var w := _shop_w
	var h := _shop_h
	var d := _shop_d
	var t := _wall
	var fz := _front_z
	var rz := _front_z + d
	var cz := fz + d * 0.5
	var cx := 0.15
	# Pink soffit / trim band under the eaves + corner posts (video landmark).
	_box(Vector3(w + 0.7, 0.28, d + 0.7), Vector3(cx, h + 0.06, cz), PINK, false)
	_box(Vector3(0.22, h + 0.2, 0.22), Vector3(cx - w * 0.5, h * 0.5, fz), PINK)
	_box(Vector3(0.22, h + 0.2, 0.22), Vector3(cx + w * 0.5, h * 0.5, fz), PINK)
	_box(Vector3(0.22, h + 0.2, 0.22), Vector3(cx - w * 0.5, h * 0.5, rz), PINK, false)
	# Walls (white). Front leaves a door gap on the +Z approach.
	_box(Vector3(t, h, d), Vector3(cx - w * 0.5 + t * 0.5, h * 0.5, cz), WHITE)
	_box(Vector3(t, h, d), Vector3(cx + w * 0.5 - t * 0.5, h * 0.5, cz), WHITE)
	_box(Vector3(w, h, t), Vector3(cx, h * 0.5, rz - t * 0.5), WHITE)
	var wing := (w - _door_w) * 0.5
	_box(Vector3(wing, h, t), Vector3(cx - (_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), WHITE)
	_box(Vector3(wing, h, t), Vector3(cx + (_door_w + wing) * 0.5, h * 0.5, fz + t * 0.5), WHITE)
	var lintel_h := h - _door_h
	_box(Vector3(_door_w + 0.1, lintel_h, t), Vector3(cx, _door_h + lintel_h * 0.5, fz + t * 0.5), WHITE)
	var jam := 0.22
	_box(Vector3(jam, _door_h, t), Vector3(cx - _door_w * 0.5 - jam * 0.5, _door_h * 0.5, fz + t * 0.5), WHITE)
	_box(Vector3(jam, _door_h, t), Vector3(cx + _door_w * 0.5 + jam * 0.5, _door_h * 0.5, fz + t * 0.5), WHITE)
	# Visual door (no collision). Large pink-framed display windows + neon.
	_box(Vector3(1.15, 2.15, 0.07), Vector3(cx, 1.12, fz - 0.02), Color("3a3a3e"), false)
	_box(Vector3(0.12, 0.12, 0.1), Vector3(cx + 0.42, 1.15, fz - 0.08), GOLD, false)
	_box(Vector3(2.15, 1.85, 0.12), Vector3(cx - 2.25, 1.95, fz - 0.03), PINK, false)
	_box(Vector3(1.85, 1.55, 0.08), Vector3(cx - 2.25, 1.95, fz - 0.1), GLASS, false)
	_sign("OPEN", Vector3(cx - 2.25, 1.95, fz - 0.18), 22, NEON_OPEN, 180)
	_box(Vector3(2.15, 1.85, 0.12), Vector3(cx + 2.35, 1.95, fz - 0.03), PINK, false)
	_box(Vector3(1.85, 1.55, 0.08), Vector3(cx + 2.35, 1.95, fz - 0.1), GLASS, false)
	_sign("COFFEE", Vector3(cx + 2.35, 1.95, fz - 0.18), 20, NEON_COFFEE, 180)
	_sign("2231", Vector3(cx + 1.55, 0.95, fz - 0.12), 18, Color("4a3034"), 180)
	# Peach fascia + logo-girl cube + readable shop name.
	_box(Vector3(4.4, 0.62, 0.16), Vector3(cx, 3.18, fz - 0.14), PEACH, false)
	VoxelKit.add_box(self, Vector3(0.78, 0.78, 0.14), Vector3(cx - 2.05, 3.18, fz - 0.18), VoxelKit.tex(LOGO_GIRL), false)
	_sign("SUNSHINE'S BAKERY", Vector3(cx + 0.25, 3.2, fz - 0.26), 30, WINE, 180)
	# Low white roof over the shop (deck pavilion is the bright green one).
	_box(Vector3(w + 0.8, 0.28, d + 0.7), Vector3(cx, h + 0.22, cz), WHITE)
	# Interior floor visual-only. Counter + pastry case at the back.
	_box(Vector3(w - t * 2.2, 0.08, d - 1.0), Vector3(cx, 0.06, cz + 0.15), Color("e8dfd0"), false)
	_box(Vector3(3.2, 1.05, 0.72), Vector3(cx, 0.6, fz + 5.15), Color("5a3a22"))
	_box(Vector3(2.95, 0.58, 0.42), Vector3(cx, 1.38, fz + 5.1), GLASS, false)
	for i in 3:
		_box(Vector3(0.28, 0.2, 0.28), Vector3(cx - 0.9 + i * 0.85, 1.2, fz + 5.02), [GOLD, PINK, Color("f3d9a8")][i], false)
	_sign("FRESH CUBES", Vector3(cx, 2.08, fz + 5.35), 20, Color("fff6ea"), 180)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(cx, 2.75, fz + 2.3)
	lamp.light_color = Color("ffe4b8")
	lamp.light_energy = 1.1
	lamp.omni_range = 9
	add_child(lamp)
	# Trash can by the front corner (video).
	_box(Vector3(0.38, 0.85, 0.38), Vector3(cx - 3.55, 0.45, fz - 1.15), TRASH, false)
	_box(Vector3(0.42, 0.08, 0.42), Vector3(cx - 3.55, 0.9, fz - 1.15), Color("4a4e52"), false)


func _build_green_cottage() -> void:
	# 2229 — small green clapboard cottage on the curved path (still p_04).
	var o := Vector3(8.55, 0, 0.15)
	_box(Vector3(4.35, 2.55, 3.35), o + Vector3(0, 1.28, 0.15), GREEN_SIDING)
	for i in 8:
		_box(Vector3(4.3, 0.06, 3.3), o + Vector3(0, 0.28 + i * 0.3, 0.18), GREEN_STRIPE, false)
	_box(Vector3(4.9, 0.26, 3.85), o + Vector3(0, 2.68, 0.15), SHINGLE)
	_box(Vector3(3.5, 0.24, 2.85), o + Vector3(0, 2.96, 0.15), SHINGLE, false)
	_box(Vector3(2.15, 0.2, 1.85), o + Vector3(0, 3.2, 0.15), SHINGLE, false)
	_box(Vector3(0.9, 0.16, 0.9), o + Vector3(0, 3.38, 0.15), SHINGLE, false)
	_box(Vector3(0.16, 2.7, 0.16), o + Vector3(-2.12, 1.35, -1.48), WHITE, false)
	_box(Vector3(0.16, 2.7, 0.16), o + Vector3(2.12, 1.35, -1.48), WHITE, false)
	_box(Vector3(0.82, 1.85, 0.1), o + Vector3(-0.15, 0.95, -1.52), Color("2a2a2e"), false)
	_box(Vector3(0.18, 0.18, 0.06), o + Vector3(0.18, 1.05, -1.58), GOLD, false)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(-1.25, 1.72, -1.5), WHITE, false)
	_box(Vector3(0.54, 0.54, 0.06), o + Vector3(-1.25, 1.72, -1.56), GLASS, false)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(1.2, 1.72, -1.5), WHITE, false)
	_box(Vector3(0.54, 0.54, 0.06), o + Vector3(1.2, 1.72, -1.56), GLASS, false)
	_box(Vector3(0.55, 1.15, 0.55), o + Vector3(2.55, 0.55, -1.15), LEAF, false)
	_sign("2229", o + Vector3(0.55, 2.15, -1.62), 18, Color("fff6ea"), 180)


func _build_stairs_and_ramp() -> void:
	# Yellow stairs (left of porch) + ramp (right). Hidden ramps carry the capsule.
	# Stairs sit off the +Z door line so smoke can walk into the shop.
	var stair_x := -3.55
	for i in 6:
		var rise := 0.18
		var y := (i + 1) * rise * 0.5
		var z := _front_z - 1.55 + i * 0.32
		_box(Vector3(1.35, rise, 0.34), Vector3(stair_x, (i + 0.5) * rise, z), YELLOW, false)
	_box(Vector3(0.1, 1.15, 2.15), Vector3(stair_x - 0.72, 0.7, _front_z - 0.7), YELLOW, false)
	_box(Vector3(0.1, 1.15, 2.15), Vector3(stair_x + 0.72, 0.7, _front_z - 0.7), YELLOW, false)
	_box(Vector3(1.45, 0.08, 0.08), Vector3(stair_x, 1.18, _front_z - 1.7), YELLOW_DK, false)
	# Walkable collider under the steps (gentle slope).
	_box(Vector3(1.2, 0.16, 2.4), Vector3(stair_x, 0.52, _front_z - 0.85), YELLOW_DK, true, 0.0, deg_to_rad(-22.0))
	# Yellow treated-pine board ramp (still p_02) up onto the covered deck.
	var rx := 4.15
	_box(Vector3(1.85, 0.14, 5.1), Vector3(rx, 0.58, 1.55), YELLOW, true, 0.0, deg_to_rad(-15.0))
	for i in 9:
		_box(Vector3(1.7, 0.04, 0.22), Vector3(rx, 0.22 + i * 0.1, 0.05 + i * 0.42), YELLOW_DK, false, 0.0, deg_to_rad(-15.0))
	_box(Vector3(0.12, 1.08, 5.0), Vector3(rx - 0.95, 1.0, 1.55), YELLOW, true, 0.0, deg_to_rad(-15.0))
	_box(Vector3(0.12, 1.08, 5.0), Vector3(rx + 0.95, 1.0, 1.55), YELLOW, true, 0.0, deg_to_rad(-15.0))
	for i in 6:
		_box(Vector3(0.1, 0.95, 0.1), Vector3(rx - 0.95, 0.55 + i * 0.12, 0.2 + i * 0.55), YELLOW_DK, false)
		_box(Vector3(0.1, 0.95, 0.1), Vector3(rx + 0.95, 0.55 + i * 0.12, 0.2 + i * 0.55), YELLOW_DK, false)
	_sign("NO SMOKING", Vector3(rx + 1.15, 1.35, 2.55), 16, Color("fff6ea"), -90)


func _build_deck() -> void:
	# Elevated tan deck + bright green pavilion. Slab collides so you cannot
	# walk through it at ground height; use the ramp / stairs.
	var origin := Vector3(7.15, _deck_y, 5.95)
	var dw := 8.6
	var dd := 8.0
	_box(Vector3(dw, 0.18, dd), origin, DECK)
	# Board stripes (visual).
	for i in 10:
		_box(Vector3(dw - 0.3, 0.02, 0.08), origin + Vector3(0, 0.1, -3.4 + i * 0.72), DECK_GAP, false)
	# Yellow railings — collide so you do not step off / clip the pavilion.
	var rail_h := 0.95
	_box(Vector3(dw, 0.08, 0.1), origin + Vector3(0, rail_h, -dd * 0.5 + 0.08), YELLOW)
	_box(Vector3(dw, 0.08, 0.1), origin + Vector3(0, rail_h, dd * 0.5 - 0.08), YELLOW)
	_box(Vector3(0.1, 0.08, dd), origin + Vector3(-dw * 0.5 + 0.08, rail_h, 0), YELLOW)
	_box(Vector3(0.1, 0.08, dd), origin + Vector3(dw * 0.5 - 0.08, rail_h, 0), YELLOW)
	for i in 7:
		_box(Vector3(0.1, rail_h, 0.1), origin + Vector3(-dw * 0.5 + 0.08, rail_h * 0.5, -3.2 + i * 1.05), YELLOW, false)
		_box(Vector3(0.1, rail_h, 0.1), origin + Vector3(dw * 0.5 - 0.08, rail_h * 0.5, -3.2 + i * 1.05), YELLOW, false)
	# Posts + hanging planters.
	for p in [Vector3(-2.6, 0, -2.2), Vector3(2.4, 0, -2.2), Vector3(-2.6, 0, 2.4), Vector3(2.4, 0, 2.4)]:
		_box(Vector3(0.22, 2.55, 0.22), origin + p + Vector3(0, 1.28, 0), YELLOW, false)
		_box(Vector3(0.58, 0.42, 0.58), origin + p + Vector3(0, 1.85, 0), LEAF, false)
		_box(Vector3(0.22, 0.16, 0.22), origin + p + Vector3(0.18, 1.92, 0.12), FLOWER, false)
		_box(Vector3(0.22, 0.18, 0.22), origin + p + Vector3(0, 1.58, 0), Color("c8b878"), false)
	# Bright green pavilion roof (the video landmark).
	_box(Vector3(dw - 0.4, 0.22, dd - 0.4), origin + Vector3(0, 2.72, 0), GREEN_ROOF)
	_box(Vector3(dw + 0.35, 0.16, dd + 0.35), origin + Vector3(0, 2.92, 0), GREEN_ROOF)
	_box(Vector3(3.6, 0.14, 3.6), origin + Vector3(0, 3.12, 0), GREEN_ROOF_DK, false)
	# 2229 green wall + black paneled door + welcome mat (still p_12).
	_box(Vector3(5.2, 2.45, 0.28), origin + Vector3(-0.35, 1.18, -3.88), GREEN_SIDING)
	for i in 6:
		_box(Vector3(5.15, 0.06, 0.26), origin + Vector3(-0.35, 0.35 + i * 0.36, -3.86), GREEN_STRIPE, false)
	_box(Vector3(0.92, 1.95, 0.1), origin + Vector3(-0.15, 1.02, -4.06), Color("2a2a2e"), false)
	_box(Vector3(0.28, 0.32, 0.06), origin + Vector3(-0.32, 1.72, -4.12), GLASS, false)
	_box(Vector3(0.28, 0.32, 0.06), origin + Vector3(0.02, 1.72, -4.12), GLASS, false)
	_box(Vector3(0.28, 0.32, 0.06), origin + Vector3(-0.32, 1.32, -4.12), GLASS, false)
	_box(Vector3(0.28, 0.32, 0.06), origin + Vector3(0.02, 1.32, -4.12), GLASS, false)
	_box(Vector3(0.1, 0.16, 0.06), origin + Vector3(0.32, 1.05, -4.14), GOLD, false)
	_box(Vector3(0.7, 0.06, 0.42), origin + Vector3(-0.15, 0.12, -4.22), Color("3a3228"), false)
	_box(Vector3(1.15, 1.15, 0.1), origin + Vector3(1.45, 1.55, -4.02), WHITE, false)
	_box(Vector3(0.92, 0.92, 0.08), origin + Vector3(1.45, 1.55, -4.08), GLASS, false)
	_sign("WELCOME", origin + Vector3(-0.15, 0.28, -4.28), 12, Color("fff6ea"), 180)
	# Baby gate in the yellow rail (still p_20).
	_box(Vector3(1.15, 0.95, 0.08), origin + Vector3(-3.35, 0.55, -dd * 0.5 + 0.12), YELLOW, false)
	_box(Vector3(0.16, 0.12, 0.12), origin + Vector3(-2.72, 0.72, -dd * 0.5 + 0.18), CHAR, false)
	_sign("EMPLOYEES ONLY", origin + Vector3(1.45, 2.22, -4.16), 14, Color("fff6ea"), 180)
	# Exposed joists + cream roll-up shades under the cover.
	for i in 6:
		_box(Vector3(dw - 1.2, 0.08, 0.1), origin + Vector3(0, 2.52, -2.4 + i * 0.85), Color("d8c48a"), false)
	_box(Vector3(1.6, 1.15, 0.06), origin + Vector3(-1.1, 1.85, 3.85), Color("efe6d2"), false)
	_box(Vector3(1.6, 1.15, 0.06), origin + Vector3(1.4, 1.85, 3.85), Color("efe6d2"), false)
	# Cafe tables + woven chairs + hanging egg chairs (video deck).
	_cafe_set(origin + Vector3(-1.3, 0.12, 0.4))
	_cafe_set(origin + Vector3(1.8, 0.12, 1.1))
	_cafe_set(origin + Vector3(0.2, 0.12, 2.6))
	_egg_chair(origin + Vector3(-3.2, 0.12, 1.6))
	_egg_chair(origin + Vector3(3.15, 0.12, 0.8))
	_sign("NO SMOKING", origin + Vector3(-3.6, 1.05, 2.2), 16, Color("fff6ea"), 90)
	var glow := OmniLight3D.new()
	glow.position = origin + Vector3(0, 2.2, 0)
	glow.light_color = Color("fff2c8")
	glow.light_energy = 0.7
	glow.omni_range = 8
	add_child(glow)


func _cafe_set(pos: Vector3) -> void:
	_box(Vector3(0.85, 0.08, 0.85), pos + Vector3(0, 0.72, 0), CHAR, false)
	_box(Vector3(0.1, 0.7, 0.1), pos + Vector3(0, 0.35, 0), BLACK, false)
	_chair(pos + Vector3(-0.7, 0, 0.15))
	_chair(pos + Vector3(0.7, 0, -0.1), PI)


func _chair(pos: Vector3, rot_y: float = 0.0) -> void:
	_box(Vector3(0.38, 0.06, 0.38), pos + Vector3(0, 0.46, 0), CHAR, false, rot_y)
	_box(Vector3(0.38, 0.42, 0.06), pos + Vector3(0, 0.7, -0.16), CHAR, false, rot_y)
	_box(Vector3(0.06, 0.44, 0.06), pos + Vector3(-0.14, 0.22, 0.12), BLACK, false, rot_y)
	_box(Vector3(0.06, 0.44, 0.06), pos + Vector3(0.14, 0.22, 0.12), BLACK, false, rot_y)


func _egg_chair(pos: Vector3) -> void:
	_box(Vector3(0.08, 1.55, 0.08), pos + Vector3(0, 1.55, 0), YELLOW_DK, false)
	_box(Vector3(0.72, 0.85, 0.62), pos + Vector3(0, 0.85, 0.05), CHAR, false)
	_box(Vector3(0.55, 0.22, 0.5), pos + Vector3(0, 0.52, 0.08), Color("4a4a4e"), false)


func _build_back_yard() -> void:
	_picnic(Vector3(-1.1, 0, 10.6), CHAR)
	_box(Vector3(1.15, 0.08, 0.32), Vector3(-4.4, 0.42, 12.4), CHAR, false)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(-4.85, 0.2, 12.4), BLACK, false)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(-3.95, 0.2, 12.4), BLACK, false)
	_box(Vector3(1.15, 0.08, 0.32), Vector3(2.6, 0.42, 13.1), CHAR, false)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(2.15, 0.2, 13.1), BLACK, false)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(3.05, 0.2, 13.1), BLACK, false)
	# Privacy fence (video look-out).
	for i in 12:
		var x := -8.0 + i * 1.55
		_box(Vector3(0.12, 1.55, 0.12), Vector3(x, 0.8, 15.4), FENCE)
		_box(Vector3(1.5, 1.35, 0.08), Vector3(x + 0.75, 0.85, 15.4), FENCE_DK)
	for i in 8:
		_box(Vector3(0.12, 1.55, 0.12), Vector3(-8.2, 0.8, 4.2 + i * 1.4), FENCE, false)
		_box(Vector3(0.08, 1.35, 1.35), Vector3(-8.2, 0.85, 4.9 + i * 1.4), FENCE_DK, false)
	_tree(Vector3(-6.4, 0, 12.8), 4.4)
	_tree(Vector3(3.8, 0, 14.2), 4.0)
	_tree(Vector3(9.6, 0, 11.5), 3.8)
	_tree(Vector3(-7.2, 0, -4.8), 3.6)
	_tree(Vector3(10.8, 0, -6.2), 3.5)
	_tree(Vector3(-5.8, 0, 8.6), 3.2)


func _tree(pos: Vector3, height: float) -> void:
	_box(Vector3(0.55, height * 0.5, 0.55), pos + Vector3(0, height * 0.25, 0), BARK, false)
	_box(Vector3(2.1, 1.9, 2.1), pos + Vector3(0, height * 0.68, 0), LEAF, false)
	_box(Vector3(1.35, 1.2, 1.35), pos + Vector3(0.4, height * 0.92, 0.2), LEAF, false)


func _build_neighbor() -> void:
	# Beige ranch + maroon/purple metal roof (stills p_00 / p_22 / p_23).
	var o := Vector3(-11.4, 0, -1.2)
	_box(Vector3(9.2, 2.45, 3.4), o + Vector3(0, 1.22, 0), BEIGE)
	_box(Vector3(9.8, 0.22, 3.9), o + Vector3(0, 2.58, 0), MAROON)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(-2.6, 1.65, -1.75), GLASS, false)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(0.1, 1.65, -1.75), GLASS, false)
	_box(Vector3(0.72, 0.72, 0.08), o + Vector3(2.8, 1.65, -1.75), GLASS, false)
	_box(Vector3(0.7, 1.85, 2.4), o + Vector3(5.1, 0.95, 0.2), Color("c4b08a"), false)
	# Rear neighbor beyond the fence + wooden stair (still p_23).
	_box(Vector3(8.5, 2.5, 3.2), Vector3(1.2, 1.25, 18.2), BEIGE, false)
	_box(Vector3(9.1, 0.2, 3.6), Vector3(1.2, 2.6, 18.2), MAROON, false)
	_box(Vector3(2.2, 0.12, 0.7), Vector3(-7.6, 0.55, 8.4), FENCE, false, 0.0, deg_to_rad(-18.0))
	_box(Vector3(0.1, 0.9, 2.0), Vector3(-8.3, 0.9, 8.6), FENCE, false, 0.0, deg_to_rad(-18.0))


func _villager(pos: Vector3, robe: Color, rot_y: float = 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	root.add_to_group("village_npc")
	add_child(root)
	VoxelKit.add_box(root, Vector3(0.55, 1.0, 0.34), Vector3(0, 0.72, 0), VoxelKit.flat(robe), false)
	VoxelKit.add_box(root, Vector3(0.46, 0.46, 0.46), Vector3(0, 1.42, 0), VoxelKit.flat(Color("e6c8a0")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(-0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)
	VoxelKit.add_box(root, Vector3(0.18, 0.55, 0.18), Vector3(0.2, 0.28, 0), VoxelKit.flat(Color("3a2416")), false)


func _build_staff() -> void:
	_villager(Vector3(-2.35, 0, -4.9), ROBE_BROWN, 0.5)
	_villager(Vector3(3.35, 0, -4.5), ROBE_GREEN, -0.4)
	_villager(Vector3(-2.4, 0, 2.4), ROBE_WINE, 2.6)
	_villager(Vector3(6.2, _deck_y + 0.05, 6.4), ROBE_BROWN, 3.3)


func _spawn_collectibles() -> void:
	var spots: Array[Dictionary] = [
		{"pos": Vector3(0.85, 0.7, -7.05), "kind": "croissant"},
		{"pos": Vector3(-1.0, 0.55, 3.55), "kind": "croissant"},
		{"pos": Vector3(1.15, 0.5, 2.15), "kind": "drink"},
	]
	for row in spots:
		_place_pickup(row["pos"], str(row["kind"]), false)


func _place_pickup(pos: Vector3, kind: String, fresh: bool) -> void:
	var item := CollectiblePickup.new()
	item.kind = kind
	item.is_fresh_batch = fresh
	item.position = pos
	item.collected.connect(_on_collected)
	add_child(item)


func _on_collected(kind: String) -> void:
	var hud := get_tree().get_first_node_in_group("explore_hud")
	if hud and hud.has_method("on_collected"):
		hud.on_collected(kind)
