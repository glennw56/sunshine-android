extends Area3D
class_name CollectiblePickup

const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")

signal collected(kind: String)

@export var kind: String = "croissant"
@export var is_fresh_batch: bool = false
var _bob: float = 0.0
var _taken := false


func _ready() -> void:
	add_to_group("bakery_pickup")
	body_entered.connect(_on_body)
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 2
	_bob = randf() * TAU
	_build()


func _build() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	col.shape = shape
	add_child(col)
	var visual := MenuPropsLib.instantiate_named("coffee" if kind == "drink" else "croissant")
	if visual:
		visual.name = "PastryCube"
		visual.scale = Vector3(1.85, 1.85, 1.85)
		visual.position = Vector3(0, 0.02, 0)
		MenuPropsLib.flatten_prop(visual)
		add_child(visual)
	else:
		_photo_cube()
	var tag := Label3D.new()
	tag.text = "FRESH" if is_fresh_batch else ("PASTRY" if kind == "croissant" else "SIP")
	tag.font_size = 28
	tag.modulate = Color("e8b4b8") if is_fresh_batch else Color("f7f0e6")
	tag.outline_size = 4
	tag.outline_modulate = Color("3d1f24")
	tag.position = Vector3(0, 0.58, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	var glow := OmniLight3D.new()
	glow.light_color = Color("f4c430") if is_fresh_batch else Color("e8b4b8")
	glow.light_energy = 0.85 if is_fresh_batch else 0.45
	glow.omni_range = 2.4
	add_child(glow)


func _photo_cube() -> void:
	var photo := _photo_path()
	var cube := MeshInstance3D.new()
	cube.name = "PastryCube"
	var box := BoxMesh.new()
	box.size = Vector3(0.62, 0.62, 0.08) if kind != "drink" else Vector3(0.42, 0.58, 0.42)
	cube.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if photo != "" and ResourceLoader.exists(photo):
		mat.albedo_texture = load(photo)
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = Color("e6b14a") if kind == "croissant" else Color("e8b4b8")
	if is_fresh_batch:
		mat.emission_enabled = true
		mat.emission = Color("f4c430")
		mat.emission_energy_multiplier = 0.35
	cube.material_override = mat
	cube.position = Vector3(0, 0.22, 0)
	add_child(cube)


func _photo_path() -> String:
	if kind == "drink":
		return "res://assets/generated/menu/square_coffee.jpg"
	return "res://assets/generated/menu/croissant.png"


func _process(delta: float) -> void:
	_bob += delta * 2.4
	rotate_y(delta * 1.1)
	position.y += sin(_bob) * 0.003


func _on_body(body: Node) -> void:
	if _taken or not (body is PlayerExplorer):
		return
	_taken = true
	collected.emit(kind)
	queue_free()
