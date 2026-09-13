extends Node3D
class_name BakeryWorld
## Voxel remake of Sunshine’s Bakery, Irondale — from Ronald’s shop video.
## Walk: front yard → pink-trim bakery → yellow stairs/ramp → tan deck
## → green-roof pavilion → fenced back lawn. Boxes only, not photoreal.

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")
const MascotScript := preload("res://scripts/explore/sunshine_mascot.gd")
const LOGO_GIRL := "res://assets/branding/sunshine-logo-girl.jpg"

const WHITE := Color("f3f0ea")
const PINK := Color("e8b4b8")
const WINE := Color("6b2d3c")
const GOLD := Color("c4922a")
const GRASS := Color("4a9a32")
const DIRT := Color("6a4a28")
const CONCRETE := Color("d5d1c8")
const SIDEWALK := Color("cfcabe")
const DECK := Color("e4d3a4")
const DECK_GAP := Color("c8b37a")
const YELLOW := Color("e8d070")
const YELLOW_DK := Color("c4a84a")
const GREEN_SIDING := Color("8fbf6a")
const GREEN_ROOF := Color("7ed45a")
const GREEN_ROOF_DK := Color("5aa83c")
const SHINGLE := Color("3a3230")
const PEACH := Color("f3c4b0")
const NEON_OPEN := Color("7cff9a")
const NEON_COFFEE := Color("ff8ad4")
const LEAF := Color("2f6a28")
const BARK := Color("3a2416")
const FENCE := Color("7a6244")
const FENCE_DK := Color("5a4630")
const BEIGE := Color("e4d8c4")
const MAROON := Color("6a3038")
const BLACK := Color("1c1c1e")
const CHAR := Color("2a2a2c")
const GLASS := Color("6a8a96")
const TRASH := Color("6e7276")
const HYDRANT := Color("f0d030")
const ROBE_BROWN := Color("8b5a2b")
const ROBE_GREEN := Color("3d6b32")
const ROBE_WINE := Color("6b2d3c")

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
	# Concrete walk spawn → bakery door (+Z). Centerline stays open.
	_box(Vector3(2.05, 0.1, 11.2), Vector3(0, 0.06, -3.6), CONCRETE, false)
	_box(Vector3(4.6, 0.1, 2.4), Vector3(0.4, 0.06, 0.15), CONCRETE, false)
	# Winding path toward the green cottage (off the walk line).
	_box(Vector3(5.2, 0.1, 1.15), Vector3(4.4, 0.06, -2.1), CONCRETE, false)
	_box(Vector3(1.2, 0.1, 4.2), Vector3(7.2, 0.06, -0.2), CONCRETE, false)


func _build_front_yard() -> void:
	_mailbox(Vector3(-3.7, 0, -6.55))
	_hydrant(Vector3(-6.1, 0, -6.2))
	_lattice(Vector3(2.35, 0, -5.55))
	_picnic(Vector3(2.7, 0, -3.15), Color("c8c4bc"))
	_picnic(Vector3(-2.55, 0, -3.55), Color("b8b4ac"))
	# Parked trucks / SUV as simple boxes (video stills).
	_box(Vector3(3.4, 1.15, 1.45), Vector3(-5.6, 0.7, 1.8), WHITE, false)
	_box(Vector3(1.15, 0.85, 1.4), Vector3(-4.15, 0.95, 1.8), WHITE, false)
	_box(Vector3(0.42, 0.42, 0.22), Vector3(-6.85, 0.38, 1.15), BLACK, false)
	_box(Vector3(0.42, 0.42, 0.22), Vector3(-6.85, 0.38, 2.45), BLACK, false)
	_box(Vector3(2.6, 1.2, 1.5), Vector3(6.4, 0.72, -4.6), WHITE, false)
	_box(Vector3(0.42, 0.42, 0.22), Vector3(5.35, 0.38, -5.2), BLACK, false)
	var mascot: Node3D = MascotScript.new()
	mascot.position = Vector3(-2.15, 0, -1.55)
	mascot.rotation.y = 0.35
	add_child(mascot)


