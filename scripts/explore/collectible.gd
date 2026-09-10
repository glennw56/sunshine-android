extends Area3D
class_name CollectiblePickup

signal collected(kind: String)

@export var kind: String = "croissant"
@export var is_fresh_batch: bool = false
var _bob: float = 0.0
var _taken := false


func _ready() -> void:
	body_entered.connect(_on_body)
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 2
	_bob = randf() * TAU
	_build()


func _build() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	col.shape = shape
	add_child(col)
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0052 if is_fresh_batch else 0.0045
	sprite.texture = load("res://assets/generated/croissant.png" if kind == "croissant" else "res://assets/generated/drink.png")
	sprite.position = Vector3(0, 0.15, 0)
	add_child(sprite)
	var glow := OmniLight3D.new()
	glow.light_color = Color("f4c430") if is_fresh_batch or kind == "croissant" else Color("e8b4b8")
	glow.light_energy = 1.15 if is_fresh_batch else 0.6
	glow.omni_range = 3.0 if is_fresh_batch else 2.2
	add_child(glow)
	if is_fresh_batch:
		var tag := Label3D.new()
		tag.text = "FRESH"
		tag.font_size = 28
		tag.modulate = Color("f4c430")
		tag.position = Vector3(0, 0.55, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(tag)


func _process(delta: float) -> void:
	_bob += delta * 2.4
	rotate_y(delta * 1.2)
	position.y += sin(_bob) * 0.003


func _on_body(body: Node) -> void:
	if _taken or not (body is PlayerExplorer):
		return
	_taken = true
	collected.emit(kind)
	queue_free()
