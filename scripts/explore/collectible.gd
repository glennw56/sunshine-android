extends Area3D
class_name CollectiblePickup

signal collected(kind: String)

const VoxelKit := preload("res://scripts/explore/voxel_kit.gd")

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
	var color := Color("e6b14a") if kind == "croissant" else Color("e8b4b8")
	if is_fresh_batch:
		color = Color("f4c430")
	var cube := VoxelKit.add_box(self, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.2, 0), VoxelKit.flat(color), false)
	cube.name = "PastryCube"
	var tag := Label3D.new()
	tag.text = "FRESH" if is_fresh_batch else ("CUBE" if kind == "croissant" else "SIP")
	tag.font_size = 28
	tag.modulate = color
	tag.outline_size = 4
	tag.outline_modulate = Color("3d1f24")
	tag.position = Vector3(0, 0.48, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 0.85 if is_fresh_batch else 0.45
	glow.omni_range = 2.4
	add_child(glow)


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