func _mailbox(pos: Vector3) -> void:
	_box(Vector3(0.38, 1.05, 0.32), pos + Vector3(0, 0.55, 0), BLACK)
	_box(Vector3(0.72, 0.58, 0.48), pos + Vector3(0, 1.28, 0), BLACK)
	_box(Vector3(0.26, 0.08, 0.06), pos + Vector3(0.42, 1.38, 0), PINK, false)
	_sign("2231", pos + Vector3(0, 1.85, 0.02), 16, Color("fff6ea"), 180)


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
	# Pink soffit / trim band under the eaves + corner posts.
	_box(Vector3(w + 0.55, 0.18, d + 0.55), Vector3(cx, h + 0.02, cz), PINK, false)
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
	# Visual door (no collision) + pink window frame.
	_box(Vector3(1.15, 2.15, 0.07), Vector3(cx, 1.12, fz - 0.02), Color("3a3a3e"), false)
	_box(Vector3(0.12, 0.12, 0.1), Vector3(cx + 0.42, 1.15, fz - 0.08), GOLD, false)
	_box(Vector3(1.15, 1.05, 0.1), Vector3(cx - 2.15, 2.15, fz - 0.03), PINK, false)
	_box(Vector3(0.95, 0.85, 0.08), Vector3(cx - 2.15, 2.15, fz - 0.08), GLASS, false)
	_sign("OPEN", Vector3(cx - 2.15, 2.15, fz - 0.16), 18, NEON_OPEN, 180)
	_box(Vector3(1.15, 1.05, 0.1), Vector3(cx + 2.2, 2.15, fz - 0.03), PINK, false)
	_box(Vector3(0.95, 0.85, 0.08), Vector3(cx + 2.2, 2.15, fz - 0.08), GLASS, false)
	_sign("COFFEE", Vector3(cx + 2.2, 2.15, fz - 0.16), 16, NEON_COFFEE, 180)
	_sign("2231", Vector3(cx + 1.55, 1.55, fz - 0.12), 18, Color("4a3034"), 180)
	# Peach fascia + logo cube + readable shop name (video sign).
	_box(Vector3(3.8, 0.58, 0.14), Vector3(cx, 3.12, fz - 0.14), PEACH, false)
	VoxelKit.add_box(self, Vector3(0.7, 0.7, 0.14), Vector3(cx - 1.95, 3.12, fz - 0.16), VoxelKit.tex(LOGO_GIRL), false)
	_sign("SUNSHINE'S BAKERY", Vector3(cx + 0.2, 3.14, fz - 0.24), 28, WINE, 180)
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
	# 2229 — green horizontal siding, pitched dark-shingle roof, white trim.
	var o := Vector3(8.6, 0, 0.4)
	_box(Vector3(4.2, 2.7, 3.6), o + Vector3(0, 1.35, 0), GREEN_SIDING)
	for i in 6:
		_box(Vector3(4.15, 0.08, 3.55), o + Vector3(0, 0.45 + i * 0.42, 0.02), Color("7eae5c"), false)
	_box(Vector3(4.9, 0.28, 4.2), o + Vector3(0, 2.78, 0), SHINGLE)
	_box(Vector3(3.4, 0.28, 3.0), o + Vector3(0, 3.08, 0), SHINGLE, false)
	_box(Vector3(2.0, 0.22, 1.8), o + Vector3(0, 3.32, 0), SHINGLE, false)
	_box(Vector3(0.16, 2.85, 0.16), o + Vector3(-2.1, 1.45, -1.8), WHITE, false)
	_box(Vector3(0.16, 2.85, 0.16), o + Vector3(2.1, 1.45, -1.8), WHITE, false)
	_box(Vector3(0.85, 1.85, 0.1), o + Vector3(-0.7, 0.95, -1.85), Color("2c2c30"), false)
	_box(Vector3(0.7, 0.7, 0.08), o + Vector3(0.85, 1.7, -1.85), GLASS, false)
	_box(Vector3(0.82, 0.82, 0.1), o + Vector3(0.85, 1.7, -1.82), WHITE, false)
	_sign("2229", o + Vector3(0.2, 2.15, -1.92), 18, Color("fff6ea"), 180)


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
	# Right-side accessibility ramp up onto the tan deck.
	var rx := 4.15
	_box(Vector3(1.55, 0.16, 4.6), Vector3(rx, 0.55, 1.55), YELLOW, true, 0.0, deg_to_rad(-14.5))
	_box(Vector3(0.12, 1.05, 4.4), Vector3(rx - 0.82, 0.95, 1.55), YELLOW, true, 0.0, deg_to_rad(-14.5))
	_box(Vector3(0.12, 1.05, 4.4), Vector3(rx + 0.82, 0.95, 1.55), YELLOW, true, 0.0, deg_to_rad(-14.5))
	_sign("NO SMOKING", Vector3(rx + 0.95, 1.35, 2.4), 16, Color("fff6ea"), -90)


func _build_deck() -> void:
	# Elevated tan deck + bright green pavilion. Slab collides so you cannot
	# walk through it at ground height; use the ramp / stairs.
	var origin := Vector3(6.3, _deck_y, 6.4)
	var dw := 8.4
	var dd := 8.2
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
		_box(Vector3(0.55, 0.42, 0.55), origin + p + Vector3(0, 1.85, 0), LEAF, false)
		_box(Vector3(0.22, 0.18, 0.22), origin + p + Vector3(0, 1.58, 0), Color("c8b878"), false)
	# Bright green pavilion roof (the video landmark).
	_box(Vector3(dw - 0.4, 0.22, dd - 0.4), origin + Vector3(0, 2.72, 0), GREEN_ROOF)
	_box(Vector3(dw + 0.35, 0.16, dd + 0.35), origin + Vector3(0, 2.92, 0), GREEN_ROOF)
	_box(Vector3(3.6, 0.14, 3.6), origin + Vector3(0, 3.12, 0), GREEN_ROOF_DK, false)
	# Green-sided wall with dark doors (deck entrance from the video).
	_box(Vector3(4.6, 2.4, 0.28), origin + Vector3(-1.6, 1.15, -3.85), GREEN_SIDING)
	_box(Vector3(0.7, 1.7, 0.1), origin + Vector3(-2.4, 0.9, -4.02), Color("2a2a2e"), false)
	_box(Vector3(0.22, 0.42, 0.06), origin + Vector3(-2.4, 1.45, -4.08), GLASS, false)
	_box(Vector3(0.7, 1.7, 0.1), origin + Vector3(-0.9, 0.9, -4.02), Color("2a2a2e"), false)
	_box(Vector3(0.08, 0.14, 0.06), origin + Vector3(-0.55, 1.05, -4.1), GOLD, false)
	_box(Vector3(0.55, 0.08, 0.35), origin + Vector3(-1.65, 0.12, -4.15), Color("3a3228"), false)
	_sign("EMPLOYEES ONLY", origin + Vector3(-1.65, 2.15, -4.12), 14, Color("fff6ea"), 180)
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
	# Beige ranch + maroon roof visible from the lawn and the deck look-out.
	var o := Vector3(-9.4, 0, 8.2)
	_box(Vector3(9.2, 2.6, 3.4), o + Vector3(0, 1.3, 0), BEIGE)
	_box(Vector3(9.8, 0.22, 3.9), o + Vector3(0, 2.72, 0), MAROON)
	_box(Vector3(0.7, 0.7, 0.08), o + Vector3(-2.4, 1.7, -1.75), GLASS, false)
	_box(Vector3(0.7, 0.7, 0.08), o + Vector3(0.2, 1.7, -1.75), GLASS, false)
	_box(Vector3(0.7, 0.7, 0.08), o + Vector3(2.6, 1.7, -1.75), GLASS, false)
	# Rear neighbor beyond the fence.
	_box(Vector3(8.5, 2.5, 3.2), Vector3(1.2, 1.25, 18.2), BEIGE, false)
	_box(Vector3(9.1, 0.2, 3.6), Vector3(1.2, 2.6, 18.2), MAROON, false)


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
	_villager(Vector3(-2.05, 0, -4.8), ROBE_BROWN, 0.5)
	_villager(Vector3(2.15, 0, -4.35), ROBE_GREEN, -0.4)
	_villager(Vector3(-2.4, 0, 2.4), ROBE_WINE, 2.6)
	_villager(Vector3(5.1, _deck_y + 0.05, 6.8), ROBE_BROWN, 3.3)


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
